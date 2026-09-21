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
/// selection, the reinsert gap, `maxReinserts`, the transition matrix and the
/// classification rule all come from `Learning/`, which phase 5 tested on its
/// own. Reimplementing any of it here would mean two sources of truth, and the
/// one with tests would lose.
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
    /// closing an attempt: only a revealed card can be closed, and closing it
    /// clears the flag.
    private(set) var isRevealed = false

    /// Mode B's middle step: the Hanzi is on screen, the meaning is not.
    ///
    /// Beside `isRevealed` rather than replacing it, so mode A and the closing
    /// paths keep the exact token they have used since phase 6. Meaningless in
    /// mode A, where nothing ever sets it.
    private(set) var hasShownHanzi = false

    /// One offered classification, together with the status it was worked out
    /// from.
    ///
    /// **Both halves, because an offer expires.** The learning session is a push
    /// *inside* the Lernen tab, so the tab bar stays reachable: the learner can
    /// leave a revealed card standing, correct that same card by hand in the card
    /// list, and come back. Without remembering where the offer started, tapping
    /// „Bestätigen" would then undo the correction — the one direction this app
    /// has no other way of going (A46) — and the bar would meanwhile read
    /// „Schwach → Gut", two rungs, against the rule it is supposed to obey.
    ///
    /// Found in review. Before the manual correction existed the interleaving was
    /// impossible, because `card.status` was only ever written here.
    private struct StatusProposal: Equatable {
        let from: LearningStatus
        let to: LearningStatus
    }

    private var proposal: StatusProposal?

    /// The status the app offers for the card on screen, or `nil` when there is
    /// nothing to offer (phase 13).
    ///
    /// An offer and nothing else: the status changes when the learner taps
    /// „Bestätigen", never because this is set.
    ///
    /// **Derived rather than stored**, so an offer that has gone stale disappears
    /// everywhere at once — the bar falls back to „Weiter", and both
    /// `acceptProposal` and `declineProposal` refuse. One check, every reader.
    var proposedStatus: LearningStatus? {
        guard let proposal, let card = currentCard, proposal.from == card.status else { return nil }
        return proposal.to
    }

    /// Whether the microphone was used for the attempt currently on screen.
    private var usedSpeechThisAttempt = false

    /// Whether the answer on screen was uncovered by hand rather than earned.
    private var revealedByHand = false

    /// Whether a recording could have run on the card on screen.
    ///
    /// Captured **when the card is revealed**, not when the attempt is closed:
    /// the recognition phase can change in between, and whether the learner had
    /// the option to speak is not up for debate afterwards. It decides the
    /// reinsertion and nothing else — which is why it is view state here rather
    /// than a field in the store (`docs/learning-engine.md` §13.5, §13.10).
    private var recordingWasPossible = false

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

    /// How many attempts this session has closed. Shown as a plain number,
    /// never as a target — the session has no natural end.
    private(set) var answeredCount = 0

    /// Set when writing failed. The card stays where it is so the same
    /// decision can be made again.
    private(set) var saveFailure: AppError?

    // MARK: - Engine state

    /// The cards this session may draw from, built once at the start.
    ///
    /// Shrinks only when an id turns out to be unresolvable, which is how a
    /// card deleted mid-session leaves the session (§9).
    private(set) var pool: [CardSnapshot] = []

    private var queue: SessionQueue?

    /// How many cards the current batch was built with.
    ///
    /// Recorded rather than derived, and honestly: no view shows it — it
    /// exists so the promise the settings make („gilt ab der nächsten Runde,
    /// eine laufende Runde wird nicht umgebaut") is a checkable fact instead
    /// of a claim about where a line of code sits. `0` before the first
    /// batch.
    private(set) var currentBatchSize = 0

    /// The previous batch's ids, for the recency damping in `CardWeighting`.
    private var previousBatchIDs: Set<UUID> = []

    /// Injected so the selection stays reproducible in tests. The engine
    /// takes `inout some RandomNumberGenerator`, which is why this is a
    /// concrete wrapper rather than an existential.
    private var generator: AnyRandomNumberGenerator

    /// Injected so `lastReviewedAt` is checkable exactly. Production passes
    /// the real clock; `Learning/` itself has no clock at all.
    private let now: () -> Date

    /// Where the batch size is read from.
    ///
    /// Injected for the same reason as the clock and the generator: the
    /// promise in the settings — „gilt ab der nächsten Runde, eine laufende
    /// Runde wird nicht umgebaut" — is a statement about *when* this is
    /// read, and without a seam that statement could only be re-read in the
    /// code, never checked.
    private let defaults: UserDefaults

    init(
        configuration: SessionConfiguration,
        generator: AnyRandomNumberGenerator = AnyRandomNumberGenerator(),
        now: @escaping () -> Date = Date.init,
        defaults: UserDefaults = .standard
    ) {
        self.configuration = configuration
        self.generator = generator
        self.now = now
        self.defaults = defaults
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

    /// Uncovers the answer because the learner asked for it — „Aufgeben" in
    /// mode A, „Antwort zeigen" in mode B.
    ///
    /// - Parameter recordingWasPossible: whether a recording could have run on
    ///   this card. Only mode A ever passes `true`, and only there does it mean
    ///   anything: it is the third condition of the reinsertion (§13.5).
    ///
    /// **No default value, deliberately.** A default of `false` would silently
    /// switch the reinsertion off at any call site that forgot the argument —
    /// which in mode A is a lost repetition nobody notices, because the card
    /// simply does not come back. Mode B passes `false` explicitly, and that
    /// reads as the statement it is.
    func reveal(recordingWasPossible: Bool) {
        guard currentCard != nil else { return }
        // Uncovering by hand is not a recall (phase 11). It is remembered for
        // the review entry and it rules out every automatic shortcut: a
        // learner who reads the answer and then says it has demonstrated
        // reading aloud.
        revealedByHand = true
        self.recordingWasPossible = recordingWasPossible
        // No evidence, so no offer. The rule would reach the same conclusion —
        // a manual reveal is never a clean attempt — but the app must not even
        // look like it is weighing one up here.
        proposal = nil
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
        let check = SpeechCheck.compare(recognized: recognized, expected: card.hanzi)
        speechCheck = check
        usedSpeechThisAttempt = true
        isRevealed = true

        // Phase 13: enough repeated clean evidence means the app offers one step
        // up. The rule lives in `Learning/`; this only carries out what it
        // decided, and it decides nothing else — no status moves here.
        proposal = AssistedAssessment.decision(
            currentStatus: card.status,
            current: attemptSignal(for: card),
            history: recentSignals(for: card)
        ).proposedStatus.map { StatusProposal(from: card.status, to: $0) }
    }

    /// Closes the attempt with a plain „Weiter": nothing was offered, or the
    /// learner is simply moving on.
    func moveOn(in context: ModelContext) {
        closeAttempt(.none, in: context)
    }

    /// The learner accepted the offered classification.
    ///
    /// Takes **exactly** the status the rule proposed — not a second derivation
    /// of it. `StatusTransition` is where that value comes into being; two
    /// routes to the same value would be two truths.
    /// - Note: reads `proposedStatus`, which is `nil` once the offer has gone
    ///   stale — so a card corrected by hand in the meantime cannot be pushed
    ///   back up by a tap on „Bestätigen".
    func acceptProposal(in context: ModelContext) {
        guard let offered = proposedStatus else { return }
        closeAttempt(.accepted(offered), in: context)
    }

    /// The learner declined the offered classification.
    ///
    /// **The neutral way out.** The status stays exactly as it is; what changes
    /// is that the decline is recorded, so the evidence for this particular step
    /// starts over and the same offer does not come back on the next clean
    /// attempt (`docs/learning-engine.md` §13.7, rule 4).
    /// - Note: same staleness guard as `acceptProposal`. Declining an expired
    ///   offer would record a `suggestedStatus` against a `previousStatus` it was
    ///   never computed from, and that entry is the only calibration data the
    ///   project has (§13.10).
    func declineProposal(in context: ModelContext) {
        guard let offered = proposedStatus else { return }
        closeAttempt(.declined(offered), in: context)
    }

    /// What became of an offered classification, if one was offered.
    private enum ProposalOutcome {
        case none
        case accepted(LearningStatus)
        case declined(LearningStatus)

        var suggestedStatus: LearningStatus? {
            switch self {
            case .none: nil
            case .accepted(let status), .declined(let status): status
            }
        }

        var decision: SuggestionDecision? {
            switch self {
            case .none: nil
            case .accepted: .accepted
            case .declined: .declined
            }
        }
    }

    /// Records one finished attempt: engine first, then the store, then the
    /// session state.
    ///
    /// The order is the whole point. `SessionQueue` is a value type, so the
    /// engine's advance happens on a copy and is only kept once the write
    /// succeeded. A failed save therefore leaves the queue exactly where it
    /// was: the same card comes up again, the offer is still on screen, and
    /// answering it a second time counts once, not twice. That is the simplest
    /// arrangement that cannot drift apart — no transactions, no event log.
    ///
    /// The failure path has no automated test: a read-only store provokes it
    /// reliably on its own but not inside the parallel suite, for reasons I
    /// could not establish, and the alternative would be a save closure that
    /// exists purely so a test can throw. What *is* pinned is the property
    /// this order rests on — advancing a copy leaves the original alone, see
    /// `SessionQueueTests.advancingACopyDoesNotAffectTheOriginal`.
    private func closeAttempt(_ outcome: ProposalOutcome, in context: ModelContext) {
        // Only a revealed card can be closed, and closing clears the flag.
        // That makes this the double-tap guard as well: a second tap arriving
        // before the view redraws finds nothing revealed and does nothing.
        guard isRevealed, let card = currentCard, var advanced = queue else { return }

        // Whether the card comes back in this batch is decided **before** the
        // queue moves, because it depends on how this attempt ended (§13.5).
        let reinserting = LearnFlow.reinserts(
            in: configuration.direction,
            wasManualReveal: revealedByHand,
            recordingWasPossible: recordingWasPossible
        )
        // Read **before** the queue closes the card: afterwards the reinsert
        // count has already moved on, and the entry has to say whether *this*
        // attempt was a repeat.
        let wasRetry = isRetryOfCurrentCard(card)
        guard advanced.closeCurrentCard(reinserting: reinserting) else { return }
        isRevealed = false

        // Read **before** an accepted proposal moves it: the entry records the
        // status the card had going into this review, which is what later
        // evidence has to be read against.
        let previousStatus = card.status

        card.reviewCount += 1
        card.lastReviewedAt = now()
        // **`correctCount` deliberately does not move — on any path.** §7 defines
        // it through a self-assessment, and the new flow gives none: „Weiter"
        // and „Ablehnen" rate nothing, and „Bestätigen" is agreement with the
        // app rather than a rating. What lay before the app was a text
        // comparison whose false-accept property phase 9 never measured. The
        // consequence for `accuracy` — a derived value no view reads — is named
        // in `docs/learning-engine.md` §13.11 rather than papered over.
        if case .accepted(let newStatus) = outcome {
            card.status = newStatus
        }

        // The review entry is written **before** the save, so the card's new
        // status and its history are one transaction: a failed save rolls
        // both back together and the learner decides on the same card again.
        context.insert(reviewLog(
            for: card,
            previousStatus: previousStatus,
            wasRetry: wasRetry,
            outcome: outcome
        ))
        do {
            try context.save()
        } catch {
            // Undo the card's changes so the alert cannot claim failure while
            // a later save commits them anyway — and leave the queue alone,
            // so the user decides on the same card again rather than a new one.
            context.rollback()
            isRevealed = true
            // The offer stays as it was: it has to be back on screen, or an
            // alert would leave the learner on a revealed card with the question
            // gone.
            saveFailure = .cardSaveFailed(error)
            Self.logger.error("Attempt could not be saved: \(error.localizedDescription, privacy: .public)")
            return
        }

        queue = advanced
        answeredCount += 1
        // The next card starts covered again. Reset here rather than where
        // `currentCard` is assigned, because this is the one path from one
        // card to the next — and because a failed save above returns before
        // it, leaving the user on the same card exactly as they left it.
        resetAttemptState()
        advanceToNextAnswerableCard(in: context)
    }

    /// The attempt on screen, as the engine sees it.
    private func attemptSignal(for card: Card) -> ReviewSignal {
        ReviewSignal(
            direction: configuration.direction,
            previousStatus: card.status,
            usedSpeech: usedSpeechThisAttempt,
            speechMatched: speechCheck?.isMatch,
            wasManualReveal: revealedByHand,
            wasRetry: isRetryOfCurrentCard(card),
            // The running attempt carries no declined offer of its own — a
            // decline is recorded on the entry this attempt produces, and it is
            // the *history* that carries it into the next decision.
            declinedSuggestion: nil
        )
    }

    /// The card's earlier reviews that may count as evidence: newest first,
    /// bounded above by the window and below by the learner's last correction.
    ///
    /// Sorted here rather than in the store: a SwiftData relationship is
    /// unordered, and the engine is given a sequence whose order it may rely on.
    ///
    /// **Both bounds belong here rather than in `Learning/`**, and for the same
    /// reason: they decide *which history is handed over*, not what the rule
    /// concludes from it. `windowSize` has always been an upper bound applied at
    /// this boundary (§12.5), and the correction line is the matching lower one.
    /// The engine keeps no clock and `ReviewSignal` keeps no timestamp — putting a
    /// date comparison inside the rule would give both of them one.
    ///
    /// The filter runs before the window because that reads more clearly, **not**
    /// because the order matters: eligibility is monotone in time — eligible means
    /// „newer than the line" — so filtering before or after the newest-first cut
    /// yields the same set. An earlier version of this comment claimed the order
    /// protected something, which taught an invariant that does not exist.
    private func recentSignals(for card: Card) -> [ReviewSignal] {
        card.reviews
            .filter { Self.countsAsEvidence($0, for: card) }
            .sorted { $0.reviewedAt > $1.reviewedAt }
            .prefix(AssistedAssessment.windowSize)
            .map(\.signal)
    }

    /// Whether one stored review is on the eligible side of the learner's last
    /// hand-picked status.
    ///
    /// A card that went *Mittel* → *Sicher* and was corrected back to *Mittel*
    /// still carries its old *Mittel*-era reviews, and the same-status rule finds
    /// those comparable again — so without this line the very next clean attempt
    /// would offer the promotion the learner had just taken away.
    ///
    /// **Strictly after**, so a review written in the same instant as a correction
    /// does not count: the correction is the later statement of the two, and at
    /// equal timestamps the tie has to fall on the side that respects it.
    ///
    /// `nil` — never corrected — means everything is eligible, which is also what
    /// every card written before phase 13 reads back as.
    ///
    /// Static and taking the card explicitly, so it can be checked without a
    /// session.
    static func countsAsEvidence(_ review: ReviewLog, for card: Card) -> Bool {
        guard let boundary = card.classificationEvidenceResetAt else { return true }
        return review.reviewedAt > boundary
    }

    /// Whether the card on screen has already been through this batch.
    ///
    /// Read from the queue rather than tracked separately: it already knows,
    /// because reinsertion is its job.
    private func isRetryOfCurrentCard(_ card: Card) -> Bool {
        (queue?.reinsertCount(for: card.id) ?? 0) > 0
    }

    /// One finished attempt, as the store records it.
    ///
    /// **`assessment` is always `nil` here**, and that is the point: the field
    /// means „the learner picked one of the four buttons of the old flow", and
    /// this flow has none. An accepted classification goes into its own two
    /// fields instead, because it is agreement with the app rather than a
    /// self-assessment — merging them would make the two indistinguishable
    /// retroactively (`docs/learning-engine.md` §13.10).
    private func reviewLog(
        for card: Card,
        previousStatus: LearningStatus,
        wasRetry: Bool,
        outcome: ProposalOutcome
    ) -> ReviewLog {
        ReviewLog(
            reviewedAt: now(),
            direction: configuration.direction,
            previousStatus: previousStatus,
            usedSpeech: usedSpeechThisAttempt,
            speechMatched: speechCheck?.isMatch,
            wasManualReveal: revealedByHand,
            wasRetry: wasRetry,
            assessment: nil,
            suggestedStatus: outcome.suggestedStatus,
            suggestionDecision: outcome.decision,
            card: card
        )
    }

    /// Everything that belongs to the attempt just finished.
    private func resetAttemptState() {
        hasShownHanzi = false
        speechCheck = nil
        proposal = nil
        usedSpeechThisAttempt = false
        revealedByHand = false
        recordingWasPossible = false
    }

    func dismissSaveFailure() {
        saveFailure = nil
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

        // Read here, at the start of a batch — never mid-batch. Changing the
        // size in the settings while a session runs must not rebuild the
        // window the learner is currently working through; the next batch
        // picks it up, which is the first moment it means anything.
        let size = Preferences.currentBatchSize(defaults)
        let batch = BatchSelector.selectBatch(
            from: pool,
            previousBatchIDs: previousBatchIDs,
            batchSize: size,
            using: &generator
        )
        currentBatchSize = size
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
