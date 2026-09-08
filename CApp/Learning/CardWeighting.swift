//
//  CardWeighting.swift
//  CApp
//

import Foundation

/// How likely a card is to be picked for the next mini-batch.
///
/// Pulled out as its own function on purpose: `docs/learning-engine.md` §11
/// swaps this one piece for real spaced repetition later, and batch
/// selection, queue and the engine's interface stay untouched. Weights are
/// never persisted — they are recomputed from the status every time
/// (`docs/architecture.md` §3).
nonisolated enum CardWeighting {

    /// The base weight of a status (§3.1).
    static func baseWeight(for status: LearningStatus) -> Double {
        switch status {
        case .new: LearningParameters.weightNew
        case .weak: LearningParameters.weightWeak
        case .medium: LearningParameters.weightMedium
        case .good: LearningParameters.weightGood
        case .secure: LearningParameters.weightSecure
        }
    }

    /// Whether the recency damping applies at this pool size (§3.2).
    ///
    /// Below two batches' worth of cards it is switched off entirely: with so
    /// few cards there is nothing to spread out, and damping the ones just
    /// seen would either skew the selection or leave nothing to pick.
    static func isRecencyActive(poolSize: Int) -> Bool {
        poolSize >= LearningParameters.minimumPoolSizeForRecency
    }

    /// The weight a card is drawn with (§3.2).
    ///
    /// Only the *immediately* previous mini-batch counts. No longer history,
    /// no time intervals, no due dates — that is §11's job, not this one's.
    static func effectiveWeight(
        for status: LearningStatus,
        wasInPreviousBatch: Bool,
        poolSize: Int
    ) -> Double {
        let base = baseWeight(for: status)
        guard wasInPreviousBatch, isRecencyActive(poolSize: poolSize) else { return base }
        return base * LearningParameters.recencyFactor
    }

    /// Convenience for a snapshot, so callers do not unwrap the status.
    static func effectiveWeight(
        for card: CardSnapshot,
        wasInPreviousBatch: Bool,
        poolSize: Int
    ) -> Double {
        effectiveWeight(for: card.status, wasInPreviousBatch: wasInPreviousBatch, poolSize: poolSize)
    }
}
