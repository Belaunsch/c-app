//
//  SelfAssessmentBar.swift
//  CApp
//

import SwiftUI

/// The four answers, in the order of the ladder they move the card along:
/// Nochmal, Schwer, Gut, Sicher.
///
/// Plain bordered buttons on purpose. Colour-coding them would turn a
/// self-assessment into a verdict, and green-versus-red is the first step
/// towards the scoring this app does not have.
struct SelfAssessmentBar: View {
    let action: (SelfAssessment) -> Void

    /// The step the app would pick, or `nil` when it has nothing to offer
    /// (phase 11).
    ///
    /// A **highlight and nothing more.** Nothing is preselected, nothing is
    /// disabled, the order does not change, and the other three cost exactly
    /// what they cost today. The suggestion is the app saying what it would
    /// do; the learner still decides, and the decision is the learner's tap.
    var suggestion: SelfAssessment? = nil

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SelfAssessment.displayOrder, id: \.self) { assessment in
                button(for: assessment)
            }
        }
    }

    /// Two branches rather than a conditional style, because `buttonStyle`
    /// takes concrete types — and prominent rather than coloured, because a
    /// suggestion must not read as „richtig".
    /// Whether this answer is the highlighted one.
    ///
    /// A one-line rule, pulled out anyway: the phase-7 audit found that a
    /// condition split between a view and a function lets either half be
    /// deleted with the whole suite staying green. `RecordAnswerButton.isOffered`
    /// and `AudioPrompt.allowsAssessment` are the same pattern.
    static func isSuggested(_ assessment: SelfAssessment, suggestion: SelfAssessment?) -> Bool {
        suggestion == assessment
    }

    @ViewBuilder
    private func button(for assessment: SelfAssessment) -> some View {
        let isSuggested = SelfAssessmentBar.isSuggested(assessment, suggestion: suggestion)
        if isSuggested {
            Button { action(assessment) } label: { label(for: assessment) }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(assessment.accessibilityLabel)
                .accessibilityHint("Vorschlag der App")
        } else {
            Button { action(assessment) } label: { label(for: assessment) }
                .buttonStyle(.bordered)
                .accessibilityLabel(assessment.accessibilityLabel)
        }
    }

    private func label(for assessment: SelfAssessment) -> some View {
        Text(assessment.title)
            .font(.subheadline)
            .frame(maxWidth: .infinity, minHeight: 44)
    }
}
