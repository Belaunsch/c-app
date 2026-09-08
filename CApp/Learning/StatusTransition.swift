//
//  StatusTransition.swift
//  CApp
//

import Foundation

/// The new learning status after one self-assessment.
///
/// A pure function over the ladder in `docs/learning-engine.md` §6:
///
///     newStatus = clamp(effectiveLevel + delta, weak, secure)
///
/// `new` counts as level 1 — the same as `weak` — because it is a starting
/// state, not a rung: once a card has been rated it never returns there
/// unless the user sets it by hand.
///
/// The lower bound is `weak`, not `new`, and the upper is `secure`. One slip
/// on a secure card drops it to `medium` rather than all the way down; two
/// slips in a row do reach `weak`.
nonisolated enum StatusTransition {

    static func newStatus(from status: LearningStatus, for assessment: SelfAssessment) -> LearningStatus {
        let level = effectiveLevel(of: status) + assessment.statusDelta
        let clamped = min(max(level, lowestLevel), highestLevel)
        // The ladder covers every value between the two bounds, so this
        // cannot fail — but a `fatalError` here would turn a future off-by-one
        // into a crash in front of the user, so it falls back to the bound.
        return LearningStatus(rawValue: clamped) ?? .weak
    }

    /// `new` enters the calculation as `weak` (§6).
    private static func effectiveLevel(of status: LearningStatus) -> Int {
        max(status.rawValue, LearningStatus.weak.rawValue)
    }

    private static let lowestLevel = LearningStatus.weak.rawValue
    private static let highestLevel = LearningStatus.secure.rawValue
}
