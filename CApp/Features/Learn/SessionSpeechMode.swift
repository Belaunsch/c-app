//
//  SessionSpeechMode.swift
//  CApp
//

import Foundation

/// Whether the session starts recordings by itself (phase 12).
///
/// ## Two states, and the name matters
///
/// „Armed" means the **session** is in speech mode — not that the microphone
/// is open. The actual recording starts and stops per card, and the learner
/// ends it. There is no silence detection here and no timeout standing in for
/// one: Q11 measured that neither `SpeechDetector` nor `isFinal` can tell when
/// somebody stopped talking on iOS 26.6, and an invented rule would cut people
/// off mid-word. What this mode saves is the tap that **starts** a recording.
nonisolated enum SessionSpeechMode: Equatable, Sendable {
    /// Every recording is started by hand. The behaviour of phases 9 to 11,
    /// unchanged.
    case off

    /// The session starts a recording for each new unrevealed card. The
    /// learner still ends it.
    case armed

    var isArmed: Bool { self == .armed }
}

/// What happened, as far as the speech mode is concerned.
///
/// An explicit list rather than scattered `if`s, because the interesting part
/// of this phase is not the happy path — it is which events end the mode and
/// which do not. A decision table can be read, reviewed and falsified; the
/// same rules spread across a view cannot.
nonisolated enum SessionSpeechEvent: CaseIterable, Sendable {
    // MARK: Events that end the mode

    /// The learner tapped the speaker **while the card was still covered**.
    /// Deliberate listening, and this app never records and speaks at once.
    ///
    /// **Unreachable from the learning screen as it stands, and that is worth
    /// saying plainly.** Mode A shows no speaker before the reveal, and mode B —
    /// which does, because there the audio *is* the question — never reaches this
    /// state machine at all: the observer guards on mode A. So after the phase-13
    /// narrowing (A44) the phase-12 rule „speech output disarms the mode" is in
    /// practice **retired**, not merely narrowed. The case stays because the rule
    /// is the honest answer should a speaker ever appear on a covered mode-A card,
    /// and because deleting it would quietly turn „we decided this" into „nobody
    /// thought about it".
    case speechOutputStartedWhileCovered
    /// The app left the foreground. There is no background recording.
    case appLeftForeground
    /// Another app took the audio session — a call, an alarm.
    case audioInterrupted
    /// Recognition failed technically.
    case recognitionFailed
    /// Recognition is permanently unavailable — no microphone permission, or
    /// a device that cannot do it. An armed mode that can never start again
    /// is a state with no way out, so it ends here.
    case speechUnavailable
    /// The session screen was left.
    case sessionEnded

    // MARK: Events that do not

    /// The learner tapped the speaker **on the revealed card** (phase 13).
    ///
    /// Its own case rather than a condition in the view, so the decision table
    /// below stays the one place these rules live. On a revealed card the
    /// attempt's recording is over and the next one cannot start before the card
    /// changes — which stops speech anyway — so the reason the covered case ends
    /// the mode does not apply here. Without this distinction phase 13 would
    /// have abolished the phase-12 feature: the learner now lands on **every**
    /// card in the revealed state, where the big speaker sits, so listening to
    /// one answer would cost the speech mode every time.
    case speechOutputStartedWhileRevealed

    /// The learner threw the running recording away with the ■ (phase 13).
    ///
    /// An abandoned attempt is not an attempt: nothing is evaluated, nothing is
    /// revealed, nothing is written. The mode stays armed — cancelling one
    /// recording is not a decision about the next card — but the loop guard
    /// stays set, so **this** card gets no automatic retry (A38).
    case recordingCancelledByLearner

    /// The recording finished with no usable text.
    case nothingRecognized
    /// The learner revealed the answer instead of speaking.
    case answerRevealedByHand
    /// The session moved to another card.
    case cardChanged
}

