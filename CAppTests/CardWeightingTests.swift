//
//  CardWeightingTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// `docs/learning-engine.md` §10, mandatory tests 1 to 3, plus the two value
/// types that carry a contract phase 6 depends on.
struct CardWeightingTests {

    @Test("An empty category set means every category")
    func sessionConfigurationDefaults() {
        // The contract phase 6 builds the pool from: one card type, never
        // mixed, and categories combined with AND — where "none selected"
        // has to mean "no restriction", not "match nothing".
        let unrestricted = SessionConfiguration(cardType: .word)
        #expect(unrestricted.tagKeys.isEmpty)
        #expect(unrestricted.cardType == .word)
        #expect(unrestricted == SessionConfiguration(cardType: .word, tagKeys: []))
        #expect(unrestricted != SessionConfiguration(cardType: .sentence))
        #expect(unrestricted != SessionConfiguration(cardType: .word, tagKeys: ["essen"]))
    }

    @Test("A snapshot carries the status and nothing about the card's text")
    func snapshotIsMinimal() {
        // Deliberately two fields: the queue works on ids, so a card edited
        // during a session shows its new content next time without the engine
        // knowing anything about it (§9).
        let id = UUID()
        #expect(CardSnapshot(id: id, status: .weak) == CardSnapshot(id: id, status: .weak))
        #expect(CardSnapshot(id: id, status: .weak) != CardSnapshot(id: id, status: .good))
        #expect(CardSnapshot(id: id, status: .weak) != CardSnapshot(id: UUID(), status: .weak))
    }

    @Test("The parameter table matches the specification")
    func parametersMatchTheSpecification() {
        // The one place where the numbers from §8 are written out. Everywhere
        // else — algorithm and tests — reads them from `LearningParameters`,
        // which is exactly why they need pinning once: without this,
        // `weightMedium = 4.0` would break no test at all, and the
        // specification and the code could drift apart silently.
        //
        // If one of these has to change, this test is the place where that
        // becomes a conscious decision including the document.
        #expect(LearningParameters.batchSize == 7)
        #expect(LearningParameters.reinsertGap == 3)
        #expect(LearningParameters.maxReinserts == 3)
        #expect(LearningParameters.recencyFactor == 0.2)

        #expect(LearningParameters.weightNew == 5.0)
        #expect(LearningParameters.weightWeak == 5.0)
        #expect(LearningParameters.weightMedium == 3.0)
        #expect(LearningParameters.weightGood == 1.0)
        #expect(LearningParameters.weightSecure == 0.3)

        #expect(LearningParameters.minimumPoolSizeForRecency == 14, "two batches' worth")
    }

    // §10, test 1
    @Test("Every status yields exactly its base weight")
    func baseWeightPerStatus() {
        #expect(CardWeighting.baseWeight(for: .new) == LearningParameters.weightNew)
        #expect(CardWeighting.baseWeight(for: .weak) == LearningParameters.weightWeak)
        #expect(CardWeighting.baseWeight(for: .medium) == LearningParameters.weightMedium)
        #expect(CardWeighting.baseWeight(for: .good) == LearningParameters.weightGood)
        #expect(CardWeighting.baseWeight(for: .secure) == LearningParameters.weightSecure)

        // The ordering is the point of the whole table: more practice needed
        // means a higher weight, and `secure` stays above zero so a known
        // card returns rarely rather than never.
        #expect(CardWeighting.baseWeight(for: .new) > CardWeighting.baseWeight(for: .medium))
        #expect(CardWeighting.baseWeight(for: .medium) > CardWeighting.baseWeight(for: .good))
        #expect(CardWeighting.baseWeight(for: .good) > CardWeighting.baseWeight(for: .secure))
        #expect(CardWeighting.baseWeight(for: .secure) > 0)
    }

    // §10, test 2
    @Test("A card from the previous batch is damped by the recency factor")
    func recencyFactorApplies() {
        // Pool large enough for recency to be active at all.
        let poolSize = LearningParameters.minimumPoolSizeForRecency

        let damped = CardWeighting.effectiveWeight(for: .weak, wasInPreviousBatch: true, poolSize: poolSize)
        let undamped = CardWeighting.effectiveWeight(for: .weak, wasInPreviousBatch: false, poolSize: poolSize)

        #expect(damped == LearningParameters.weightWeak * LearningParameters.recencyFactor)
        #expect(undamped == LearningParameters.weightWeak)
        #expect(damped < undamped)
    }

    // §10, test 3
    @Test("The recency factor is off while the pool is smaller than two batches")
    func recencyFactorIsDisabledForSmallPools() {
        let tooSmall = LearningParameters.minimumPoolSizeForRecency - 1

        #expect(CardWeighting.isRecencyActive(poolSize: tooSmall) == false)
        #expect(CardWeighting.isRecencyActive(poolSize: LearningParameters.minimumPoolSizeForRecency))

        // Same card, same "was in the previous batch" — only the pool size
        // differs, and that alone decides whether the damping happens.
        let small = CardWeighting.effectiveWeight(for: .weak, wasInPreviousBatch: true, poolSize: tooSmall)
        let large = CardWeighting.effectiveWeight(
            for: .weak,
            wasInPreviousBatch: true,
            poolSize: LearningParameters.minimumPoolSizeForRecency
        )
        #expect(small == LearningParameters.weightWeak, "undamped below the threshold")
        #expect(large < small, "damped from the threshold upwards")

        // Down to the degenerate sizes from §9.
        #expect(CardWeighting.effectiveWeight(for: .secure, wasInPreviousBatch: true, poolSize: 1)
                == LearningParameters.weightSecure)
        #expect(CardWeighting.effectiveWeight(for: .secure, wasInPreviousBatch: true, poolSize: 0)
                == LearningParameters.weightSecure)
    }
}
