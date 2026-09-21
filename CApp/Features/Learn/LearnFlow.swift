//
//  LearnFlow.swift
//  CApp
//

import Foundation

/// The rules of the phase-13 card flow, as pure functions.
///
/// They live here rather than inside a `body` for the reason this project pulls
/// every decision out of the view layer: a `body` is not reachable from a test,
/// so a rule that lives only there is a rule nobody can falsify. The phase-7
/// audit measured what that costs.
nonisolated enum LearnFlow {

    // MARK: - The labels that must not collide

    /// The label that finalises the spoken answer.
    ///
    /// Named here rather than written into a `body`, and the reason is a
    /// requirement rather than tidiness: „Fertig" used to be the toolbar button
    /// that **left the session**, and since phase 13 it finalises a recording.
    /// One word with two meanings on one screen is what task 13.9 forbids, and a
    /// string literal buried in a `body` is a rule no test can reach.
    static let finishRecordingTitle = "Fertig"

    /// The toolbar button that leaves the session.
    static let endSessionTitle = "Beenden"

    /// Every label the learning screen can show, so a collision is checkable.
    ///
    /// The recording row's own states come from `RecordAnswerButton.title(for:)`
    /// and are added by the test; what belongs here is the set this type owns.
    static var ownLabels: [String] {
        [finishRecordingTitle, endSessionTitle,
         revealTitle(in: .germanToChinese), revealTitle(in: .audioToGerman)]
    }

    // MARK: - One card transition, one key

    /// The value the session watches to notice that a new attempt has begun.
    ///
    /// **A composite key, and both halves are load-bearing.** The card id alone
    /// misses a reinsertion — giving up on the **last** card of a batch puts the
    /// same card back at position zero, so the id does not change and an
    /// id-only observer stays silent on a card it is meant to record. The
    /// counter alone misses a card that was deleted mid-session.
    ///
    /// It is one key rather than two observers because the phase-12 review found
    /// what two cost: their order is not guaranteed, and both firing is the
    /// double start that opened two microphones or threw a recognised answer
    /// away. Pulled out of the `body` so that „exactly one new key per card
    /// transition" is a testable claim.
    static func cardCycleKey(cardID: UUID?, answeredCount: Int) -> String {
        "\(cardID?.uuidString ?? "-")#\(answeredCount)"
    }

    /// What the button under the recording control says.
    ///
    /// **In mode A it is „Aufgeben" in every state** — including a refused
    /// microphone and a device that cannot recognise Mandarin. A control that
    /// renames itself depending on the microphone is harder to learn than one
    /// that does not, and „Aufgeben" describes the same thing in all of those
    /// cases: the learner ends this attempt without having produced the answer.
    ///
    /// Mode B keeps „Antwort zeigen", because there revealing **is** the
    /// intended step of the mode rather than giving up on an attempt.
    static func revealTitle(in direction: SessionDirection) -> String {
        switch direction {
        case .germanToChinese: "Aufgeben"
        case .audioToGerman: "Antwort zeigen"
        }
    }

    /// Whether a recording could run on this card at all.
    ///
    /// The two permanently impossible phases are the exception: no transcriber
    /// or no Mainland locale on this device, and a refused microphone. Every
    /// other phase either is a recording or can become one after a tap.
    static func allowsRecording(at phase: SpeechRecognitionService.Phase) -> Bool {
        switch phase {
        case .unavailable, .permissionDenied: false
        case .idle, .ready, .preparing, .downloading, .recording,
             .finalizing, .noSpeechDetected, .failed: true
        }
    }

    /// Whether closing this attempt puts the card back into the batch.
    ///
    /// **Three conditions, and the third is the one that is easy to miss.**
    /// „Aufgeben" took over the role „Nochmal" had until phase 12 (§13.5), so a
    /// card the learner gave up on comes back once — behind every unseen card
    /// and at most `maxReinserts` times, exactly as §5 describes.
    ///
    /// But on a device without recognition, revealing is the *only* way
    /// forward, just as in mode B. Reinserting there would make **every batch
    /// twice as long** — seven cards would become fourteen questions, every
    /// card twice, always. That is why this is a separate predicate from
    /// `revealTitle(in:)`: the label is constant in mode A, the scheduling is
    /// not. The invisible difference is pure scheduling — it touches neither the
    /// learning status, nor the evidence, nor anything the learner is told.
    ///
    /// - Parameters:
    ///   - wasManualReveal: whether the answer was uncovered by hand.
    ///   - recordingWasPossible: whether a recording could have run on this
    ///     card, captured **when the card was revealed** rather than when it is
    ///     closed — the recognition phase can change in between, and which
    ///     button was pressed is not up for debate afterwards.
    static func reinserts(
        in direction: SessionDirection,
        wasManualReveal: Bool,
        recordingWasPossible: Bool
    ) -> Bool {
        direction == .germanToChinese && wasManualReveal && recordingWasPossible
    }
}