nonisolated extension SessionSpeechEvent {

    /// Which speech-output event this is, given where the card stands.
    ///
    /// A factory rather than an `if` in the view: the *mapping* belongs next to
    /// the cases, and then the rules stay entirely inside the decision table
    /// below where a test can drive them.
    static func speechOutputStarted(onRevealedCard isRevealed: Bool) -> SessionSpeechEvent {
        isRevealed ? .speechOutputStartedWhileRevealed : .speechOutputStartedWhileCovered
    }
    /// Whether the card in front of the learner is now open for a fresh
    /// attempt.
    ///
    /// **One event, and the reason there is only one is `cardCycleKey`.** Giving
    /// up on the **last** card of a batch puts the same card back at position
    /// zero, so the card id does not change — an id-only observer would sit armed
    /// and silent on a card it is supposed to record. Phase 12 fixed that with a
    /// composite key that also counts closed attempts, so that case *is* a card
    /// change as far as this state is concerned.
    ///
    /// Phase 12 carried a second case for „a rating was recorded" as well. It
    /// never had a production caller — the composite key already covers it — and
    /// phase 13 removed it rather than keeping an enum case, two table rows and
    /// three tests for a transition the app never makes.
    var startsANewAttempt: Bool {
        self == .cardChanged
    }
}

/// The rules of the speech mode, as pure functions.
nonisolated enum SessionSpeechRules {

    /// Whether the mode survives `event`.
    ///
    /// **The list of `false`s is the product decision of this phase.** Each one
    /// makes the learner tap the microphone again, deliberately:
    ///
    /// - **Speech output on a covered card** — the roadmap's own rule. Somebody
    ///   who is listening is not speaking, and a mode that records again right
    ///   afterwards takes that decision away from them. **On the revealed card
    ///   it does not end the mode** (A44): the attempt is over, and the next
    ///   recording cannot begin before the card changes.
    /// - **Background and interruption** — nothing records while the app is not
    ///   on screen, and coming back to an open microphone would be a surprise.
    ///   Apple's `shouldResume` is documented as a *playback* hint; it is not
    ///   an instruction to reopen a microphone.
    /// - **Technical failure** — a mode that keeps retrying through a broken
    ///   audio path is a loop, not a feature.
    /// - **Session end** — there is no session to be in speech mode for.
    ///
    /// And the `true`s matter just as much: „nothing recognised", a mismatch, a
    /// reveal by hand or an assessment are all **normal**. They must not drop
    /// the learner out of a mode they switched on.
    static func keepsModeActive(after event: SessionSpeechEvent) -> Bool {
        switch event {
        case .speechOutputStartedWhileCovered, .appLeftForeground, .audioInterrupted,
             .recognitionFailed, .speechUnavailable, .sessionEnded:
            false
        case .speechOutputStartedWhileRevealed, .recordingCancelledByLearner,
             .nothingRecognized, .answerRevealedByHand, .cardChanged:
            true
        }
    }

    /// Whether a running recording has to be thrown away when `event` happens.
    ///
    /// Wider than the list above: a card change or a reveal by hand ends the
    /// **recording** without ending the **mode**. What must never happen is a
    /// result arriving for a card the learner has moved on from.
    static func cancelsRecording(on event: SessionSpeechEvent) -> Bool {
        switch event {
        case .speechOutputStartedWhileCovered, .appLeftForeground, .audioInterrupted,
             .recognitionFailed, .speechUnavailable, .sessionEnded,
             .answerRevealedByHand, .cardChanged, .recordingCancelledByLearner:
            true
        // These happen **after** a recording has already finished, or — for
        // speech output on a revealed card — while there is none to cancel.
        case .nothingRecognized, .speechOutputStartedWhileRevealed:
            false
        }
    }

    /// Whether a recording should now start on its own.
    ///
    /// - Parameters:
    ///   - mode: whether the learner switched the mode on.
    ///   - direction: mode B has no microphone at all (phase 9).
    ///   - isRevealed: an open card has nothing left to say.
    ///   - hasAttemptedCurrentCard: whether a recording has already run for
    ///     this card since it appeared.
    ///   - phase: what the recognition service is doing.
    ///
    /// `hasAttemptedCurrentCard` is the loop guard, and it is the reason
    /// „nothing recognised" cannot spin: once a card has been attempted, the
    /// next recording on it takes a tap. The learner can always retry — just
    /// not by doing nothing.
    static func shouldStartRecording(
        mode: SessionSpeechMode,
        direction: SessionDirection,
        isRevealed: Bool,
        hasAttemptedCurrentCard: Bool,
        phase: SpeechRecognitionService.Phase
    ) -> Bool {
        guard mode.isArmed else { return false }
        guard direction == .germanToChinese else { return false }
        guard isRevealed == false else { return false }
        guard hasAttemptedCurrentCard == false else { return false }
        return isIdle(phase)
    }

    /// Whether the service is free to take a new recording.
    ///
    /// `.recording` and `.finalizing` are busy — starting there would be the
    /// double-start this phase must not produce. `.failed`, `.unavailable` and
    /// `.permissionDenied` are **not** retried automatically: each one needs a
    /// deliberate tap, which is also what the button already offers.
    /// `.noSpeechDetected` is excluded for the same reason — it is the state
    /// right after an empty attempt, and auto-starting there is the loop.
    static func isIdle(_ phase: SpeechRecognitionService.Phase) -> Bool {
        switch phase {
        case .idle, .ready: true
        case .preparing, .downloading, .recording, .finalizing,
             .failed, .noSpeechDetected, .unavailable, .permissionDenied: false
        }
    }
}


