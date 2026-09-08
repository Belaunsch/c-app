//
//  CardEditorModel.swift
//  CApp
//

import Foundation
import OSLog
import SwiftData
import Translation

/// Editing state for a single card, plus the rules worth testing on their own:
/// validation, tag deduplication, and the German → Hanzi → Pinyin chain with
/// its provenance tracking.
///
/// The three text fields form a chain: German feeds the translation, Hanzi
/// feeds the Pinyin generation. Every field stays editable at all times, and a
/// value the user typed is never silently replaced by automation.
@Observable
final class CardEditorModel {
    var type: CardType
    var german: String
    var hanzi: String
    var pinyin: String
    var selectedTags: [Tag]
    var newTagName: String = ""

    /// Reported when creating a category failed. User-facing.
    private(set) var tagFailure: AppError?

    // MARK: - Provenance (the answer to Q9)
    //
    // Phase 2 derived the manual-edit flags at save time by comparing against
    // the stored value. That breaks the moment automation fills a field: on a
    // new card the stored value is empty, so a generated value would count as
    // "typed by the user" and the automation would never fire again.
    //
    // The flags are therefore tracked live instead. `hanziBaseline` and
    // `pinyinBaseline` hold the last value the field was *reconciled against*:
    // what the app put there when loading or generating, or what the user had
    // typed the last time editing ended. Anything that differs from the
    // baseline came from the user.

    private(set) var hanziIsManual: Bool
    private(set) var pinyinIsManual: Bool
    private var hanziBaseline: String
    private var pinyinBaseline: String

    /// Whether the current **automatic** Pinyin rests on a transliterated
    /// guess rather than on a lexicon reading.
    ///
    /// Not persisted. It is derived: the resolver is pure and offline, so
    /// running it again on the stored Hanzi answers the question at any time —
    /// see `refreshPinyinReview()`. A hand-corrected Pinyin is never in
    /// question, so the flag is cleared then.
    private(set) var pinyinNeedsReview = false

    /// The Hanzi the automatic Pinyin was derived from, `nil` when no Pinyin
    /// has been generated.
    ///
    /// This is what decides whether the Pinyin still belongs to the card, and
    /// it is deliberately not the same question as "did the Hanzi change since
    /// the last reconciliation". Those two came apart in exactly the case the
    /// device found: a translation that arrives while the user is typing their
    /// own Hanzi reconciles the provenance and then bails out, which advances
    /// the Hanzi baseline without touching the Pinyin. Asked the other way —
    /// "was this Pinyin made from what is in the field now?" — the answer
    /// stays correct no matter which path got us here.
    ///
    /// It also settles the empty cases without a second flag: a Pinyin the
    /// user cleared has the current Hanzi as its source, so nothing refills
    /// it, while a Pinyin that was never generated has no source at all.
    private var pinyinSourceHanzi: String?

    // MARK: - Translation state

    /// What the framework reports for this device, `nil` until checked.
    ///
    /// Plain `var` rather than `private(set)` plus a test hook: within one
    /// module the hook would have made the `private(set)` a facade anyway, and
    /// tests need to set it because `TranslationService.support()` requires
    /// real system models.
    var translationSupport: TranslationService.Support?
    private(set) var isTranslating = false

    /// What the last translation attempt has to say — an error, or an empty
    /// result. Transient: cleared as soon as the next attempt begins.
    private(set) var translationNotice: String?

    /// The hint under the German field. German, user-facing.
    ///
    /// Derived from both sources rather than stored, so neither can bury the
    /// other: a notice about one failed attempt takes precedence, but once it
    /// is gone the standing fact that this device cannot translate at all
    /// reappears. Stored in one variable it did not: leaving the German field
    /// cleared the message, and the footer went back to promising automatic
    /// Hanzi on a device that has none.
    var translationMessage: String? {
        translationNotice ?? availabilityMessage
    }

    private var availabilityMessage: String? {
        guard let translationSupport else { return nil }
        switch translationSupport.availability {
        case .installed:
            return nil
        case .downloadable where translationSupport.isConfirmed:
            return "Für die Übersetzung lädt iOS einmalig ein Sprachpaket. Beim ersten Übersetzen fragt das System nach."
        case .downloadable:
            // Inferred from the language catalogue, not measured: promise less.
            return "Fehlt das Sprachpaket, fragt iOS beim ersten Übersetzen danach. Falls die Übersetzung auf diesem Gerät nicht geht, Hanzi bitte manuell eintragen."
        case .unsupported:
            return "Auf diesem Gerät ist Deutsch → Chinesisch nicht verfügbar. Hanzi bitte manuell eintragen."
        }
    }

