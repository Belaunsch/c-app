//
//  BatchSelectorTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// `docs/learning-engine.md` §10, mandatory tests 4 to 8.
struct BatchSelectorTests {

    /// A pool of `count` cards, all with the same status unless told
    /// otherwise. Ids are generated, so nothing here depends on their order.
    private func pool(_ count: Int, status: LearningStatus = .medium) -> [CardSnapshot] {
        (0..<count).map { _ in CardSnapshot(id: UUID(), status: status) }
    }

    /// Comfortably above the threshold where the recency damping switches on,
    /// derived rather than a literal.
    private var largePool: Int { LearningParameters.minimumPoolSizeForRecency * 2 }

    // §10, test 4
    @Test("A batch never contains the same card twice")
    func batchHasNoDuplicates() {
        // Checked over many seeds, because a duplicate from drawing with
        // replacement would only show up in some draws.
        for seed in UInt64(1)...50 {
            var generator = SeededGenerator(seed: seed)
            let batch = BatchSelector.selectBatch(from: pool(largePool), using: &generator)
            #expect(Set(batch.map(\.id)).count == batch.count, "seed \(seed) produced a duplicate")
        }
    }

    // §10, test 5
    @Test("The batch is as large as the pool allows")
    func batchSizeIsCapped() {
        var generator = SeededGenerator(seed: 42)

        #expect(BatchSelector.selectBatch(from: pool(largePool), using: &generator).count
                == LearningParameters.batchSize)
        #expect(BatchSelector.selectBatch(from: pool(LearningParameters.batchSize), using: &generator).count
                == LearningParameters.batchSize)
        // Pool smaller than a batch: the batch is the whole pool (§9).
        // Derived, so the assumption "smaller than a batch" cannot quietly
        // stop being true if the parameter changes.
        let smallPool = LearningParameters.batchSize - 1
        #expect(BatchSelector.selectBatch(from: pool(smallPool), using: &generator).count == smallPool)
        // Empty pool: no batch, and no crash. Phase 6 reads this as "cannot
        // start a session".
        #expect(BatchSelector.selectBatch(from: [], using: &generator).isEmpty)
    }

    // §10, test 6
    @Test("The same seed reproduces the same batch in the same order")
    func sameSeedSameResult() {
        let cards = pool(largePool + 10, status: .weak)

        var first = SeededGenerator(seed: 12_345)
        var second = SeededGenerator(seed: 12_345)
        let a = BatchSelector.selectBatch(from: cards, using: &first)
        let b = BatchSelector.selectBatch(from: cards, using: &second)

        // Comparing the arrays covers the order too, not just which cards
        // were picked — the shuffle has to be seeded as well, otherwise a
        // global `shuffled()` would slip through here.
        #expect(a == b)

        // And a different seed is allowed to differ — checked across several
        // so a single unlucky coincidence cannot fail the test.
        var results: Set<[UUID]> = []
        for seed in UInt64(1)...8 {
            var generator = SeededGenerator(seed: seed)
            results.insert(BatchSelector.selectBatch(from: cards, using: &generator).map(\.id))
        }
        #expect(results.count > 1, "every seed produced the same batch, so the seed is being ignored")
    }

    // §10, test 7
    @Test("Weak cards are drawn far more often than secure ones")
    func weightingIsStatisticallyPlausible() {
        // Deterministic: one fixed seed, a fixed number of draws. Qualitative
        // on purpose — the claim is "much more often", not a percentage.
        let weak = pool(20, status: .weak)
        let secure = pool(20, status: .secure)
        let cards = weak + secure
        let weakIDs = Set(weak.map(\.id))

        var generator = SeededGenerator(seed: 777)
        var weakDraws = 0
        var secureDraws = 0
        for _ in 0..<300 {
            for card in BatchSelector.selectBatch(from: cards, using: &generator) {
                if weakIDs.contains(card.id) { weakDraws += 1 } else { secureDraws += 1 }
            }
        }

        // Weights are 5.0 against 0.3. Equal weights would land near 1:1, so
        // this threshold fails loudly if the weighting stops being applied,
        // while staying far away from the actual ratio.
        #expect(weakDraws > secureDraws * 3, "weak \(weakDraws) vs secure \(secureDraws)")
        #expect(secureDraws > 0, "a secure card must still turn up now and then")
    }

    // §10, test 8
    @Test("A pool of one card yields a batch of one")
    func singleCardPool() {
        let card = CardSnapshot(id: UUID(), status: .new)
        var generator = SeededGenerator(seed: 5)

        let batch = BatchSelector.selectBatch(from: [card], using: &generator)

        #expect(batch == [card])
    }

    // Additional: that the selector *applies* the recency damping at all.
    // Found missing by the audit — forcing `wasInPreviousBatch` to false or
    // the pool size to zero inside `selectBatch` left every test green, so
    // §3.2 was only verified one layer down in `CardWeighting`.
    @Test("A card from the previous batch is drawn markedly less often")
    func recencyDampingReachesTheSelection() {
        // Same status for every card, so the only difference between the two
        // halves is whether they were in the previous batch.
        let previous = pool(10, status: .weak)
        let fresh = pool(10, status: .weak)
        let cards = previous + fresh
        #expect(cards.count >= LearningParameters.minimumPoolSizeForRecency, "damping has to be active")
        let previousIDs = Set(previous.map(\.id))

        var generator = SeededGenerator(seed: 4711)
        var previousDraws = 0
        var freshDraws = 0
        for _ in 0..<200 {
            for card in BatchSelector.selectBatch(from: cards, previousBatchIDs: previousIDs, using: &generator) {
                if previousIDs.contains(card.id) { previousDraws += 1 } else { freshDraws += 1 }
            }
        }

        // Weight 5.0 against 5.0 × 0.2 = 1.0. Without the damping both halves
        // would come out near equal, so the threshold fails loudly if the
        // selector stops passing the flag or the pool size through.
        #expect(freshDraws > previousDraws * 2, "fresh \(freshDraws) vs previous \(previousDraws)")
        #expect(previousDraws > 0, "a card from the previous batch may still turn up")
    }

    @Test("The damping switches on exactly at two batches' worth of cards")
    func recencyThresholdActsThroughTheSelection() {
        // Compared **inside** one pool, against an otherwise identical card
        // that was not in the previous batch. A first attempt compared a
        // 14-card pool against a 13-card one and passed even with the
        // damping disabled — drawing 7 of 13 is a larger share than 7 of 14,
        // so the pool size explained the result instead of the damping.
        func draws(poolSize: Int, seed: UInt64) -> (marked: Int, unmarked: Int) {
            let marked = CardSnapshot(id: UUID(), status: .weak)
            let unmarked = CardSnapshot(id: UUID(), status: .weak)
            let filler = pool(poolSize - 2, status: .good)
            let cards = [marked, unmarked] + filler

            var generator = SeededGenerator(seed: seed)
            var markedDraws = 0
            var unmarkedDraws = 0
            for _ in 0..<200 {
                let batch = BatchSelector.selectBatch(
                    from: cards,
                    previousBatchIDs: [marked.id],
                    using: &generator
                )
                if batch.contains(marked) { markedDraws += 1 }
                if batch.contains(unmarked) { unmarkedDraws += 1 }
            }
            return (markedDraws, unmarkedDraws)
        }

        // At the threshold: the damping is on, so the marked card — same
        // status, same everything else — is drawn clearly less often.
        let atThreshold = draws(poolSize: LearningParameters.minimumPoolSizeForRecency, seed: 99)
        #expect(
            atThreshold.marked < atThreshold.unmarked * 3 / 4,
            "damped \(atThreshold.marked) vs undamped \(atThreshold.unmarked)"
        )

        // One card below it: the damping is off (§3.2), so both cards behave
        // the same. Same weights mean the same expectation, so anything close
        // is fine and a disabled-by-mistake damping still shows up above.
        let belowThreshold = draws(poolSize: LearningParameters.minimumPoolSizeForRecency - 1, seed: 99)
        #expect(
            belowThreshold.marked > belowThreshold.unmarked * 3 / 4,
            "below the threshold nothing is damped: \(belowThreshold.marked) vs \(belowThreshold.unmarked)"
        )
    }

    // Additional, guarding a real invariant rather than adding a number:
    // the recency damping must not be able to empty a batch.
    @Test("Recency damping never shrinks a batch")
    func recencyDoesNotShrinkTheBatch() {
        // Every card was in the previous batch, so every weight is damped.
        // Damping all of them equally must change nothing about how many are
        // picked — only about which.
        let cards = pool(largePool, status: .weak)
        let everyID = Set(cards.map(\.id))
        var generator = SeededGenerator(seed: 99)

        let batch = BatchSelector.selectBatch(from: cards, previousBatchIDs: everyID, using: &generator)

        #expect(batch.count == LearningParameters.batchSize)
        #expect(Set(batch.map(\.id)).count == batch.count)
    }
}
