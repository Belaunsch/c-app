//
//  SessionQueue.swift
//  CApp
//

import Foundation

/// What one self-assessment did, and what the feature layer has to write
/// because of it.
///
/// Small on purpose. `docs/learning-engine.md` §7 lists exactly what phase 6
/// needs after every answer, and this carries it without that layer having to
/// reconstruct anything about the queue: no event bus, no command objects, no
/// state machine.
nonisolated struct AssessmentOutcome: Equatable, Sendable {

    /// The card that was just rated.
    let cardID: UUID

    let assessment: SelfAssessment

    /// Whether this was the card's **first** rating in this mini-batch.
    let wasFirstAssessmentInBatch: Bool

    /// The status to store, or `nil` when the status must stay as it is.
    ///
    /// Non-nil exactly on the first rating of a card per batch (§6.1): the
    /// first attempt is the honest indicator, so a later "Gut" in the same
    /// batch must not lift a card that was not known at first.
    let newStatus: LearningStatus?

    /// Whether the card was put back into the batch for another try.
    let wasReinserted: Bool

    /// Whether the batch is finished, meaning every card in it is resolved.
    let isBatchFinished: Bool

    /// Whether `correctCount` should go up (§7). `reviewCount` goes up for
    /// every outcome, so it needs no flag.
    var countsAsCorrect: Bool { assessment.countsAsCorrect }

    /// The complement of `wasReinserted`: the card has left the batch.
    var isResolved: Bool { wasReinserted == false }
}

/// The order the cards of one mini-batch are asked in, and how a card that
/// was not known comes back.
///
/// A value type holding ids, never card contents — a card edited during the
/// session simply shows its new text next time it comes up
/// (`docs/learning-engine.md` §9).
///
/// The rule from §5, in one sentence: **every** assessment removes the
/// current card from the queue, and "Nochmal" then puts it back
/// `reinsertGap` positions later. Because removal makes the next card slide
/// into the current position, the index never advances — the current card is
/// always the first one.
///
/// Termination is a property of this type, not of the UI driving it: a card
/// may be reinserted at most `maxReinserts` times, after which it counts as
/// resolved. A pool of one card answered "Nochmal" forever therefore ends
/// after `maxReinserts + 1` questions.
nonisolated struct SessionQueue: Equatable, Sendable {

    /// The cards still to ask, in order. The first one is the current card.
    private(set) var pending: [UUID]

    /// How often each card has been put back so far.
    private var reinsertCounts: [UUID: Int] = [:]

    /// The cards that have been rated at least once in this batch.
    private var assessedCardIDs: Set<UUID> = []

    /// The ids of every card in this batch, for the next batch's recency
    /// damping (§3.2). Kept because the queue empties as cards resolve.
    let cardIDs: [UUID]

    init(cards: [CardSnapshot]) {
        self.init(cardIDs: cards.map(\.id))
    }

    init(cardIDs: [UUID]) {
        self.cardIDs = cardIDs
        pending = cardIDs
    }

    /// The card to show now, or `nil` when the batch is finished.
    var currentCardID: UUID? { pending.first }

    /// Whether every card of this batch is resolved.
    var isFinished: Bool { pending.isEmpty }

    /// How often `cardID` has been put back into this batch.
    func reinsertCount(for cardID: UUID) -> Int {
        reinsertCounts[cardID, default: 0]
    }

    /// Records one self-assessment of the current card.
    ///
    /// - Parameter currentStatus: the card's status *now*, which only the
    ///   feature layer knows — the queue holds no card contents. It is used
    ///   for the status transition, and only on the card's first rating in
    ///   this batch.
    /// - Returns: what to write and what happened, or `nil` when the batch is
    ///   already finished. Returning `nil` rather than trapping: a mis-wired
    ///   caller should not crash in front of the user.
    @discardableResult
    mutating func assess(
        _ assessment: SelfAssessment,
        currentStatus: LearningStatus
    ) -> AssessmentOutcome? {
        guard let cardID = pending.first else { return nil }

        let isFirstAssessment = assessedCardIDs.contains(cardID) == false
        assessedCardIDs.insert(cardID)

        // Every assessment removes the current card first. That is what makes
        // the reinsert positions in §5 come out right, and it is why the
        // index never has to move.
        pending.removeFirst()

        let reinserted = reinsert(cardID, after: assessment)

        return AssessmentOutcome(
            cardID: cardID,
            assessment: assessment,
            wasFirstAssessmentInBatch: isFirstAssessment,
            newStatus: isFirstAssessment
                ? StatusTransition.newStatus(from: currentStatus, for: assessment)
                : nil,
            wasReinserted: reinserted,
            isBatchFinished: pending.isEmpty
        )
    }

    /// Drops the current card without rating it.
    ///
    /// For the one case §9 names: a card deleted while the session runs. Its
    /// id can no longer be resolved, so it is skipped when moving on. It does
    /// **not** count as a review — no outcome, no counters, no status change.
    ///
    /// Two things to know when driving this from the feature layer, because
    /// both are easy to get wrong: it returns no outcome, so a caller that
    /// follows `isBatchFinished` has to check `isFinished` after a skip; and
    /// a card that had already been reinserted still sits in the queue a
    /// second time, so it will come up again and has to be skipped again.
    mutating func skipCurrentCard() {
        guard pending.isEmpty == false else { return }
        pending.removeFirst()
    }

    /// Puts the card back if the answer asks for it and the limit allows.
    /// - Returns: whether it went back in.
    private mutating func reinsert(_ cardID: UUID, after assessment: SelfAssessment) -> Bool {
        guard assessment.keepsCardInBatch else { return false }
        guard reinsertCount(for: cardID) < LearningParameters.maxReinserts else {
            // The limit is reached: the card counts as resolved and leaves the
            // batch. Without this a batch could never end.
            return false
        }

        let position = LearningParameters.reinsertGap
        if position >= pending.count {
            // Fewer than `reinsertGap` cards left, so the repetition goes as
            // late as this batch still allows.
            pending.append(cardID)
        } else {
            pending.insert(cardID, at: position)
        }
        reinsertCounts[cardID, default: 0] += 1
        return true
    }
}