    /// Raised by the Hanzi refresh control ("Neu übersetzen"): the next
    /// translation may replace a hand-edited Hanzi and regenerate the Pinyin
    /// along with it.
    private var translationMayOverwriteManualValues = false

    /// Guards against stale async results. Every translation run gets a
    /// number; a result whose number is no longer current is dropped.
    private var translationRun = 0

    /// The German text the last run was requested for.
    ///
    /// Return closes the keyboard by dropping the focus, so one keypress
    /// produces both a submit and a focus change. The view already routes both
    /// through a single call, and this makes a duplicate harmless anyway.
    private var lastTranslationRequest: String?

    /// The card being edited, or `nil` when creating a new one.
    private let existingCard: Card?

    init(card: Card? = nil, type: CardType = .word) {
        existingCard = card
        self.type = card?.type ?? type
        german = card?.german ?? ""
        hanzi = card?.hanzi ?? ""
        pinyin = card?.pinyin ?? ""
        selectedTags = card?.tags ?? []

        hanziIsManual = card?.hanziWasEditedManually ?? false
        pinyinIsManual = card?.pinyinWasEditedManually ?? false
        hanziBaseline = card?.hanzi ?? ""
        pinyinBaseline = card?.pinyin ?? ""
        // A stored Pinyin was saved together with its Hanzi, so that is its
        // source. A stored card *without* a Pinyin keeps `nil` and is treated
        // like one that was never generated — the next visit to the Hanzi
        // field fills it in.
        if let card, card.pinyin.isEmpty == false {
            pinyinSourceHanzi = Self.normalized(card.hanzi)
        }
    }

    var isEditingExistingCard: Bool { existingCard != nil }

    /// Loads the lexicon and settles whether the Pinyin in the field would
    /// need a second look.
    ///
    /// Called from the editor's `task`, which is why it is not done in
    /// `init`: the first lexicon access reads and indexes the bundled data
    /// (measured 46 ms on a Mac for 119.939 entries), and that belongs into
    /// the sheet's appearance rather than into the middle of typing.
    func prepareResolver() {
        ChineseLexicon.shared.prepare()
        refreshPinyinReview()
    }

    /// Works out whether the Pinyin currently in the field would need a
    /// second look.
    ///
    /// Derived rather than stored — no schema change for a hint. The resolver
    /// is pure, offline and deterministic, so the stored Hanzi is enough to
    /// ask the question again whenever the editor opens.
    func refreshPinyinReview() {
        // An empty field is never up for review — there is no reading to
        // check, and `hanziHint` explains why it is empty. Same rule as in
        // `generatePinyinFromHanzi`.
        guard pinyinIsManual == false,
              trimmedHanzi.isEmpty == false,
              trimmedPinyin.isEmpty == false else {
            pinyinNeedsReview = false
            return
        }
        pinyinNeedsReview = PinyinService.resolution(for: trimmedHanzi).needsReview
    }

    // MARK: - Validation

    /// German and Hanzi are required, Pinyin is not. Whitespace is not content,
    /// and the Hanzi field has to hold Chinese: a card whose Hanzi side reads
    /// `asdf` is not a card, and it cannot produce Pinyin either.
    var canSave: Bool {
        guard trimmedGerman.isEmpty == false, trimmedHanzi.isEmpty == false else { return false }
        return PinyinService.containsHanScript(trimmedHanzi)
    }

    /// Why the Hanzi field is not acceptable yet, or `nil` when it is.
    ///
    /// Derived rather than stored: it explains both the disabled save button
    /// and a Pinyin that could not be generated, and it updates while the
    /// user types instead of waiting for the next event.
    var hanziHint: String? {
        guard trimmedHanzi.isEmpty == false else { return nil }
        guard PinyinService.containsHanScript(trimmedHanzi) == false else { return nil }
        return "Das Hanzi-Feld braucht mindestens ein chinesisches Zeichen. Ohne Hanzi gibt es kein Pinyin."
    }

