//
//  RevealedDecisionBar.swift
//  CApp
//

import SwiftUI

/// What the learner does once the answer is on screen (phase 13).
///
/// Exactly one of two things, never both:
///
/// ```text
/// kein Vorschlag                  Vorschlag liegt vor
///
/// [ Weiter ]                      Neue Einstufung
///                                 Mittel → Gut
///                                 [ Ablehnen ]  [ Bestätigen ]
/// ```
///
/// ## Why there is no „Weiter" beside the suggestion
///
/// **„Ablehnen" *is* the neutral way out.** It changes no status, it lowers
/// nothing, and it moves to the next card exactly as „Weiter" would. A third
/// button offering the same outcome under a different name would only ask the
/// learner to work out the difference between „no thanks" and „next" — there
/// isn't one, apart from the app remembering the „no" so it stops asking for a
/// while.
///
/// ## No colour coding
///
/// „Bestätigen" is prominent because it is the affirmative action, not because
/// it is the right one. Colouring these green and red would turn a suggestion
/// into a verdict, which is the first step towards the scoring this app does not
/// have (hard rule 6), and the app has no grounds for a verdict anyway.
struct RevealedDecisionBar: View {

    /// The card's status right now — the left-hand side of the arrow.
    let currentStatus: LearningStatus

    /// The status the app offers, or `nil` for the plain „Weiter".
    let proposal: LearningStatus?

    let onContinue: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        if let proposal {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Neue Einstufung")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(RevealedDecisionBar.transitionTitle(from: currentStatus, to: proposal))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                // One announcement instead of two, and with the arrow spelled
                // out — an arrow is not a word.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    RevealedDecisionBar.accessibilityLabel(from: currentStatus, to: proposal)
                )

                HStack(spacing: 8) {
                    Button("Ablehnen", action: onDecline)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)

                    Button("Bestätigen", action: onAccept)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                }
            }
        } else {
            Button("Weiter", action: onContinue)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - The two visible strings, pulled out so tests can reach them

    /// Whether the suggestion is on offer rather than the plain „Weiter".
    ///
    /// A one-line rule, pulled out anyway: the phase-7 audit found that a
    /// condition split between a view and a function lets either half be deleted
    /// with the whole suite staying green.
    static func showsProposal(_ proposal: LearningStatus?) -> Bool {
        proposal != nil
    }

    /// „Mittel → Gut".
    static func transitionTitle(from current: LearningStatus, to proposal: LearningStatus) -> String {
        "\(current.title) → \(proposal.title)"
    }

    /// Spoken by VoiceOver, where an arrow is not a word.
    static func accessibilityLabel(from current: LearningStatus, to proposal: LearningStatus) -> String {
        "Neue Einstufung: von \(current.title) auf \(proposal.title)"
    }
}
