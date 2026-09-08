//
//  SessionQueueTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// `docs/learning-engine.md` §10, mandatory tests 9 to 14 and 18 to 19.
///
/// The queue is fed fixed id orders rather than a selected batch, so nothing
/// here depends on the random selection — these tests are about the queue
/// alone.
struct SessionQueueTests {

    /// Named ids, so the expectations read like the examples in §5.
    private struct Cards {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID(), f = UUID()
    }

    // §10, test 9
    @Test("After Nochmal exactly reinsertGap other cards come before the repeat")
    func reinsertLeavesExactlyTheGap() {
        // The example from §5: queue [A, C, F, B, D], A rated "Nochmal".
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.c, cards.f, cards.b, cards.d])

        let outcome = queue.assess(.again, currentStatus: .weak)

        #expect(outcome?.wasReinserted == true)
        #expect(queue.pending == [cards.c, cards.f, cards.b, cards.a, cards.d])

        // The same thing again as the rule instead of a list, so a changed
        // gap cannot slip past the literal above: exactly `reinsertGap` other
        // cards stand before the repetition, so "A → A" cannot happen.
        #expect(queue.pending.firstIndex(of: cards.a) == LearningParameters.reinsertGap)
        #expect(queue.currentCardID != cards.a, "never straight away")
    }

    // §10, test 10
    @Test("With fewer cards left than the gap, the repeat goes to the end")
    func reinsertFallsBackToTheEnd() {
        // The queue length is derived from the gap, so "one card short of the
        // gap" stays true if the parameter changes — with a fixed list of
        // three the test would also pass for a gap of two, which is exactly
        // what it is supposed to rule out.
        let repeated = UUID()
        let others = (0..<(LearningParameters.reinsertGap - 1)).map { _ in UUID() }
        var queue = SessionQueue(cardIDs: [repeated] + others)

        queue.assess(.again, currentStatus: .weak)

        #expect(queue.pending == others + [repeated])
        #expect(queue.pending.last == repeated, "as late as this batch still allows")
        #expect(queue.pending.count == LearningParameters.reinsertGap)
    }

    // §10, test 11
    @Test("After maxReinserts the card leaves the batch")
    func maxReinsertsEndsTheRepetition() {
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.b, cards.c, cards.d])

        // Rate A "Nochmal" every time it comes up.
        // Derived, and checked: a limit that silently runs out would make the
        // count below wrong for the wrong reason.
        let safetyLimit = 4 * (LearningParameters.maxReinserts + 1)
        var reinserts = 0
        var questions = 0
        while let current = queue.currentCardID, questions < safetyLimit {
            questions += 1
            let outcome = queue.assess(current == cards.a ? .again : .good, currentStatus: .weak)
            if outcome?.wasReinserted == true { reinserts += 1 }
        }
        #expect(questions < safetyLimit, "the queue is not terminating")

        #expect(reinserts == LearningParameters.maxReinserts, "exactly three repetitions, not two, not four")
        #expect(queue.reinsertCount(for: cards.a) == LearningParameters.maxReinserts)
        #expect(queue.isFinished, "the fourth Nochmal resolves the card instead of extending the batch")
    }

    // §10, test 12
    @Test("Gut removes the card from the queue immediately")
    func goodResolvesAtOnce() {
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.b])

        let outcome = queue.assess(.good, currentStatus: .weak)

        #expect(outcome?.wasReinserted == false)
        #expect(outcome?.isResolved == true)
        #expect(queue.pending == [cards.b])
        #expect(queue.pending.contains(cards.a) == false)

        // The same for the other two resolving answers.
        for assessment in [SelfAssessment.hard, .secure] {
            var other = SessionQueue(cardIDs: [cards.a, cards.b])
            other.assess(assessment, currentStatus: .weak)
            #expect(other.pending == [cards.b], "\(assessment) resolves too")
        }
    }

    // §10, test 13
    @Test("A batch ends only once every card is resolved")
    func batchEndsWhenAllResolved() {
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.b, cards.c])

        let first = queue.assess(.good, currentStatus: .weak)
        #expect(first?.isBatchFinished == false)
        #expect(queue.isFinished == false)

        let second = queue.assess(.hard, currentStatus: .weak)
        #expect(second?.isBatchFinished == false)

        // Still not finished while a repetition is outstanding, even though
        // every card has been seen once.
        let third = queue.assess(.again, currentStatus: .weak)
        #expect(third?.isBatchFinished == false)
        #expect(queue.isFinished == false, "the repetition of C is still queued")

        let fourth = queue.assess(.good, currentStatus: .weak)
        #expect(fourth?.isBatchFinished == true)
        #expect(queue.isFinished)
        #expect(queue.currentCardID == nil)
        #expect(queue.assess(.good, currentStatus: .weak) == nil, "nothing left to rate")
    }

    // §10, test 14
    @Test("A batch of one card answered Nochmal forever still terminates")
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
            queue.assess(.again, currentStatus: .weak)
        }

        #expect(queue.isFinished)
        // One first question plus three permitted repetitions.
        #expect(questions == LearningParameters.maxReinserts + 1)
    }

    // §10, test 18
    @Test("Every assessment produces one outcome, repetitions included")
    func everyAssessmentCountsAsAReview() {
        // `reviewCount` is phase 6's to write; what the engine owes is one
        // outcome per assessment, so counting them gives the increments.
        let card = UUID()
        var queue = SessionQueue(cardIDs: [card])

        // Bounded on purpose. The loop's end depends on exactly the
        // mechanism this test is meant to check, so without a limit a broken
        // `maxReinserts` would hang the suite instead of failing it — the
        // worst possible outcome for a test.
        let safetyLimit = LearningParameters.maxReinserts + 10
        var outcomes: [AssessmentOutcome] = []
        while outcomes.count < safetyLimit, let outcome = queue.assess(.again, currentStatus: .weak) {
            outcomes.append(outcome)
        }
        #expect(outcomes.count < safetyLimit, "the queue is not terminating")

        #expect(outcomes.count == LearningParameters.maxReinserts + 1, "four ratings, four reviews")
        #expect(outcomes.allSatisfy { $0.cardID == card })
        #expect(outcomes.filter(\.wasFirstAssessmentInBatch).count == 1, "only the first one is the first")
    }

    // §10, test 19
    @Test("Only Nochmal fails to count as correct")
    func correctnessPerAssessment() {
        let cards = Cards()

        for assessment in SelfAssessment.allCases {
            var queue = SessionQueue(cardIDs: [cards.a, cards.b])
            let outcome = queue.assess(assessment, currentStatus: .weak)
            #expect(outcome?.countsAsCorrect == (assessment != .again), "\(assessment)")
        }

        // Hard counts as correct: the learner knew it, even if it took effort.
        #expect(SelfAssessment.hard.countsAsCorrect)
        #expect(SelfAssessment.again.countsAsCorrect == false)
    }

    // Additional, for the edge case in §9 that has no numbered test: a card
    // deleted mid-session.
    @Test("A skipped card leaves the batch without counting as a review")
    func skippingDoesNotCountAsAReview() {
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.b])

        queue.skipCurrentCard()

        #expect(queue.pending == [cards.b])
        #expect(queue.currentCardID == cards.b)
        // No outcome exists for a skip, so phase 6 has nothing to write —
        // which is the point: a deleted card is not a review.
        queue.skipCurrentCard()
        #expect(queue.isFinished)
        queue.skipCurrentCard()
        #expect(queue.isFinished, "skipping an empty queue is harmless")
    }

    // Additional: the ids of a finished batch have to survive for the next
    // batch's recency damping, which the queue empties as it goes.
    @Test("The batch remembers its cards after the queue has emptied")
    func batchIDsSurviveTheBatch() {
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.b])
        queue.assess(.good, currentStatus: .weak)
        queue.assess(.good, currentStatus: .weak)

        #expect(queue.isFinished)
        #expect(queue.cardIDs == [cards.a, cards.b])
    }
}