    var trimmedGerman: String { Self.normalized(german) }
    var trimmedHanzi: String { Self.normalized(hanzi) }
    var trimmedPinyin: String { Self.normalized(pinyin) }

    // MARK: - The chain

    /// Whether an automatic translation should run now.
    ///
    /// Not while a hand-edited Hanzi would be overwritten — that is what the
    /// refresh control next to the Hanzi field is for.
    var shouldTranslateAutomatically: Bool {
        // Not before the availability check has answered: starting earlier
        // would pin a configuration without the strategy the check might
        // still ask for.
        guard let translationSupport, translationSupport.availability != .unsupported else {
            return false
        }
        guard trimmedGerman.isEmpty == false else { return false }
        // Same text as the last run: nothing to do. Return and the following
        // focus loss are one user action, and leaving the field again without
        // touching the text is not a request to translate it a second time.
        // This comes *before* the overwrite permission on purpose. The
        // permission stays armed until the asynchronous run ends, so checking
        // it first would let the focus change that follows the ↻ tap start a
        // second run for the same text.
        guard trimmedGerman != lastTranslationRequest else { return false }
        if translationMayOverwriteManualValues { return true }
        return hanziIsManual == false
    }

    var canTranslate: Bool {
        guard let translationSupport, translationSupport.availability != .unsupported else {
            return false
        }
        return trimmedGerman.isEmpty == false
    }

    /// Pinyin can only be generated from actual Chinese, so this also gates
    /// the Pinyin refresh control.
    var canGeneratePinyin: Bool {
        PinyinService.containsHanScript(trimmedHanzi)
    }

    /// Called when editing the German field ends — focus loss or Return.
    /// - Returns: whether a translation should start now.
    func germanEditingEnded() -> Bool {
        normalizeGerman()
        translationNotice = nil
        guard shouldTranslateAutomatically else { return false }
        // Recorded at trigger time rather than when the run starts: the
        // session arrives asynchronously, so a second trigger could otherwise
        // slip in before the first run has recorded anything. The price is
        // that a run which then bails out — the user finished a Hanzi of their
        // own while the session was still loading — leaves this text marked as
        // requested. ↻ is the way back, and that is the same button the user
        // needs anyway to overwrite the Hanzi they just typed.
        lastTranslationRequest = trimmedGerman
        return true
    }

    /// Called when editing the Hanzi field ends — focus loss or Return.
    ///
    /// Marks the value as hand-edited if it differs from what the app last put
    /// there, then re-derives the Pinyin — unless the Pinyin itself was
    /// hand-corrected, which stays protected.
    func hanziEditingEnded() {
        normalizeHanzi()
        reconcileHanziProvenance()
        regeneratePinyinIfItNoLongerBelongsToTheHanzi()
    }

    /// Re-derives the Pinyin unless it already belongs to the Hanzi in the
    /// field, or the user typed it themselves.
    ///
    /// The single place this decision is made — the editor asks it when the
    /// Hanzi field is done, when a translation declines to overwrite, and
    /// before saving. Note what it does *not* do: regenerate on every focus
    /// loss. A stored Pinyin whose source is the stored Hanzi is left alone,
    /// so a curated "xièxie" does not turn into the ICU rendering "xièxiè"
    /// just from tabbing through the form.
    private func regeneratePinyinIfItNoLongerBelongsToTheHanzi() {
        guard pinyinIsManual == false else { return }
        guard pinyinSourceHanzi != trimmedHanzi else { return }
        generatePinyinFromHanzi()
    }

    /// Called when editing the Pinyin field ends — focus loss or Return.
    func pinyinEditingEnded() {
        normalizePinyin()
        reconcilePinyinProvenance()
    }

    /// The Pinyin refresh control: a deliberate user action, so it may replace
    /// a hand-corrected value. Afterwards the value counts as automatic again.
    func regeneratePinyin() {
        normalizeHanzi()
        reconcileHanziProvenance()
        generatePinyinFromHanzi()
    }

    /// The Hanzi refresh control ("Neu übersetzen"): explicit permission to
    /// replace a hand-edited Hanzi and regenerate the whole chain from it.
    func prepareExplicitRetranslation() {
        normalizeGerman()
        translationMayOverwriteManualValues = true
        translationNotice = nil
        // The deliberate run counts as this text's run, so the focus loss that
        // follows the tap does not start an automatic one on top of it.
        lastTranslationRequest = trimmedGerman
    }

