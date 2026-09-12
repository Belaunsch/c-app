//
//  LearnSessionModel.swift
//  CApp
//

import Foundation
import OSLog
import SwiftData

/// Drives one learning session: builds the pool, feeds the engine, and writes
/// the results back.
///
/// The split is deliberate and load-bearing:
///
///     LearnSessionModel  = orchestration + SwiftData + view state
///     Learning/          = selection, queue, status logic
///
/// Not one rule of the learning logic lives here. Weights, recency, batch
/// selection, the reinsert gap, `maxReinserts`, the transition matrix and
/// "only the first assessment changes the status" all come from `Learning/`,
/// which phase 5 tested on its own. Reimplementing any of it here would mean
/// two sources of truth, and the one with tests would lose.
@Observable
final class LearnSessionModel {

    enum State: Equatable {
        /// No usable card for this configuration.
        case empty
        /// A card is being asked.
        case asking
    }

    let configuration: SessionConfiguration

    private(set) var state: State = .empty

    /// The card on screen, resolved from the store every time it changes.
    ///
    /// Deliberately not a copy taken at batch selection: the queue works on
    /// ids, so an edit made between two sessions — or between two
    /// appearances within one session — shows up here
    /// (`docs/learning-engine.md` §9).
    private(set) var currentCard: Card?

    /// Whether the answer is shown. This is also the one-shot token for
    /// assessing: only a revealed card can be rated, and rating clears it.
    private(set) var isRevealed = false

    /// Mode B's middle step: the Hanzi is on screen, the meaning is not.
    ///
    /// Beside `isRevealed` rather than replacing it, so mode A and `submit`
    /// keep the exact token they have used since phase 6. Meaningless in
    /// mode A, where nothing ever sets it.
    private(set) var hasShownHanzi = false

    /// What the spoken answer came to, if the learner used the microphone.
    ///
    /// `nil` means they did not — which is the normal case, because the
    /// recording is optional and everything works without it. Never set by
    /// anything but `applyRecognition(_:forCardWith:)`, so a late result
    /// cannot reach it by another route.
    private(set) var speechCheck: SpeechCheck?

    /// How much of the card is uncovered, as one value.
    ///
    /// Derived rather than stored — two flags that can disagree is how a
    /// card ends up "revealed but still hidden". The derivation itself is a
    /// pure function so it can be tested; see `PromptStage`.
    var promptStage: PromptStage {
        PromptStage.stage(isRevealed: isRevealed, hasShownHanzi: hasShownHanzi)
    }

    /// How many assessments this session has recorded. Shown as a plain
    /// number, never as a target — the session has no natural end.
    private(set) var answeredCount = 0

    /// Set when writing failed. The card stays where it is so the same
    /// answer can be given again.
    private(set) var saveFailure: AppError?

    // MARK: - Engine state

    /// The cards this session may draw from, built once at the start.
    ///
    /// Shrinks only when an id turns out to be unresolvable, which is how a
    /// card deleted mid-session leaves the session (§9).
    private(set) var pool: [CardSnapshot] = []

    private var queue: SessionQueue?

    /// The previous batch's ids, for the recency damping in `CardWeighting`.
    private var previousBatchIDs: Set<UUID> = []

    /// Injected so the selection stays reproducible in tests. The engine
    /// takes `inout some RandomNumberGenerator`, which is why this is a
    /// concrete wrapper rather than an existential.
    private var generator: AnyRandomNumberGenerator

    /// Injected so `lastReviewedAt` is checkable exactly. Production passes
    /// the real clock; `Learning/` itself has no clock at all.
    private let now: () -> Date

    init(
        configuration: SessionConfiguration,
        generator: AnyRandomNumberGenerator = AnyRandomNumberGenerator(),
        now: @escaping () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.generator = generator
        self.now = now
    }

    // MARK: - Starting

    /// Builds the pool and asks the first card.
    ///
    /// Idempotent enough to be called from a `task`: a session that already
    /// has a queue is left alone.
    func start(in context: ModelContext) {
        guard queue == nil else { return }
        pool = Self.pool(for: configuration, in: context)
        guard pool.isEmpty == false else {
            state = .empty
            return
        }
        state = .asking
        advanceToNextAnswerableCard(in: context)
    }

