//
//  SuggestionDecision.swift
//  CApp
//

import Foundation

/// What became of a status suggestion the app made (phase 13).
///
/// ## Why this is its own type and not a `Bool`
///
/// A stored `Bool` named `wasAccepted` cannot say „there was no suggestion" —
/// it needs an optional, and then `nil`, `false` and `true` carry three
/// meanings in a field whose name promises two. This enum says exactly what it
/// is, and `nil` on the property says „no suggestion was made".
///
/// ## Why this is not folded into `SelfAssessment`
///
/// A confirmed suggestion is **not** a self-assessment. `SelfAssessment` means
/// „the learner picked one of the four buttons"; accepting a suggestion means
/// „the learner agreed with the app". They happen to produce the same status
/// step, which is exactly why merging them would be irreversible: after the
/// merge nothing in the store could tell the two apart, retroactively and for
/// good. `docs/learning-engine.md` §13.10 works this through.
///
/// **Raw values written out**, because they are history: a rename in Swift
/// must not rewrite what is already in the store. Same rule as
/// `SelfAssessment`, `SessionDirection` and `SpeechRate`.
nonisolated enum SuggestionDecision: String, CaseIterable, Sendable {
    /// The learner tapped „Bestätigen"; the suggested status was written.
    case accepted = "accepted"

    /// The learner tapped „Ablehnen"; the status stayed as it was, and the
    /// evidence for this particular step starts over
    /// (`docs/learning-engine.md` §13.7, rule 4).
    case declined = "declined"
}
