//
//  SessionQueue.swift
//  CApp
//

import Foundation

/// The order the cards of one mini-batch are asked in, and how a card that
/// was not known comes back.
///
/// A value type holding ids, never card contents — a card edited during the
/// session simply shows its new text next time it comes up
/// (`docs/learning-engine.md` §9).
///
/// The rule from §5, in one sentence: **every** finished attempt removes the
/// current card from the queue, and giving up puts it back later. Because
/// removal makes the next card slide into the current position, the index never
/// advances — the current card is always the first one.
///
/// **Since phase 13 the trigger is an attempt, not a self-assessment.** The
/// four ratings left the learning flow, so the only statement about not knowing
/// a card is „Aufgeben", and that is what puts a card back. Everything else
/// about this type is unchanged: where a repetition lands, how often, and when
/// a batch ends. A mismatch deliberately does **not** reinsert — it is not
/// negative evidence, and scheduling on it would be acting on a signal the app
/// says it does not trust.
///
/// How much later is the part the device test corrected. A repetition goes
/// **after every card that has not had its first attempt yet**, and at least
/// `reinsertGap` positions away. The fixed gap alone produced a cycle: with
/// `A B C D E F G` and the first four given up on, each repetition
/// landed three places on and the batch ran `A B C D A B C D` while E, F and
/// G had never been shown. Technically finite, but it feels like a loop, and
/// it drills four cards instead of introducing the other three.
///
/// Termination is a property of this type, not of the UI driving it: a card
/// may be reinserted at most `maxReinserts` times, after which it counts as
/// resolved. A pool of one card given up on forever therefore ends
/// after `maxReinserts + 1` questions.
nonisolated struct SessionQueue: Equatable, Sendable {

    /// The cards still to ask, in order. The first one is the current card.
    private(set) var pending: [UUID]

    /// How often each card has been put back so far.
    private var reinsertCounts: [UUID: Int] = [:]

    /// The cards that have had at least one finished attempt in this batch.
    private var attemptedCardIDs: Set<UUID> = []

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
    ///
    /// Also the feature layer's answer to „is this a retry?" — a card that has
    /// been put back is on its second run through the batch.
    func reinsertCount(for cardID: UUID) -> Int {
        reinsertCounts[cardID, default: 0]
    }

    /// Closes the current card's attempt and moves the batch on.
    ///
    /// - Parameter reinserting: whether the card goes back into this batch for
    ///   another try. The feature layer decides that from the learner's action
    ///   („Aufgeben") and from whether a recording was possible at all — the
    ///   queue holds no card contents and knows nothing about microphones
    ///   (`docs/learning-engine.md` §13.5).
    /// - Returns: whether a card was closed. `false` when the batch was already
    ///   finished — returning rather than trapping, because a mis-wired caller
    ///   should not crash in front of the user.
    ///
    /// **It deliberately returns no outcome object.** Phase 12 returned one
    /// carrying the new status, whether this was the first rating and whether
    /// the batch is finished. None of that has a reader any more: the status is
    /// written only when the learner confirms a suggestion, „first attempt in
    /// the batch" is answered by `reinsertCount(for:)` where it is needed, and
    /// the caller asks `isFinished` directly. A returned value nobody reads is
    /// a promise without cover.
    @discardableResult
    mutating func closeCurrentCard(reinserting: Bool) -> Bool {
        guard let cardID = pending.first else { return false }

        attemptedCardIDs.insert(cardID)

        // Closing removes the current card first. That is what makes the
        // reinsert positions in §5 come out right, and it is why the index
        // never has to move.
        pending.removeFirst()

        reinsert(cardID, if: reinserting)
        return true
    }

    /// Drops the current card without it counting as an attempt.
    ///
    /// For the one case §9 names: a card deleted while the session runs. Its
    /// id can no longer be resolved, so it is skipped when moving on. It does
    /// **not** count as a review — no counters, no status change, and unlike
    /// `closeCurrentCard(reinserting:)` it does not mark the card as attempted.
    ///
    /// One thing to know when driving this from the feature layer: a card that
    /// had already been reinserted still sits in the queue a second time, so it
    /// will come up again and has to be skipped again.
    mutating func skipCurrentCard() {
        guard pending.isEmpty == false else { return }
        pending.removeFirst()
    }

    /// Puts the card back if the caller asks for it and the limit allows.
    /// - Returns: whether it went back in.
    @discardableResult
    private mutating func reinsert(_ cardID: UUID, if shouldReinsert: Bool) -> Bool {
        guard shouldReinsert else { return false }
        guard reinsertCount(for: cardID) < LearningParameters.maxReinserts else {
            // The limit is reached: the card counts as resolved and leaves the
            // batch. Without this a batch could never end. Its low status
            // gives it a high weight, so the next batches will bring it back
            // — repetition over time is the weighting's job, not this
            // batch's.
            return false
        }

        // `insert(at: count)` is an append, so no separate case is needed for
        // "fewer cards left than the position asks for".
        pending.insert(cardID, at: min(reinsertPosition(), pending.count))
        reinsertCounts[cardID, default: 0] += 1
        return true
    }

    /// Where a repetition goes: behind every card still awaiting its first
    /// attempt, and never closer than `reinsertGap`.
    ///
    /// Both halves matter. Without the unseen boundary a run of give-ups
    /// cycles the same few cards while others are never shown — the
    /// device test found exactly that. Without the minimum gap a repetition
    /// in a batch whose cards have all been seen once would come straight
    /// back, which is what §5 rules out.
    private func reinsertPosition() -> Int {
        let behindUnseen = pending
            .lastIndex { attemptedCardIDs.contains($0) == false }
            .map { $0 + 1 } ?? 0
        return max(LearningParameters.reinsertGap, behindUnseen)
    }
}