    /// Runs one translation on the session `translationTask` provides.
    func translate(using session: TranslationSession) async {
        let requestedText = trimmedGerman
        guard requestedText.isEmpty == false else {
            finishTranslationRun()
            return
        }

        let mayOverwrite = translationMayOverwriteManualValues
        guard mayOverwrite || hanziIsManual == false else { return }

        translationRun += 1
        let run = translationRun
        isTranslating = true
        translationNotice = nil

        do {
            let response = try await session.translate(requestedText)

            // A newer run has taken over — it owns the state, leave it alone.
            guard run == translationRun else { return }

            // Latest input wins. The text moved on without a new run starting
            // (typing does not start one), so this run has to release the
            // state itself — otherwise the spinner and the overwrite
            // permission would both stay set for the rest of the session.
            guard requestedText == trimmedGerman else {
                finishTranslationRun()
                return
            }

            completeTranslation(with: response.targetText)
        } catch {
            guard run == translationRun else { return }
            Self.logger.error("Translation failed: \(error.localizedDescription, privacy: .public)")
            finishTranslationRun(
                message: "Übersetzung nicht möglich. Hanzi kann manuell eingetragen werden."
            )
        }
    }

    /// Everything that happens once the translated text has arrived.
    ///
    /// Split out from `translate(using:)` on purpose: a `TranslationSession`
    /// cannot be constructed in a test, but these rules — a hand-edited Hanzi
    /// stays, the overwrite permission is good for exactly one run, the Pinyin
    /// follows the new Hanzi — are the heart of this phase and need tests.
    func completeTranslation(with translatedHanzi: String) {
        let mayOverwrite = translationMayOverwriteManualValues

        // The user may have typed into the fields while the translation was
        // running — the jump into the Hanzi field is what triggered it. Settle
        // the provenance first, then decide, so their input is never wiped.
        _ = reconcileHanziProvenance()
        _ = reconcilePinyinProvenance()

        guard mayOverwrite || hanziIsManual == false else {
            // The user typed their own Hanzi while this ran. It stays — but
            // the Pinyin next to it must not keep describing the word the
            // card no longer holds.
            regeneratePinyinIfItNoLongerBelongsToTheHanzi()
            finishTranslationRun()
            return
        }

        let translated = Self.normalized(translatedHanzi)
        guard translated.isEmpty == false else {
            finishTranslationRun(message: "Die Übersetzung war leer. Hanzi bitte manuell eintragen.")
            return
        }

        applyGeneratedHanzi(translated)
        if mayOverwrite || pinyinIsManual == false {
            generatePinyinFromHanzi()
        }
        finishTranslationRun()
    }

    /// Asks the framework whether the pair can be translated on this device.
    ///
    /// Sets no message of its own: `availabilityMessage` derives it, so a
    /// check that arrives late cannot overwrite an error the user is reading.
    func refreshTranslationSupport() async {
        translationSupport = await TranslationService.support()
    }

    // MARK: - Applying automatic values

    /// The single seam automation writes a Hanzi through. Internal rather
    /// than private so the provenance rule can be tested without a real
    /// `TranslationSession`, which cannot be constructed in a test.
    func applyGeneratedHanzi(_ value: String) {
        hanzi = value
        hanziBaseline = value
        hanziIsManual = false
    }

    /// The single seam automation writes a Pinyin through.
    func applyGeneratedPinyin(_ value: String) {
        pinyin = value
        pinyinBaseline = value
        pinyinIsManual = false
        // Records what this Pinyin was made from, including the empty result
        // for a Hanzi nothing can be derived from: that empty field belongs
        // to this Hanzi just as much.
        pinyinSourceHanzi = trimmedHanzi
    }

    private func generatePinyinFromHanzi() {
        let resolution = PinyinService.resolution(for: trimmedHanzi)
        guard resolution.text.isEmpty else {
            applyGeneratedPinyin(resolution.text)
            pinyinNeedsReview = resolution.needsReview
            return
        }

        // Nothing derivable. An automatic Pinyin that is still standing here
        // was derived from a *different* Hanzi, so keeping it would show the
        // reading of a word the card no longer contains — it goes. A
        // hand-corrected value is never dropped, not even by the refresh
        // control: that would delete work the user did.
        guard pinyinIsManual == false else { return }
        applyGeneratedPinyin("")
        // An empty field is not a doubtful reading. Why it is empty is what
        // `hanziHint` explains.
        pinyinNeedsReview = false
    }

