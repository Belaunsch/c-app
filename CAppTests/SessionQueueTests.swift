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

    // §10, test 9 — rewritten after the phase-6 device test.
    @Test("A repetition goes behind every card that has not been seen yet")
    func reinsertGoesBehindUnseenCards() {
        // The rule the device test forced. Before it, a repetition went a
        // fixed three places on, and four cards answered "Nochmal" in a row
        // cycled among themselves while the rest of the batch was never
        // shown.
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.c, cards.f, cards.b, cards.d])

        let outcome = queue.assess(.again, currentStatus: .weak)

        #expect(outcome?.wasReinserted == true)
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

        // Four "Nochmal" answers. Each repetition lands behind the cards that
        // are still unseen, so after this exactly one unseen card is left and
        // it is the current one.
        for _ in 0..<4 {
            queue.assess(.again, currentStatus: .weak)
        }
        let last = queue.currentCardID
        #expect(last == cards.e, "the one card nobody has seen yet")

        // Its first attempt. Nothing unseen remains afterwards, so this
        // repetition is placed by the gap alone — which is the point.
        queue.assess(.again, currentStatus: .weak)

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
    @Test("Several failed cards in a row do not starve the unseen ones")
    func consecutiveFailuresDoNotStarveUnseenCards() {
        // Reproduces the reported sequence: seven cards, the first four all
        // answered "Nochmal". What must follow is E, F, G — the cards nobody
        // has seen — not another round of A B C D.
        let ids = (0..<7).map { _ in UUID() }
        var queue = SessionQueue(cardIDs: ids)

        let failed = Array(ids.prefix(4))
        for expected in failed {
            #expect(queue.currentCardID == expected)
            queue.assess(.again, currentStatus: .weak)
        }

        // The next three questions are the three cards never shown.
        let unseen = Array(ids.suffix(3))
        for expected in unseen {
            #expect(queue.currentCardID == expected, "an unseen card must come before any repetition")
            queue.assess(.good, currentStatus: .weak)
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

            // Answer "Nochmal" to everything and watch the order.
            while let current = queue.currentCardID, firstAttempts.count < size {
                if firstAttempts.contains(current) {
                    // A card is coming back although not everything has been
                    // seen once — exactly what must not happen.
                    sawRepetitionTooEarly = true
                }
                firstAttempts.insert(current)
                queue.assess(.again, currentStatus: .weak)
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

        queue.assess(.again, currentStatus: .weak)   // A goes behind the unseen ones
        queue.assess(.good, currentStatus: .weak)    // B resolved
        queue.assess(.good, currentStatus: .weak)    // C resolved
        #expect(queue.pending == [cards.d, cards.a], "D unseen, A waiting")

        // D's first attempt. Afterwards only A is left, and A has been seen,
        // so the gap asks for position 3 in a queue of one.
        queue.assess(.again, currentStatus: .weak)

        #expect(queue.pending == [cards.a, cards.d], "appended, as late as the batch allows")
        #expect(queue.pending.last == cards.d)
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

        #expect(reinserts == LearningParameters.maxReinserts, "exactly the configured number of repetitions, no more")
        #expect(queue.reinsertCount(for: cards.a) == LearningParameters.maxReinserts)
        #expect(queue.isFinished, "the Nochmal past the limit resolves the card instead of extending the batch")
    }

    // §10, test 12
    @Test("Gut removes the card from the queue immediately")
    func goodResolvesAtOnce() {
        let cards = Cards()
        var queue = SessionQueue(cardIDs: [cards.a, cards.b])

        let outcome = queue.assess(.good, currentStatus: .weak)

        #expect(outcome?.wasReinserted == false)
        #expect(outcome?.isResolved == true)
        #expect(queue.pending == [cards.b], "A is gone, not moved")

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

    // Additional, and the number the device test was actually about: how long
    // a batch can get. §5 and `LearningParameters` both claim
    // `batchSize × (1 + maxReinserts)`, and until the audit pointed it out
    // nothing checked it — a change to `maxReinserts` was noticed only by the
    // parameter table, not by its user-visible consequence.
    @Test("A full batch answered Nochmal throughout is exactly as long as promised")
    func fullBatchLengthMatchesThePromise() {
        let ids = (0..<LearningParameters.batchSize).map { _ in UUID() }
        var queue = SessionQueue(cardIDs: ids)

        let promised = LearningParameters.batchSize * (1 + LearningParameters.maxReinserts)
        var questions = 0
        while queue.isFinished == false, questions <= promised {
            questions += 1
            queue.assess(.again, currentStatus: .weak)
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
        // One first question plus the permitted repetitions.
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

        #expect(outcomes.count == LearningParameters.maxReinserts + 1, "one rating per question, repetitions included")
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

        // Spelled out once, because this is the rule people get wrong:
        // "Schwer" counts as correct — the learner knew it, with effort.
        #expect(SelfAssessment.hard.countsAsCorrect)
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

    // Additional: the property the feature layer's persistence order rests
    // on. `LearnSessionModel.submit` advances a *copy* of the queue and keeps
    // it only after the write succeeded, so a failed save leaves the same
    // card in place. That only works because this is a value type — and
    // nothing asserted it until the audit pointed it out.
    @Test("Advancing a copy leaves the original untouched")
    func advancingACopyDoesNotAffectTheOriginal() {
        let cards = Cards()
        let original = SessionQueue(cardIDs: [cards.a, cards.b, cards.c])

        var copy = original
        let outcome = copy.assess(.again, currentStatus: .weak)

        #expect(outcome != nil, "the copy advanced")
        #expect(copy.currentCardID == cards.b)
        #expect(original.currentCardID == cards.a, "the original still asks the same card")
        #expect(original.pending == [cards.a, cards.b, cards.c])
        #expect(original.reinsertCount(for: cards.a) == 0, "and has no repetition recorded")

        // Which means answering again from the original counts as the first
        // assessment — the retry after a failed save must not be treated as a
        // repetition.
        var retry = original
        let second = retry.assess(.again, currentStatus: .weak)
        #expect(second?.wasFirstAssessmentInBatch == true)
        #expect(second?.newStatus == .weak, "and the status is still decided by it")
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