    /// The cards of one session: the chosen type, the chosen categories, and
    /// something Chinese to learn.
    ///
    /// Filtering runs in plain Swift on a type-narrowed fetch, the same way
    /// the card list does it (`docs/architecture.md` A11). The rule itself
    /// lives in `poolCards`, which is also what the setup screen counts with;
    /// the category semantics differ from the card list on purpose (A26).
    static func pool(for configuration: SessionConfiguration, in context: ModelContext) -> [CardSnapshot] {
        let typeRaw = configuration.cardType.rawValue
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.typeRaw == typeRaw },
            sortBy: [SortDescriptor(\.german)]
        )

        let cards: [Card]
        do {
            cards = try context.fetch(descriptor)
        } catch {
            // Nothing to recover: an unreadable store means no session. The
            // empty state tells the user, and this line says why in the log.
            logger.error("Pool could not be read: \(error.localizedDescription, privacy: .public)")
            return []
        }

        return poolCards(from: cards, configuration: configuration)
            .map { CardSnapshot(id: $0.id, status: $0.status) }
    }

    /// The pool rule itself, as a pure function over cards already loaded.
    ///
    /// Split out so the setup screen can count the same cards from its own
    /// `@Query` instead of fetching behind SwiftUI's back — a read the view
    /// does not observe does not re-run when a card is added, and the start
    /// button would stay disabled after the user created their first card.
    /// One rule, two callers.
    ///
    /// **Categories are combined with OR.** The device test made it
    /// concrete: picking "Allgemein" and "Essen" in a session means
    /// "practise either", not "practise the few cards that carry both" —
    /// asking for two topics should widen the session, not empty it. This
    /// was the difference from the card list when it was written (A26 versus
    /// A12); the list has since been measured against the same use and
    /// adopted the same rule (A32).
    static func poolCards(from cards: [Card], configuration: SessionConfiguration) -> [Card] {
        // Type filtering stays with `CardFilter`, so "words and sentences
        // never mix" has one owner. Only the category rule differs.
        CardFilter.apply(to: cards, type: configuration.cardType)
            .filter { matchesAnyCategory($0, tagKeys: configuration.tagKeys) }
            // No Chinese, nothing to learn — excluded when the pool is built
            // (`docs/learning-engine.md` §9). A plain Unicode scan, not a
            // Pinyin generation: the lexicon is never touched here.
            .filter { PinyinService.containsHanScript($0.hanzi) }
    }

    /// The selected keys that still have a category behind them.
    ///
    /// A category deleted in the management screen would otherwise stay
    /// selected invisibly: narrowing the pool, and impossible to deselect
    /// because it no longer has a control on the setup screen. Dropping it
    /// heals the pool and the setup screen in one place.
    ///
    /// Written when the categories still sat behind a filter button, where
    /// the stale key also inflated a badge. Since A33 they are chips on the
    /// setup screen and the **Alle** chip is the clear-selection control that
    /// A25 once ruled out — the reason this function exists is unchanged, but
    /// the screen it heals looks different, and the chips must be asked about
    /// *these* keys rather than the raw selection for it to work.
    ///
    /// Nothing left means no restriction, not an empty session: the state the
    /// user can see is "no category selected", and that is what they get.
    /// Lives here rather than in the view because it decides which keys the
    /// pool rule ever sees, and that deserves a test.
    static func activeTagKeys(_ tagKeys: Set<String>, among tags: [Tag]) -> Set<String> {
        tagKeys.intersection(tags.map { TagNormalization.key(for: $0.name) })
    }

    /// Whether the card belongs to at least one of the chosen categories.
    ///
    /// No selection means no restriction — all cards of the chosen type.
    static func matchesAnyCategory(_ card: Card, tagKeys: Set<String>) -> Bool {
        guard tagKeys.isEmpty == false else { return true }
        return tagKeys.isDisjoint(with: CardFilter.keys(of: card)) == false
    }

    // MARK: - Asking

    func reveal() {
        guard currentCard != nil else { return }
        isRevealed = true
    }

    /// Mode B's middle step: show the Hanzi without giving the meaning away.
    ///
    /// Idempotent, and it never runs backwards — a second tap changes
    /// nothing, and it cannot un-reveal a card that is already fully
    /// visible, because `promptStage` reads `isRevealed` first.
    func showHanzi() {
        guard currentCard != nil else { return }
        hasShownHanzi = true
    }

    /// Records what the spoken answer came to, and reveals the card.
    ///
    /// **The card id is the point of this signature.** Recognition is
    /// asynchronous: the learner can tap "Antwort zeigen", rate, and be two
    /// cards further on before a finalising analyzer returns. The id the
    /// recording started with is compared against the card on screen, and a
    /// result that belongs to a card the session has left is dropped. Without
    /// that, a late transcription would attach itself to whatever card
    /// happened to be showing — and it would look like the app had recognised
    /// something the learner never said.
    ///
    /// Revealing here is what makes the spoken answer part of the normal
    /// flow rather than a second answer display beside it: speaking checks
    /// the card, so the card opens, and the one revealed state shows the
    /// result next to the answer. The self-assessment stays untouched and
    /// manual — recognition never rates anything.
    func applyRecognition(_ recognized: String, forCardWith id: UUID) {
        guard let card = currentCard, card.id == id else {
            Self.logger.info("recognition result dropped: the session moved on")
            return
        }
        speechCheck = SpeechCheck.compare(recognized: recognized, expected: card.hanzi)
        isRevealed = true
    }

    /// Records one self-assessment: engine first, then the store, then the
    /// session state.
    ///
    /// The order is the whole point. `SessionQueue` is a value type, so the
    /// engine's advance happens on a copy and is only kept once the write
    /// succeeded. A failed save therefore leaves the queue exactly where it
    /// was: the same card comes up again, and answering it a second time
    /// counts once, not twice. That is the simplest arrangement that cannot
    /// drift apart — no transactions, no event log.
    ///
    /// The failure path has no automated test: a read-only store provokes it
    /// reliably on its own but not inside the parallel suite, for reasons I
    /// could not establish, and the alternative would be a save closure that
    /// exists purely so a test can throw. What *is* pinned is the property
    /// this order rests on — advancing a copy leaves the original alone, see
    /// `SessionQueueTests.advancingACopyDoesNotAffectTheOriginal`.
    /// `LearnSessionModelTests` records the full reasoning.
    func submit(_ assessment: SelfAssessment, in context: ModelContext) {
        // Only a revealed card can be rated, and rating clears the flag.
        // That makes this the double-tap guard as well: a second tap arriving
        // before the view redraws finds nothing revealed and does nothing.
        guard isRevealed, let card = currentCard, var advanced = queue else { return }
        guard let outcome = advanced.assess(assessment, currentStatus: card.status) else { return }
        // Cleared only once there is an outcome. If the queue ever had nothing
        // to rate, the card would otherwise sit there covered, unrated and
        // without any feedback.
        isRevealed = false

        apply(outcome, to: card)
        do {
            try context.save()
        } catch {
            // Undo the card's changes so the alert cannot claim failure while
            // a later save commits them anyway — and leave the queue alone,
            // so the user rates the same card again rather than a new one.
            context.rollback()
            isRevealed = true
            saveFailure = .cardSaveFailed(error)
            Self.logger.error("Answer could not be saved: \(error.localizedDescription, privacy: .public)")
            return
        }

        queue = advanced
        answeredCount += 1
        // The next card starts covered again. Reset here rather than where
        // `currentCard` is assigned, because this is the one path from one
        // card to the next — and because a failed save above returns before
        // it, leaving the user on the same card exactly as they left it.
        hasShownHanzi = false
        speechCheck = nil
        advanceToNextAnswerableCard(in: context)
    }

    func dismissSaveFailure() {
        saveFailure = nil
    }

    /// Writes what one answer changes (`docs/learning-engine.md` §7).
    ///
    /// The counters move on every assessment, repetitions included. The
    /// status moves only when the engine says this was the card's first
    /// assessment in the batch — reported as `newStatus`, which is `nil`
    /// otherwise. That decision is not reconstructed here: a second opinion
    /// on it is exactly how the rule would get lost.
    private func apply(_ outcome: AssessmentOutcome, to card: Card) {
        card.reviewCount += 1
        card.lastReviewedAt = now()
        if outcome.countsAsCorrect {
            card.correctCount += 1
        }
        if let newStatus = outcome.newStatus {
            card.status = newStatus
        }
    }

    // MARK: - Moving on

    /// Finds the next card that can actually be shown, starting a new batch
    /// when the current one is done.
    ///
    /// Terminates because every pass either consumes one queue entry or
    /// removes one card from the pool, and an empty pool ends the session.
    private func advanceToNextAnswerableCard(in context: ModelContext) {
        while true {
            if queue == nil || queue?.isFinished == true {
                startNextBatch(in: context)
            }
            guard state == .asking, var current = queue, let id = current.currentCardID else {
                currentCard = nil
                return
            }

            if let card = card(with: id, in: context) {
                currentCard = card
                return
            }

            // The card was deleted while the session was running (§9). It is
            // skipped rather than rated, and it leaves the pool so a later
            // batch cannot pick it again.
            current.skipCurrentCard()
            queue = current
            pool.removeAll { $0.id == id }
        }
    }

    /// Selects the next mini-batch. No screen, no summary, no interruption —
    /// for the user the session simply continues (§5, task 6.7).
    private func startNextBatch(in context: ModelContext) {
        if let finished = queue {
            previousBatchIDs = Set(finished.cardIDs)
        }
        guard pool.isEmpty == false else {
            state = .empty
            queue = nil
            currentCard = nil
            return
        }

        // Statuses change while the session runs, and the weighting reads
        // them — so the pool's snapshots are refreshed from the store before
        // the next draw rather than kept at their start-of-session values.
        pool = refreshedPool(in: context)
        guard pool.isEmpty == false else {
            state = .empty
            queue = nil
            currentCard = nil
            return
        }

        let batch = BatchSelector.selectBatch(
            from: pool,
            previousBatchIDs: previousBatchIDs,
            using: &generator
        )
        queue = SessionQueue(cards: batch)
        state = .asking
    }

    /// The pool's cards with their current status.
    ///
    /// The membership stays the pool's own — nothing is added, because §2
    /// builds the pool once at the start. What is refreshed is the status,
    /// and that is the weighting's input (§3.1): without this, a card just
    /// rated *Sicher* would keep being drawn with weight 5.0 for the rest of
    /// the session, which is the opposite of what §1 asks for. Cards that no
    /// longer exist, or that no longer belong to this session's type, drop
    /// out — the latter can only happen if the user edits the card's type
    /// mid-session, and letting it stay would be the one way words and
    /// sentences could still mix.
    ///
    /// One fetch, then matching in Swift: a fetch per card would be a few
    /// hundred round trips at every batch change.
    private func refreshedPool(in context: ModelContext) -> [CardSnapshot] {
        let ids = Set(pool.map(\.id))
        let cards = Self.cards(with: ids, in: context)
        let byID = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return pool.compactMap { snapshot in
            guard let card = byID[snapshot.id], card.type == configuration.cardType else { return nil }
            return CardSnapshot(id: card.id, status: card.status)
        }
    }

    /// The cards for a set of ids, in one fetch.
    private static func cards(with ids: Set<UUID>, in context: ModelContext) -> [Card] {
        let descriptor = FetchDescriptor<Card>(predicate: #Predicate { ids.contains($0.id) })
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Pool could not be refreshed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Looks a card up by its id, or `nil` when it no longer exists.
    ///
    /// Fetched every time instead of held: a `Card` reference to a deleted
    /// object is not safe to touch, and the current content is what should be
    /// shown.
    private func card(with id: UUID, in context: ModelContext) -> Card? {
        var descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            Self.logger.error("Card \(id, privacy: .public) could not be read: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static let logger = Logger(subsystem: "de.belaunsch.CApp", category: "learning")
}