    // MARK: - Field normalization

    private func normalizeGerman() {
        let normalized = Self.normalized(german)
        if german != normalized { german = normalized }
    }

    private func normalizeHanzi() {
        let normalized = Self.normalized(hanzi)
        if hanzi != normalized { hanzi = normalized }
    }

    private func normalizePinyin() {
        let normalized = Self.normalized(pinyin)
        if pinyin != normalized { pinyin = normalized }
    }

    /// Ends a translation run: no spinner, and the one-shot overwrite
    /// permission is spent. Internal so the release can be tested.
    func finishTranslationRun(message: String? = nil) {
        isTranslating = false
        translationNotice = message
        translationMayOverwriteManualValues = false
    }

    /// Settles whether the current Hanzi came from the user.
    /// - Returns: whether the value changed since the last reconciliation.
    @discardableResult
    private func reconcileHanziProvenance() -> Bool {
        guard trimmedHanzi != Self.normalized(hanziBaseline) else { return false }
        hanziIsManual = trimmedHanzi.isEmpty == false
        hanziBaseline = hanzi
        return true
    }

    @discardableResult
    private func reconcilePinyinProvenance() -> Bool {
        guard trimmedPinyin != Self.normalized(pinyinBaseline) else { return false }
        pinyinIsManual = trimmedPinyin.isEmpty == false
        // Whatever the user put here — including nothing — now belongs to the
        // Hanzi in the field, so the automation leaves it alone until that
        // Hanzi changes. And their own value needs no review from us: the
        // hint asked them to look, and they did.
        pinyinSourceHanzi = trimmedHanzi
        pinyinNeedsReview = false
        pinyinBaseline = pinyin
        return true
    }

    // MARK: - Tags

    func isSelected(_ tag: Tag) -> Bool {
        selectedTags.contains { $0 === tag }
    }

