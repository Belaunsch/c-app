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

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SelfAssessment.displayOrder, id: \.self) { assessment in
                Button {
                    action(assessment)
                } label: {
                    Text(assessment.title)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(assessment.accessibilityLabel)
            }
        }
    }
}
