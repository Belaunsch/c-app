//
//  BatchSelector.swift
//  CApp
//

import Foundation

/// Picks the next mini-batch: `batchSize` **different** cards, weighted, and
/// without replacement.
///
/// Repeatedly drawing with replacement would not do — it produces duplicates
/// that then have to be filtered out, which quietly changes the
/// probabilities. Instead this uses weighted sampling without replacement
/// after **Efraimidis–Spirakis** (A-Res, `docs/learning-engine.md` §4): one
/// key per card, one sort, done.
///
///     key(card) = -ln(u) / weight        u drawn uniformly from (0, 1)
///
/// Cards with a higher weight get smaller keys more often, so taking the
/// smallest keys selects proportionally to weight. Distinctness is structural
/// — every card produces exactly one key — rather than something to clean up
/// afterwards.
///
/// The generator is handed in and never created here, so the same seed
/// reproduces the same batch. That is what makes §10's tests possible at all.
nonisolated enum BatchSelector {

    /// The next mini-batch, already in the order it should be shown in.
    ///
    /// - Parameters:
    ///   - pool: every card the session may draw from, already filtered by
    ///     the feature layer.
    ///   - previousBatchIDs: the ids of the batch just finished, for the
    ///     recency damping. Empty for the first batch.
    ///   - generator: injected, never created here.
    ///
    /// The batch size is not a parameter. §8 foresees making it configurable
    /// between 5 and 10 later, and when that happens it has to reach **two**
    /// places: this selection and the recency threshold in
    /// `LearningParameters.minimumPoolSizeForRecency`, which is two batches'
    /// worth. A size passed in here alone would silently leave that threshold
    /// at the old value, and pools between the two would lose the damping
    /// §3.2 asks for.
    static func selectBatch(
        from pool: [CardSnapshot],
        previousBatchIDs: Set<UUID> = [],
        using generator: inout some RandomNumberGenerator
    ) -> [CardSnapshot] {
        guard pool.isEmpty == false else { return [] }
        let batchSize = LearningParameters.batchSize

        let keyed = pool.enumerated().map { index, card in
            let weight = CardWeighting.effectiveWeight(
                for: card,
                wasInPreviousBatch: previousBatchIDs.contains(card.id),
                poolSize: pool.count
            )
            return (card: card, index: index, key: selectionKey(weight: weight, using: &generator))
        }

        // Sorting by key, and by the original position when two keys are
        // equal. Equal keys only happen for non-positive weights, which the
        // status ladder never produces — but a sort that falls back on
        // whatever order the algorithm happens to leave would make the result
        // depend on the standard library rather than on the seed.
        let ordered = keyed.sorted { left, right in
            left.key == right.key ? left.index < right.index : left.key < right.key
        }

        let selected = ordered.prefix(min(batchSize, pool.count)).map(\.card)
        return shuffled(selected, using: &generator)
    }

    /// `-ln(u) / weight`, with the two degenerate inputs handled.
    private static func selectionKey(
        weight: Double,
        using generator: inout some RandomNumberGenerator
    ) -> Double {
        // A weight of zero or less cannot occur — the lowest base weight is
        // 0.3 and the recency factor only shrinks it — but dividing by it
        // would produce infinity or a negative key, which would put the card
        // *first*. Sorting it last is the safe direction.
        guard weight > 0 else { return .infinity }

        // `random(in: 0..<1)` can return exactly 0, and `-ln(0)` is infinity.
        // Nudging it to the smallest normal value keeps the key finite (about
        // 708 before the division) and the card last in line, which is where
        // an unlucky draw belongs.
        var uniform = Double.random(in: 0..<1, using: &generator)
        if uniform <= 0 { uniform = .leastNormalMagnitude }

        return -Foundation.log(uniform) / weight
    }

    /// Fisher-Yates with the injected generator.
    ///
    /// Written out rather than using `shuffled(using:)` because
    /// `docs/learning-engine.md` §4 names the algorithm and because the
    /// uniformity is then visible in this file instead of resting on an
    /// unspecified standard-library strategy. It does **not** make the byte
    /// exact result independent of the standard library — `Int.random(in:
    /// using:)` below draws from the generator with rejection sampling, so
    /// how many values one shuffle consumes is still the library's business.
    /// What the tests rely on is weaker and enough: the same seed and the
    /// same input produce the same output within one build.
    ///
    /// Weighting decides *whether* a card is in the batch, this decides
    /// *where* in it — uniformly, so a heavy card is not also always first.
    private static func shuffled(
        _ cards: [CardSnapshot],
        using generator: inout some RandomNumberGenerator
    ) -> [CardSnapshot] {
        var result = cards
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, to: 0, by: -1) {
            let swapIndex = Int.random(in: 0...index, using: &generator)
            result.swapAt(index, swapIndex)
        }
        return result
    }
}
