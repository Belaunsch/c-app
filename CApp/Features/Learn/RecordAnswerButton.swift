//
//  RecordAnswerButton.swift
//  CApp
//

import SwiftUI

/// The optional microphone in mode A.
///
/// ## Optional means optional
///
/// Everything on this screen works without it: a device that cannot do speech
/// recognition — or a learner who says no to the microphone — loses this row and
/// nothing else. That is task 9.5 and acceptance criterion 5, and it is why this
/// is a second control rather than a replacement for the first.
///
/// **Two things changed in phase 13 and are easy to misread from here.** The
/// button underneath is called *Aufgeben* in mode A, in every recognition state
/// including the two that rule a recording out — and giving up puts the card back
/// into the batch, but **only** where a recording was actually possible, so on a
/// device without recognition nothing is reinserted and the batch keeps its
/// length (`LearnFlow`, `docs/learning-engine.md` §13.5).
///
/// ## The states are the service's, not invented here
///
/// `SpeechRecognitionService.Phase` decides what the button says and whether
/// it does anything. The mapping is a pure function so it can be tested: what
/// a button looks like in seven states is exactly the sort of thing that
/// drifts when it lives in a `body`.
struct RecordAnswerButton: View {
    let phase: SpeechRecognitionService.Phase
    let progress: Progress?

    /// A technical failure, if there is one. Shown under the button rather
    /// than in an alert: the learning session must not be interrupted by
    /// something that is optional to begin with.
    var failure: AppError? = nil
    let start: () -> Void
    let stop: () -> Void

