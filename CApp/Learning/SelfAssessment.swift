//
//  SelfAssessment.swift
//  CApp
//

import Foundation

/// How the learner rated their own recall of a card.
///
/// The four answers of `docs/learning-engine.md` §6 — there is deliberately
/// no fifth.
///
/// ## No longer offered, and still needed (phase 13)
///
/// The learning flow stopped showing these four buttons: the question came
/// *after* the answer was already on screen, where the difference between
/// „Schwer" and „Gut" is a mood rather than an observation. What remains of the
/// type is what still has a reader:
///
/// - the **raw values**, because they are history — every `ReviewLog` written
///   between phases 11 and 12 holds one, and a rename must not rewrite it;
/// - **`statusDelta`**, because `StatusTransition` builds the ladder of §6 from
///   it, and the *Gut* column of that ladder is what phase 13 suggests.
///
/// `countsAsCorrect` and `keepsCardInBatch` are gone with the buttons:
/// `correctCount` is defined through a self-assessment and therefore stops
/// moving (§13.11), and a card is now put back by „Aufgeben" rather than by an
/// answer (§13.5). Neither had a caller left, and a rule nothing asks is not a
/// guarantee. There are no German titles here either — `Learning/` holds no
/// user-facing text, and nothing displays these any more.
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
    ///
    /// The only member with a caller since phase 13: `StatusTransition` reads
    /// it, and `AssistedAssessment.proposedStatus(from:)` reads that in turn to
    /// build its one step up. All four cases stay reachable through the matrix,
    /// even though only the `.good` column is offered in the flow.
    var statusDelta: Int {
        switch self {
        case .again: -2
        case .hard: -1
        case .good: 1
        case .secure: 2
        }
    }
}
