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
    var status: LearningStatus
    var selectedTags: [Tag]
    var newTagName: String = ""

    /// Names the user typed that do not exist as a tag yet. Deliberately not
    /// inserted into the context while editing, so a cancelled editor leaves
    /// nothing behind.
    private(set) var pendingTagNames: [String] = []

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
        status = card?.status ?? .new
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
        let generated = PinyinService.pinyin(for: trimmedHanzi)
        guard generated.isEmpty else {
            applyGeneratedPinyin(generated)
            return
        }

        // Nothing derivable. An automatic Pinyin that is still standing here
        // was derived from a *different* Hanzi, so keeping it would show the
        // reading of a word the card no longer contains — it goes. A
        // hand-corrected value is never dropped, not even by the refresh
        // control: that would delete work the user did.
        guard pinyinIsManual == false else { return }
        applyGeneratedPinyin("")
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
        // Hanzi changes.
        pinyinSourceHanzi = trimmedHanzi
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

    /// Takes the name from `newTagName`. An existing tag is selected instead
    /// of queueing a duplicate; a genuinely new name is only remembered and
    /// becomes a `Tag` when the card is saved.
    func addNewTag(existingTags: [Tag]) {
        let name = TagNormalization.displayName(for: newTagName)
        guard TagNormalization.isValid(name) else { return }

        if let match = TagNormalization.existingTag(matching: name, in: existingTags) {
            if isSelected(match) == false {
                selectedTags.append(match)
            }
        } else if isPending(name) == false {
            pendingTagNames.append(name)
        }
        newTagName = ""
    }

    func isPending(_ name: String) -> Bool {
        let key = TagNormalization.key(for: name)
        return pendingTagNames.contains { TagNormalization.key(for: $0) == key }
    }

    func removePendingTag(_ name: String) {
        pendingTagNames.removeAll { $0 == name }
    }

    private func resolveTags(in context: ModelContext) throws -> [Tag] {
        guard pendingTagNames.isEmpty == false else { return selectedTags }

        let storedTags = try context.fetch(FetchDescriptor<Tag>())
        var resolved = selectedTags

        for name in pendingTagNames {
            if let existing = TagNormalization.existingTag(matching: name, in: storedTags + resolved) {
                if resolved.contains(where: { $0 === existing }) == false {
                    resolved.append(existing)
                }
            } else {
                let tag = Tag(name: name)
                context.insert(tag)
                resolved.append(tag)
            }
        }
        return resolved
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
    func save(into context: ModelContext) throws {
        reconcileForSave()
        guard canSave else { throw AppError.cardIncomplete }

        let tags = try resolveTags(in: context)

        if let card = existingCard {
            card.type = type
            card.german = trimmedGerman
            card.hanzi = trimmedHanzi
            card.pinyin = trimmedPinyin
            card.status = status
            card.tags = tags
            card.hanziWasEditedManually = hanziIsManual
            card.pinyinWasEditedManually = pinyinIsManual
        } else {
            let card = Card(
                type: type,
                german: trimmedGerman,
                hanzi: trimmedHanzi,
                pinyin: trimmedPinyin,
                status: status,
                hanziWasEditedManually: hanziIsManual,
                pinyinWasEditedManually: pinyinIsManual,
                tags: tags
            )
            context.insert(card)
        }

        try context.save()
    }

    private static let logger = Logger(subsystem: "de.belaunsch.CApp", category: "translation")

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
