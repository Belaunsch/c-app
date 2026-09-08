//
//  LearningParameters.swift
//  CApp
//

import Foundation

/// Every tunable number of the learning engine, in one place.
///
/// `docs/learning-engine.md` §8 is the specification these values come from.
/// Nothing else in `Learning/` may write a numeric literal for any of them —
/// the point of the section is that the behaviour can be changed here and
/// nowhere else.
///
/// `nonisolated` like the rest of this layer: the target sets
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and pure code has no business
/// requiring an actor. See Q8 in `docs/apple-frameworks.md`.
nonisolated enum LearningParameters {

    /// Different cards per mini-batch.
    ///
    /// Fixed for now. §8 foresees making it configurable between 5 and 10
    /// later; until then a settings screen would be a promise with nothing
    /// behind it.
    static let batchSize = 7

    /// How many other cards go before a repeated card comes back.
    ///
    /// The whole point of the queue: a card answered with "Nochmal" has to
    /// return within the same batch, but never straight away.
    static let reinsertGap = 3

    /// How often one card may be put back into the same mini-batch.
    ///
    /// **One** since the phase-6 device test. It was 3, and together with
    /// several cards answered "Nochmal" that turned a seven-card window into
    /// ten to fifteen questions about the same few cards — a drill, not a
    /// session. One short repetition keeps the value of trying again soon;
    /// everything beyond that is the weighting's job, which brings a card
    /// with a low status back in a later batch anyway (§3.1).
    ///
    /// It still is what makes a batch terminate: with this limit a batch is
    /// at most `batchSize × (1 + maxReinserts)` questions long, whatever the
    /// answers are.
    static let maxReinserts = 1

    /// Weight multiplier for a card that was in the immediately previous
    /// mini-batch, so the same card does not show up twice in a row.
    static let recencyFactor = 0.2

    // MARK: - Base weights per learning status
    //
    // Higher weight means "needs practice more often". `secure` deliberately
    // keeps a weight above zero: a card one knows should appear rarely, not
    // never.

    static let weightNew = 5.0
    static let weightWeak = 5.0
    static let weightMedium = 3.0
    static let weightGood = 1.0
    static let weightSecure = 0.3

    /// Pools below this size ignore the recency factor entirely (§3.2).
    ///
    /// Derived rather than a second constant: with few cards there is nothing
    /// to spread out, and damping the ones just seen would skew or block the
    /// selection.
    static var minimumPoolSizeForRecency: Int { 2 * batchSize }
}