    func toggle(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0 === tag }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }

    var canAddNewTag: Bool { TagNormalization.isValid(newTagName) }

    /// Creates the category from `newTagName` right away and selects it.
    ///
    /// **Changed in the phase-6 correction round, and it overrides the phase-2
    /// rule (A14).** Until then a typed name was only remembered and became a
    /// `Tag` when the card was saved, so that cancelling the editor left
    /// nothing behind. The device test showed what that costs: the queued name
    /// had to look different from a real category — a "neu" badge and a delete
    /// control — and a tap on it deleted instead of selecting. Two kinds of
    /// category on one screen, one of them deletable in a place where deleting
    /// categories is otherwise impossible.
    ///
    /// So "Hinzufügen" is now taken at its word: the category exists, is
    /// persisted, survives cancelling the card, and can be used by other
    /// cards. Renaming and deleting live where they always did — in the
    /// category management screen, with its confirmation.
    ///
    /// An existing name selects that category instead of creating a second
    /// one; the normalisation rules from phase 2 are unchanged (`Essen`,
    /// `essen` and `ESSEN` are one category).
    func addNewTag(existingTags: [Tag], in context: ModelContext) {
        let name = TagNormalization.displayName(for: newTagName)
        guard TagNormalization.isValid(name) else { return }

        // Checked against the store, not only against the list the button's
        // closure captured. A stale snapshot would let a second category with
        // the same normalised key appear, and A13 says there is only ever
        // one — undoable afterwards solely through the management screen.
        // A failed fetch would fall back to the possibly stale list from the
        // view, which is exactly how a second category with the same key
        // could appear (A13). The behaviour stays the same — refusing to add
        // would be worse than a rare duplicate — but it must not be silent.
        let stored: [Tag]
        do {
            stored = try context.fetch(FetchDescriptor<Tag>())
        } catch {
            Self.logger.error(
                "Tag lookup failed, falling back to the view's list: \(error.localizedDescription, privacy: .public)"
            )
            stored = []
        }
        let candidates = stored + existingTags + selectedTags

        if let match = TagNormalization.existingTag(matching: name, in: candidates) {
            if isSelected(match) == false {
                selectedTags.append(match)
            }
            newTagName = ""
            return
        }

        let tag = Tag(name: name)
        context.insert(tag)
        do {
            try context.save()
        } catch {
            // Nothing half-created: without the rollback the category would
            // exist in memory, be selectable, and vanish on the next launch.
            //
            // Note that `rollback()` discards **every** uncommitted change on
            // the shared `mainContext`, not just this insert. That is safe
            // today because every write path in the app mutates and saves
            // inside one synchronous block, so nothing else is ever pending.
            // An asynchronous save added later would break that quietly.
            //
            // This branch has no automated test; `CardEditorModelTests`
            // records why, and the device checklist covers what the user
            // sees.
            context.rollback()
            tagFailure = .tagCreateFailed(error)
            Self.logger.error("Category could not be created: \(error.localizedDescription, privacy: .public)")
            return
        }
        selectedTags.append(tag)
        newTagName = ""
    }

    func dismissTagFailure() {
        tagFailure = nil
    }

    // MARK: - Saving

    /// Brings the editor's state up to date before anything is persisted.
    ///
    /// Saving can happen while a field still has focus — tapping the toolbar
    /// does not reliably move it — so correctness must not depend on SwiftUI
    /// having delivered a focus change first. Measured on the device in phase
    /// 4: "Brot" translated to `面包`/`miànbāo`, the Hanzi was corrected to
    /// `水` by hand, and saving straight from the Hanzi field stored `水` with
    /// the Pinyin `miànbāo` — the reading of a word that was no longer on the
    /// card. This does what leaving the field would have done.
    ///
    /// Internal so the rule can be tested without a view.
    func reconcileForSave() {
        normalizeGerman()
        normalizeHanzi()
        normalizePinyin()

        reconcileHanziProvenance()
        reconcilePinyinProvenance()

        // A hand-corrected Pinyin is never touched (rule 5). Otherwise the
        // Pinyin follows the Hanzi it belongs to: re-derived when it was made
        // from a different one, and filled in when it was never generated at
        // all — "type German, type Hanzi, hit save" must not save a card
        // without Pinyin just because no focus change fired. A Pinyin the
        // user cleared has the current Hanzi as its source and therefore
        // stays cleared: "Pinyin kann leer bleiben" is what the editor
        // promises, so saving must not quietly write one back.
        regeneratePinyinIfItNoLongerBelongsToTheHanzi()
    }

    /// Writes the card.
    ///
    /// Throws `AppError.cardIncomplete` rather than returning silently, so a
    /// mis-wired caller cannot mistake "nothing happened" for success.
    ///
    /// **The learning status is deliberately not written here.** The editor
    /// lost its status picker in the phase-6 correction round (task 6.10), so
    /// it no longer owns that value — writing it back would mean writing a
    /// copy taken when the editor opened. The device test made that concrete:
    /// the card editor stays alive when the tab changes, so rating the same
    /// card in a session and then saving the untouched editor would have
    /// reset the freshly earned status while leaving the counters. A new card
    /// starts on `LearningStatus.new` through `Card`'s own default; from then
    /// on only the session writes it.
    func save(into context: ModelContext) throws {
        reconcileForSave()
        guard canSave else { throw AppError.cardIncomplete }

        let tags = selectedTags

        if let card = existingCard {
            card.type = type
            card.german = trimmedGerman
            card.hanzi = trimmedHanzi
            card.pinyin = trimmedPinyin
            card.tags = tags
            card.hanziWasEditedManually = hanziIsManual
            card.pinyinWasEditedManually = pinyinIsManual
        } else {
            let card = Card(
                type: type,
                german: trimmedGerman,
                hanzi: trimmedHanzi,
                pinyin: trimmedPinyin,
                hanziWasEditedManually: hanziIsManual,
                pinyinWasEditedManually: pinyinIsManual,
                tags: tags
            )
            context.insert(card)
        }

        try context.save()
    }

    private static let logger = Logger(subsystem: "de.belaunsch.CApp", category: "editor")

    /// Trimmed at the ends, with every run of whitespace inside collapsed to a
    /// single space.
    ///
    /// No blanket ban on spaces: sentence cards need them in the German text,
    /// sentence Pinyin needs them between words, and a word card may well be a
    /// legitimate multi-word expression. Line breaks are not card content
    /// though — they become spaces here rather than being rejected, so a paste
    /// with a stray newline still saves.
    private static func normalized(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