/// The session's speech state, and every transition it can make.
///
/// ## Why this is a type and not two `@State` properties
///
/// The interesting behaviour of this phase is not any single rule — it is the
/// **sequence**: a recording ends, phase 11 may advance to the next card, and
/// exactly one new recording must start. Spread across a SwiftUI `body` that
/// sequence cannot be tested, and the phase-7 audit measured what that costs
/// („`body` is 0 % covered"). Here it can be driven step by step.
///
/// It holds no `Card` and no service — only two values and the rules above.
nonisolated struct SessionSpeechState: Equatable, Sendable {

    /// Whether the session starts recordings by itself.
    private(set) var mode: SessionSpeechMode = .off

    /// The card a recording has already run for since it appeared.
    ///
    /// The loop guard. After any attempt — successful, empty or abandoned —
    /// the next recording on **this** card takes a tap.
    private(set) var attemptedCardID: UUID?

    init(mode: SessionSpeechMode = .off, attemptedCardID: UUID? = nil) {
        self.mode = mode
        self.attemptedCardID = attemptedCardID
    }

    /// The learner tapped the microphone: arm the session and mark the card.
    ///
    /// One control, two effects — deliberately. A separate switch for „record
    /// every card" would be a second thing to explain for a feature whose
    /// whole point is one tap fewer.
    mutating func armStartingRecording(on cardID: UUID) {
        mode = .armed
        attemptedCardID = cardID
    }

    /// A recording has been started for `cardID`.
    ///
    /// Called **before** the recording actually starts, not after: the marker
    /// has to hold even when starting fails, or a failure would open the door
    /// to an automatic retry.
    mutating func markAttempt(on cardID: UUID) {
        attemptedCardID = cardID
    }

    /// Applies one event.
    ///
    /// - Returns: whether a running recording has to be thrown away.
    @discardableResult
    mutating func apply(_ event: SessionSpeechEvent) -> Bool {
        if SessionSpeechRules.keepsModeActive(after: event) == false {
            mode = .off
        }
        if event.startsANewAttempt {
            attemptedCardID = nil
        }
        return SessionSpeechRules.cancelsRecording(on: event)
    }

    /// Whether a recording should start now for `cardID`.
    func shouldStartRecording(
        for cardID: UUID,
        direction: SessionDirection,
        isRevealed: Bool,
        phase: SpeechRecognitionService.Phase
    ) -> Bool {
        SessionSpeechRules.shouldStartRecording(
            mode: mode,
            direction: direction,
            isRevealed: isRevealed,
            hasAttemptedCurrentCard: attemptedCardID == cardID,
            phase: phase
        )
    }
}
