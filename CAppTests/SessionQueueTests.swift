//
//  SessionQueueTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// `docs/learning-engine.md` §10, mandatory tests 9 to 14 and 18.
///
/// The queue is fed fixed id orders rather than a selected batch, so nothing
/// here depends on the random selection — these tests are about the queue
/// alone.
///
/// **Since phase 13 the trigger is `closeCurrentCard(reinserting:)`, not a
/// self-assessment**, and `reinserting: true` is what „Aufgeben" produces. Every
/// rule below is the same rule as before: where a repetition lands, how often,
/// and when a batch ends. What is gone is §10's test 19 (`correctCount` per
/// assessment): the counter is defined through a self-assessment, the new flow
/// gives none, and it therefore stops moving — that is pinned in
/// `LearnSessionModelTests` where the counter is actually written, not here.
struct SessionQueueTests {

    /// Named ids, so the expectations read like the examples in §5.
    private struct Cards {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID(), f = UUID()
    }

    // §10, test 9 — rewritten after the phase-6 device test.
    @Test("A repetition goes behind every card that has not been seen yet")
    func reinsertGoesBehindUnseenCards() {
        // The rule the device test forced. Before it, a repetition went a
        // fixed three places on, and four cards given up on in a row cycled
        // among themselves while the rest of the batch was never shown.
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.c, cards.f, cards.b, cards.d])

        let closed = queue.closeCurrentCard(reinserting: true)

        #expect(closed)
        #expect(queue.reinsertCount(for: cards.a) == 1, "and it really went back in")
        #expect(queue.pending == [cards.c, cards.f, cards.b, cards.d, cards.a])
        #expect(queue.pending.last == cards.a, "behind all four unseen cards")
        #expect(queue.currentCardID != cards.a, "and never straight away")
    }

    // §10, test 9b: the minimum gap still governs once nothing is unseen.
    @Test("With nothing unseen left, the repetition keeps the minimum gap")
    func reinsertKeepsTheGapAmongSeenCards() {
        // Once every card has had its first attempt the unseen boundary is
        // gone and `reinsertGap` decides on its own — that is the lower half
        // of `max(reinsertGap, behindUnseen)`, and §5's original point: a
        // card must not come straight back.
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.b, cards.c, cards.d, cards.e])

        // Four give-ups. Each repetition lands behind the cards that are still
        // unseen, so after this exactly one unseen card is left and it is the
        // current one.
        for _ in 0..<4 {
            queue.closeCurrentCard(reinserting: true)
        }
        let last = queue.currentCardID
        #expect(last == cards.e, "the one card nobody has seen yet")

        // Its first attempt. Nothing unseen remains afterwards, so this
        // repetition is placed by the gap alone — which is the point.
        queue.closeCurrentCard(reinserting: true)

        #expect(queue.pending.count > LearningParameters.reinsertGap, "cards left to place it among")
        // Exact equality on purpose: §5 specifies the position as
        // `max(reinsertGap, behindUnseen)`, so the formula is what is pinned,
        // not merely the "at least" it implies. Placing the card even later
        // would satisfy the prose and still be a change nobody asked for.
        #expect(
            queue.pending.firstIndex(of: cards.e) == LearningParameters.reinsertGap,
            "the gap decides once nothing is unseen"
        )
    }

    // §10, test 9c: the rule that the device test was about.
    @Test("Several given-up cards in a row do not starve the unseen ones")
    func consecutiveFailuresDoNotStarveUnseenCards() {
        // Reproduces the reported sequence: seven cards, the first four all
        // given up on. What must follow is E, F, G — the cards nobody has
        // seen — not another round of A B C D.
        let ids = (0..<7).map { _ in UUID() }
        var queue = SessionQueue(cardIDs: ids)

        let failed = Array(ids.prefix(4))
        for expected in failed {
            #expect(queue.currentCardID == expected)
            queue.closeCurrentCard(reinserting: true)
        }

        // The next three questions are the three cards never shown.
        let unseen = Array(ids.suffix(3))
        for expected in unseen {
            #expect(queue.currentCardID == expected, "an unseen card must come before any repetition")
            queue.closeCurrentCard(reinserting: false)
        }

        // Only now do the repetitions follow.
        #expect(queue.pending.isEmpty == false)
        #expect(Set(queue.pending) == Set(failed), "and now the four repetitions")
    }

    // §10, test 9d: generalised, not a special case for four cards.
    @Test("Every card gets its first attempt before any repetition, at any batch size")
    func firstAttemptsComeFirstForEveryBatchSize() {
        for size in 2...LearningParameters.batchSize {
            let ids = (0..<size).map { _ in UUID() }
            var queue = SessionQueue(cardIDs: ids)

            var firstAttempts: Set<UUID> = []
            var sawRepetitionTooEarly = false

            // Give up on everything and watch the order.
            while let current = queue.currentCardID, firstAttempts.count < size {
                if firstAttempts.contains(current) {
                    // A card is coming back although not everything has been
                    // seen once — exactly what must not happen.
                    sawRepetitionTooEarly = true
                }
                firstAttempts.insert(current)
                queue.closeCurrentCard(reinserting: true)
            }

            #expect(sawRepetitionTooEarly == false, "size \(size): a repetition jumped an unseen card")
            #expect(firstAttempts.count == size, "size \(size): every card was asked once")
        }
    }

    // §10, test 10
    @Test("With too few cards left, the repeat goes to the end")
    func reinsertFallsBackToTheEnd() {
        // The clamp on its own. Built so that only the clamp can explain the
        // result: every remaining card has already been seen, so the unseen
        // boundary is zero and the gap asks for a position beyond the end.
        //
        // The audit found the earlier version blind here — it used a queue of
        // nothing but unseen cards, where "behind the unseen ones" and "past
        // the end" are the same place, so it could not tell the two rules
        // apart.
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.b, cards.c, cards.d])

        queue.closeCurrentCard(reinserting: true)    // A goes behind the unseen ones
        queue.closeCurrentCard(reinserting: false)   // B resolved
        queue.closeCurrentCard(reinserting: false)   // C resolved
        #expect(queue.pending == [cards.d, cards.a], "D unseen, A waiting")

        // D's first attempt. Afterwards only A is left, and A has been seen,
        // so the gap asks for position 3 in a queue of one.
        queue.closeCurrentCard(reinserting: true)

        #expect(queue.pending == [cards.a, cards.d], "appended, as late as the batch allows")
        #expect(queue.pending.last == cards.d)
    }

    // §10, test 11
    @Test("After maxReinserts the card leaves the batch")
    func maxReinsertsEndsTheRepetition() {
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.b, cards.c, cards.d])

        // Give up on A every time it comes up.
        // Derived, and checked: a limit that silently runs out would make the
        // count below wrong for the wrong reason.
        let safetyLimit = 4 * (LearningParameters.maxReinserts + 1)
        var questions = 0
        while let current = queue.currentCardID, questions < safetyLimit {
            questions += 1
            queue.closeCurrentCard(reinserting: current == cards.a)
        }
        #expect(questions < safetyLimit, "the queue is not terminating")

        #expect(
            queue.reinsertCount(for: cards.a) == LearningParameters.maxReinserts,
            "exactly the configured number of repetitions, no more"
        )
        #expect(queue.isFinished, "the give-up past the limit resolves the card instead of extending the batch")
    }

    // §10, test 12
    @Test("Closing without reinsertion removes the card from the queue immediately")
    func closingResolvesAtOnce() {
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.b])

        let closed = queue.closeCurrentCard(reinserting: false)

        #expect(closed)
        #expect(queue.reinsertCount(for: cards.a) == 0, "nothing went back in")
        #expect(queue.pending == [cards.b], "A is gone, not moved")
        #expect(queue.currentCardID == cards.b)
    }

    // Phase 13: the one thing the queue must *not* do on its own.
    @Test("The queue never reinserts unless the caller asks")
    func theQueueNeverReinsertsByItself() {
        // The decision lives in the feature layer (`LearnFlow.reinserts`), and
        // this is the half the queue owes: `false` means gone, every time, for
        // every card. It is also the counter-mutation guard for a mismatch — a
        // mismatch closes with `false`, and if the queue ever reinserted on its
        // own that would silently become a repetition rule based on evidence the
        // app says it does not trust.
        let ids = (0..<LearningParameters.batchSize).map { _ in UUID() }
        var queue = SessionQueue(cardIDs: ids)

        var questions = 0
        while queue.isFinished == false, questions <= ids.count {
            questions += 1
            queue.closeCurrentCard(reinserting: false)
        }

        #expect(questions == ids.count, "one question per card, and not one more")
        for id in ids {
            #expect(queue.reinsertCount(for: id) == 0, "\(id) came back although nobody asked")
        }
    }

    // §10, test 13
    @Test("A batch ends only once every card is resolved")
    func batchEndsWhenAllResolved() {
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.b, cards.c])

        var closed = queue.closeCurrentCard(reinserting: false)
        #expect(closed)
        #expect(queue.isFinished == false)

        closed = queue.closeCurrentCard(reinserting: false)
        #expect(closed)
        #expect(queue.isFinished == false)

        // Still not finished while a repetition is outstanding, even though
        // every card has been seen once.
        closed = queue.closeCurrentCard(reinserting: true)
        #expect(closed)
        #expect(queue.isFinished == false, "the repetition of C is still queued")

        closed = queue.closeCurrentCard(reinserting: false)
        #expect(closed)
        #expect(queue.isFinished)
        #expect(queue.currentCardID == nil)

        closed = queue.closeCurrentCard(reinserting: false)
        #expect(closed == false, "nothing left to close")
        closed = queue.closeCurrentCard(reinserting: true)
        #expect(closed == false, "and nothing to put back either")
    }

    // Additional, and the number the device test was actually about: how long
    // a batch can get. §5 and `LearningParameters` both claim
    // `batchSize × (1 + maxReinserts)`, and until the audit pointed it out
    // nothing checked it — a change to `maxReinserts` was noticed only by the
    // parameter table, not by its user-visible consequence.
    @Test("A full batch given up on throughout is exactly as long as promised")
    func fullBatchLengthMatchesThePromise() {
        let ids = (0..<LearningParameters.batchSize).map { _ in UUID() }
        var queue = SessionQueue(cardIDs: ids)

        let promised = LearningParameters.batchSize * (1 + LearningParameters.maxReinserts)
        var questions = 0
        while queue.isFinished == false, questions <= promised {
            questions += 1
            queue.closeCurrentCard(reinserting: true)
        }

        #expect(queue.isFinished, "the batch has to end")
        #expect(questions == promised, "\(questions) questions instead of \(promised)")

        // Every card was asked exactly `1 + maxReinserts` times, so no card
        // carried the batch while another was dropped early.
        for id in ids {
            #expect(queue.reinsertCount(for: id) == LearningParameters.maxReinserts, "one card was treated differently")
        }
    }

    // §10, test 14
    @Test("A batch of one card given up on forever still terminates")
    func singleCardBatchTerminates() {
        // The invariant, not just the output: termination must come from the
        // queue itself, never from the UI happening to stop asking.
        let card = UUID()
        var queue = SessionQueue(cardIDs: [card])

        var questions = 0
        let safetyLimit = LearningParameters.maxReinserts + 10
        while queue.isFinished == false {
            questions += 1
            #expect(questions <= safetyLimit, "the queue is not terminating")
            if questions > safetyLimit { break }
            queue.closeCurrentCard(reinserting: true)
        }

        #expect(queue.isFinished)
        // One first question plus the permitted repetitions.
        #expect(questions == LearningParameters.maxReinserts + 1)
    }

    // §10, test 18
    @Test("Every closed attempt is reported, repetitions included")
    func everyAttemptIsReported() {
        // `reviewCount` is the feature layer's to write; what the engine owes is
        // one `true` per closed attempt, so counting them gives the increments.
        let card = UUID()
        var queue = SessionQueue(cardIDs: [card])

        // Bounded on purpose. The loop's end depends on exactly the
        // mechanism this test is meant to check, so without a limit a broken
        // `maxReinserts` would hang the suite instead of failing it — the
        // worst possible outcome for a test.
        let safetyLimit = LearningParameters.maxReinserts + 10
        var closed = 0
        while closed < safetyLimit, queue.closeCurrentCard(reinserting: true) {
            closed += 1
        }
        #expect(closed < safetyLimit, "the queue is not terminating")

        #expect(closed == LearningParameters.maxReinserts + 1, "one close per question, repetitions included")
        #expect(queue.reinsertCount(for: card) == LearningParameters.maxReinserts)
    }

    // Additional, for the edge case in §9 that has no numbered test: a card
    // deleted mid-session.
    @Test("A skipped card leaves the batch without counting as an attempt")
    func skippingDoesNotCountAsAnAttempt() {
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.b])

        queue.skipCurrentCard()

        #expect(queue.pending == [cards.b])
        #expect(queue.currentCardID == cards.b)
        #expect(queue.reinsertCount(for: cards.a) == 0, "a skip never puts a card back")
        // A skip reports nothing, so the feature layer has nothing to write —
        // which is the point: a deleted card is not a review.
        queue.skipCurrentCard()
        #expect(queue.isFinished)
        queue.skipCurrentCard()
        #expect(queue.isFinished, "skipping an empty queue is harmless")
    }

    // Additional: the property the feature layer's persistence order rests
    // on. `LearnSessionModel.closeAttempt` advances a *copy* of the queue and
    // keeps it only after the write succeeded, so a failed save leaves the same
    // card in place. That only works because this is a value type — and
    // nothing asserted it until the audit pointed it out.
    @Test("Advancing a copy leaves the original untouched")
    func advancingACopyDoesNotAffectTheOriginal() {
        let cards = Cards()
        let original = SessionQueue(cardIDs: [cards.a, cards.b, cards.c])

        var copy = original
        let closed = copy.closeCurrentCard(reinserting: true)
        #expect(closed, "the copy advanced")

        #expect(copy.currentCardID == cards.b)
        #expect(copy.reinsertCount(for: cards.a) == 1)
        #expect(original.currentCardID == cards.a, "the original still asks the same card")
        #expect(original.pending == [cards.a, cards.b, cards.c])
        #expect(original.reinsertCount(for: cards.a) == 0, "and has no repetition recorded")

        // Which means closing again from the original is still the card's first
        // attempt — the retry after a failed save must not be treated as a
        // repetition, because that is what `wasRetry` is read from.
        var retry = original
        let retried = retry.closeCurrentCard(reinserting: true)
        #expect(retried)
        #expect(retry.reinsertCount(for: cards.a) == 1, "counted once, not twice")
    }

    // Additional: the ids of a finished batch have to survive for the next
    // batch's recency damping, which the queue empties as it goes.
    @Test("The batch remembers its cards after the queue has emptied")
    func batchIDsSurviveTheBatch() {
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.b])
        queue.closeCurrentCard(reinserting: false)
        queue.closeCurrentCard(reinserting: false)

        #expect(queue.isFinished)
        #expect(queue.cardIDs == [cards.a, cards.b])
    }
}