    /// Throws the running recording away without evaluating it (phase 13).
    ///
    /// The small ■ beside „Fertig". Without it a stumbled attempt costs a
    /// recording **and** a reveal, because the only way out of a recording used
    /// to be the one that evaluates it.
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let note = RecordAnswerButton.note(for: phase, failure: failure),
               RecordAnswerButton.isHidden(at: phase) {
                // The device cannot do it. The explanation stays even though
                // the control is gone.
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if RecordAnswerButton.isHidden(at: phase) == false {
                // One row, two states, and **one** animation on the value the
                // layout is derived from — not two independent transitions,
                // which is the lesson A33 stands for. While recording, the wide
                // button shrinks to the right onto the stop area and „Fertig"
                // appears in the space it gives up. The row keeps its height,
                // so the button underneath does not move.
                HStack(spacing: 8) {
                    if RecordAnswerButton.showsStopControl(at: phase) {
                        Button(action: stop) {
                            Label(LearnFlow.finishRecordingTitle, systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }

                    // **One** button across both states, so the width really
                    // animates instead of one view being swapped for another:
                    // full width while idle, intrinsic width — the ■ — while
                    // recording. Only its content and frame change.
                    Button(action: RecordAnswerButton.showsStopControl(at: phase) ? cancel : start) {
                        Group {
                            if RecordAnswerButton.showsStopControl(at: phase) {
                                Image(systemName: RecordAnswerButton.symbol(for: phase))
                            } else {
                                Label(
                                    RecordAnswerButton.title(for: phase),
                                    systemImage: RecordAnswerButton.symbol(for: phase)
                                )
                            }
                        }
                        .frame(maxWidth: RecordAnswerButton.showsStopControl(at: phase) ? nil : .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(RecordAnswerButton.isEnabled(at: phase) == false)
                    .tint(RecordAnswerButton.showsStopControl(at: phase) ? .red : .accentColor)
                    .accessibilityLabel(RecordAnswerButton.title(for: phase))
                }
                .animation(.snappy, value: RecordAnswerButton.showsStopControl(at: phase))

                // Apple's own `Progress`, never a stand-in. A bar that moves
                // on a timer while nothing downloads is worse than no bar.
                if phase == .downloading, let progress {
                    ProgressView(progress)
                        .progressViewStyle(.linear)
                }

                if let note = RecordAnswerButton.note(for: phase, failure: failure) {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    /// Whether the microphone belongs on screen at all.
    ///
    /// Two conditions, both here rather than split between a view and a
    /// function — the phase-7 audit showed that a condition written half in a
    /// `body` can lose either half with the whole suite staying green.
    ///
    /// **Mode A only.** In mode B the learner is working out a meaning from
    /// sound; there is no Chinese for them to say, and a microphone there
    /// would be asking a question the mode does not pose. **Before the reveal
    /// only:** once the answer is on screen, speaking it proves nothing.
    static func isOffered(in direction: SessionDirection, revealed: Bool) -> Bool {
        direction == .germanToChinese && revealed == false
    }

    // MARK: - The state table, pulled out so it can be falsified

    /// The button is gone when the feature cannot exist on this device.
    ///
    /// Hidden rather than disabled: a permanently dead control invites taps
    /// and explains nothing. The accompanying note carries the explanation.
    static func isHidden(at phase: SpeechRecognitionService.Phase) -> Bool {
        phase == .unavailable
    }

    /// Whether a tap does anything.
    static func isEnabled(at phase: SpeechRecognitionService.Phase) -> Bool {
        switch phase {
        case .idle, .ready, .recording, .failed, .noSpeechDetected: true
        // `.permissionDenied` stays tappable: the learner may have granted
        // the microphone in the iOS settings since, and asking again is the
        // only way to find out. Refusing would strand them for the rest of
        // the app's run.
        case .permissionDenied: true
        case .unavailable, .preparing, .downloading, .finalizing: false
        }
    }

    /// Whether a recording is running: the row shows „Fertig" plus the small ■,
    /// the wide control **cancels** instead of starting, and it is tinted red.
    ///
    /// **One predicate for all three**, because they are one question. Phase 13
    /// briefly had two names for it plus a third inline `phase == .recording` in
    /// the `body`; three spellings of one condition is three chances to drift.
    ///
    /// **Derived from the phase and from nothing else** — not from who started
    /// the recording. That is what makes an automatically started recording show
    /// `[ Fertig ][ ■ ]` straight away instead of „Antwort sprechen" (phase 12
    /// arms the session, this row only reports what the service is doing).
    static func showsStopControl(at phase: SpeechRecognitionService.Phase) -> Bool {
        phase == .recording
    }

    static func title(for phase: SpeechRecognitionService.Phase) -> String {
        switch phase {
        case .idle, .ready, .failed, .noSpeechDetected: "Antwort sprechen"
        case .unavailable: "Spracherkennung nicht verfügbar"
        case .permissionDenied: "Mikrofon nicht freigegeben"
        case .preparing: "Wird vorbereitet …"
        case .downloading: "Sprachmodell wird geladen …"
        case .recording: "Aufnahme abbrechen"
        case .finalizing: "Wird ausgewertet …"
        }
    }

    static func symbol(for phase: SpeechRecognitionService.Phase) -> String {
        switch phase {
        case .recording: "stop.circle"
        case .permissionDenied: "mic.slash"
        case .unavailable: "mic.slash"
        case .preparing, .downloading, .finalizing: "hourglass"
        case .idle, .ready, .failed, .noSpeechDetected: "mic"
        }
    }

    /// The sentence under the button, when there is something to say.
    ///
    /// Deliberately silent in the ordinary states: a permanent explanation
    /// under a button that works is noise.
    static func note(
        for phase: SpeechRecognitionService.Phase,
        failure: AppError? = nil
    ) -> String? {
        switch phase {
        case .unavailable:
            // Shown even though the button is hidden — otherwise the feature
            // simply is not there and nobody can tell whether that is the
            // device or a bug.
            "Dieses Gerät kann kein Mandarin erkennen. Alles andere funktioniert weiter."
        case .permissionDenied:
            "Ohne Mikrofon geht alles andere weiter — tippe auf „Aufgeben“."
        case .noSpeechDetected:
            // Informative, never a verdict: nothing here measured how it was
            // said, so nothing here may comment on it.
            "Nichts erkannt. Noch einmal versuchen, oder aufgeben."
        case .failed:
            // The real reason when there is one — task 9.3 asks for errors to
            // be visible, and "something went wrong" is not visible.
            failure?.message ?? "Noch einmal versuchen, oder einfach aufgeben."
        case .idle, .ready, .preparing, .downloading, .recording, .finalizing:
            nil
        }
    }
}
