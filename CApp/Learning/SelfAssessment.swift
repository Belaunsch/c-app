//
//  SelfAssessment.swift
//  CApp
//

import Foundation

/// How the learner rated their own recall of a card.
///
/// The four answers of `docs/learning-engine.md` §6 — there is deliberately
/// no fifth. German titles for these live in the feature layer; `Learning/`
/// holds no user-facing text.
///
/// **Raw values since phase 11**, written out rather than left to the
/// compiler: a `ReviewLog` entry stores the assessment the learner actually
/// gave, so the strings are history and a rename must not rewrite it. Same
/// rule as `CardSortOrder`, `SpeechRate` and `SessionDirection`.
nonisolated enum SelfAssessment: String, CaseIterable, Sendable {
    case again = "again"
    case hard = "hard"
    case good = "good"
    case secure = "secure"

    /// Steps up or down the status ladder (§6).
    var statusDelta: Int {
        switch self {
        case .again: -2
        case .hard: -1
        case .good: 1
        case .secure: 2
        }
    }

    /// Whether this answer counts as a correct recall (§7).
    ///
    /// "Schwer" counts: the learner knew it, even if it took effort. Only
    /// "Nochmal" means they did not.
    var countsAsCorrect: Bool {
        self != .again
    }

    /// Whether the card stays in the batch for another try (§5).
    var keepsCardInBatch: Bool {
        self == .again
    }
}
