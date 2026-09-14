//
//  SessionSpeechModeTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// The session speech mode of phase 12: when a recording starts by itself, and
/// what switches the mode off.
///
/// ## What this file covers and what it cannot
///
/// The **rules**. They are pure functions precisely so they can be checked
/// without a device — the alternative would be a mock of Apple's speech stack,
/// which would only confirm my own assumptions about it. That the view calls
/// these rules is structural and was read in review; that the microphone
/// behaves as expected on real hardware belongs to the final device
/// acceptance.
///
/// **The important half is negative:** what must *not* happen — no loop after
/// an empty attempt, no recording while an assessment is waiting, no recording
/// after speech output, none in the background.
@MainActor
struct SessionSpeechModeTests {

    // MARK: - The mode itself

    @Test("Off is the default, and off means the app of phase 11")
    func offByDefault() {
        #expect(SessionSpeechMode.off.isArmed == false)
        #expect(SessionSpeechMode.armed.isArmed)

        // With the mode off nothing ever starts on its own, whatever else is
        // true. That is the guarantee „mode A behaves exactly as before".
        for phase in SpeechRecognitionService.Phase.allCases {
            #expect(SessionSpeechRules.shouldStartRecording(
                mode: .off, direction: .germanToChinese, isRevealed: false,
                hasAttemptedCurrentCard: false, phase: phase
            ) == false)
        }
    }

    // MARK: - When a recording starts on its own

    @Test("An armed session records a fresh card")
    func armedStartsOnAFreshCard() {
        #expect(SessionSpeechRules.shouldStartRecording(
            mode: .armed, direction: .germanToChinese, isRevealed: false,
            hasAttemptedCurrentCard: false, phase: .ready
        ))
        #expect(SessionSpeechRules.shouldStartRecording(
            mode: .armed, direction: .germanToChinese, isRevealed: false,
            hasAttemptedCurrentCard: false, phase: .idle
        ))
    }

    @Test("Mode B has no microphone, armed or not")
    func modeBNeverRecords() {
        // Phase 9 put the microphone in mode A only; phase 12 does not change
        // that. In mode B the Chinese **is** the question.
        #expect(SessionSpeechRules.shouldStartRecording(
            mode: .armed, direction: .audioToGerman, isRevealed: false,
            hasAttemptedCurrentCard: false, phase: .ready
        ) == false)
    }

    @Test("A revealed card is not recorded")
    func revealedCardIsNotRecorded() {
        // This is also what keeps the microphone shut while the four
        // assessment buttons are waiting: the card is revealed then.
        #expect(SessionSpeechRules.shouldStartRecording(
            mode: .armed, direction: .germanToChinese, isRevealed: true,
            hasAttemptedCurrentCard: false, phase: .ready
        ) == false)
    }

    @Test("One automatic attempt per card — this is the loop guard")
    func oneAttemptPerCard() {
        // „Nothing recognised" leaves the card unrevealed. Without this guard
        // the next recording would start immediately, find nothing again, and
        // the session would spin with the microphone open.
        #expect(SessionSpeechRules.shouldStartRecording(
            mode: .armed, direction: .germanToChinese, isRevealed: false,
            hasAttemptedCurrentCard: true, phase: .ready
        ) == false)
    }

    @Test("A busy or refusing service is never started twice")
    func busyServiceIsNotStarted() {
        // `.recording`/`.finalizing` would be the double start. The rest need a
        // deliberate tap: `.noSpeechDetected` is the state right after an empty
        // attempt, `.failed`/`.unavailable`/`.permissionDenied` are not things
        // to retry automatically.
        for phase: SpeechRecognitionService.Phase in [
            .recording, .finalizing, .preparing, .downloading,
            .failed, .noSpeechDetected, .unavailable, .permissionDenied,
        ] {
            #expect(SessionSpeechRules.shouldStartRecording(
                mode: .armed, direction: .germanToChinese, isRevealed: false,
                hasAttemptedCurrentCard: false, phase: phase
            ) == false, "\(phase) must not start a recording")
        }
        // And exactly two do.
        let idle = SpeechRecognitionService.Phase.allCases.filter(SessionSpeechRules.isIdle)
        #expect(Set(idle) == [.idle, .ready])
    }

    // MARK: - What ends the mode

    @Test("Speech output ends the mode")
    func speechOutputEndsTheMode() {
        // The roadmap's own product rule: somebody who is listening is not
        // speaking, and a mode that records again right afterwards takes that
        // decision away from them. Re-arming needs a deliberate tap.
        #expect(SessionSpeechRules.keepsModeActive(after: .speechOutputStarted) == false)
        #expect(SessionSpeechRules.cancelsRecording(on: .speechOutputStarted))
    }

    @Test("Leaving the foreground and being interrupted both end the mode")
    func lifecycleEventsEndTheMode() {
        for event: SessionSpeechEvent in [
            .appLeftForeground, .audioInterrupted, .speechUnavailable,
        ] {
            #expect(SessionSpeechRules.keepsModeActive(after: event) == false, "\(event)")
            #expect(SessionSpeechRules.cancelsRecording(on: event), "\(event)")
        }
    }

    @Test("A technical failure ends the mode")
    func failureEndsTheMode() {
        #expect(SessionSpeechRules.keepsModeActive(after: .recognitionFailed) == false)
        #expect(SessionSpeechRules.cancelsRecording(on: .recognitionFailed))
    }

    @Test("Leaving the session ends the mode")
    func sessionEndEndsTheMode() {
        #expect(SessionSpeechRules.keepsModeActive(after: .sessionEnded) == false)
        #expect(SessionSpeechRules.cancelsRecording(on: .sessionEnded))
    }

    // MARK: - What does not end the mode

    @Test("The ordinary course of learning keeps the mode on")
    func ordinaryEventsKeepTheMode() {
        // These are all normal. Dropping the learner out of a mode they
        // switched on, because a recogniser heard something else, would make
        // the mode feel broken.
        for event: SessionSpeechEvent in [
            .nothingRecognized, .answerRevealedByHand,
            .cardChanged, .assessmentSubmitted,
        ] {
            #expect(SessionSpeechRules.keepsModeActive(after: event), "\(event)")
        }
    }

    @Test("Revealing by hand and changing card end the recording but not the mode")
    func revealAndCardChangeCancelOnly() {
        // Wider than the mode rule on purpose: a result must never arrive for a
        // card the learner has moved on from.
        for event: SessionSpeechEvent in [.answerRevealedByHand, .cardChanged] {
            #expect(SessionSpeechRules.cancelsRecording(on: event), "\(event)")
            #expect(SessionSpeechRules.keepsModeActive(after: event), "\(event)")
        }
    }

    @Test("Events that happen after a recording do not cancel one")
    func postRecordingEventsCancelNothing() {
        for event: SessionSpeechEvent in [
            .nothingRecognized, .assessmentSubmitted,
        ] {
            #expect(SessionSpeechRules.cancelsRecording(on: event) == false, "\(event)")
        }
    }

    @Test("Every event is decided, and the two rules do not contradict")
    func everyEventIsDecided() {
        // Exhaustive over the type, so a new event cannot slip in undecided.
        for event in SessionSpeechEvent.allCases {
            _ = SessionSpeechRules.keepsModeActive(after: event)
            _ = SessionSpeechRules.cancelsRecording(on: event)
            // An event that ends the mode must also end the recording —
            // otherwise the microphone outlives the mode that opened it.
            if SessionSpeechRules.keepsModeActive(after: event) == false {
                #expect(SessionSpeechRules.cancelsRecording(on: event),
                        "\(event) ends the mode but leaves the microphone open")
            }
        }
        // The counter-probe: without it the implication above is vacuously
        // true — a `keepsModeActive` that always said `true` would satisfy it.
        let ending = SessionSpeechEvent.allCases.filter {
            SessionSpeechRules.keepsModeActive(after: $0) == false
        }
        #expect(ending.isEmpty == false, "at least one event has to end the mode")
        #expect(ending.count < SessionSpeechEvent.allCases.count, "and at least one must not")

        #expect(SessionSpeechEvent.allCases.count == 10, "a new event needs a decision above")
    }

    // MARK: - The sequences the roadmap describes

    // MARK: - The sequences, driven step by step

    @Test("The microphone tap arms the session and claims the card")
    func tappingArms() {
        // The activation itself, which had no test at all: the audit found
        // that removing `armStartingRecording` from the tap left the whole
        // phase inert with the suite green.
        var state = SessionSpeechState()
        let card = UUID()
        #expect(state.mode == .off)

        state.armStartingRecording(on: card)

        #expect(state.mode == .armed)
        #expect(state.attemptedCardID == card, "the tap is this card's one attempt")
        #expect(state.shouldStartRecording(
            for: card, direction: .germanToChinese, isRevealed: false, phase: .ready
        ) == false, "and it does not immediately ask for a second one")
    }

    @Test("After an automatic advance the next card records on its own")
    func autoAdvanceLeadsToTheNextRecording() {
        // The real sequence: a card was recorded, phase 11 advanced by itself,
        // and the new card must get a recording. The first version of this test
        // compared two unrelated UUIDs and proved nothing — it was a duplicate
        // of `armedStartsOnAFreshCard` in disguise. Found by the audit.
        let first = UUID()
        let second = UUID()
        var state = SessionSpeechState()
        state.armStartingRecording(on: first)

        // Still the same card: no second attempt.
        #expect(state.shouldStartRecording(
            for: first, direction: .germanToChinese, isRevealed: false, phase: .ready
        ) == false)

        let cancels = state.apply(.cardChanged)

        #expect(cancels, "whatever was running belonged to the old card")
        #expect(state.mode == .armed, "and the mode survives an ordinary advance")
        #expect(state.shouldStartRecording(
            for: second, direction: .germanToChinese, isRevealed: false, phase: .ready
        ), "the new card records")
    }

    @Test("The same card coming straight back is recorded again")
    func reinsertedCardRecordsAgain() {
        // „Nochmal" on the **last** card of a batch puts the same card back at
        // position zero — the id never changes, so a card-change observer
        // misses it entirely. Without `assessmentSubmitted` clearing the marker
        // the session would sit armed and silent on a card it is meant to
        // record. Found in review.
        let card = UUID()
        var state = SessionSpeechState()
        state.armStartingRecording(on: card)

        let cancels = state.apply(.assessmentSubmitted)

        #expect(cancels == false, "the recording ended long before the rating")
        #expect(state.mode == .armed)
        #expect(state.shouldStartRecording(
            for: card, direction: .germanToChinese, isRevealed: false, phase: .ready
        ), "the very same card is a new attempt now")
    }

    @Test("An empty attempt does not open a second one on the same card")
    func nothingRecognizedDoesNotLoop() {
        // The loop, walked through: record, nothing, and then nothing again.
        let card = UUID()
        var state = SessionSpeechState()
        state.armStartingRecording(on: card)

        let cancels = state.apply(.nothingRecognized)

        #expect(cancels == false, "the recording is already over")
        #expect(state.mode == .armed, "the mode is not the learner's fault")
        #expect(state.shouldStartRecording(
            for: card, direction: .germanToChinese, isRevealed: false, phase: .noSpeechDetected
        ) == false, "and this card waits for a tap")
    }

    @Test("Speech output disarms, and nothing starts afterwards")
    func speechOutputDisarmsForGood() {
        let card = UUID()
        var state = SessionSpeechState()
        state.armStartingRecording(on: card)

        let cancelled = state.apply(.speechOutputStarted)
        #expect(cancelled, "a running recording ends")
        #expect(state.mode == .off)

        // Not even the next card: re-arming takes a deliberate tap.
        let cancelledAgain = state.apply(.cardChanged)
        #expect(cancelledAgain)
        #expect(state.shouldStartRecording(
            for: UUID(), direction: .germanToChinese, isRevealed: false, phase: .ready
        ) == false)
    }

    @Test("Every event that ends the mode ends it for the rest of the session")
    func disarmingEventsAreFinal() {
        for event: SessionSpeechEvent in [
            .speechOutputStarted, .appLeftForeground, .audioInterrupted,
            .recognitionFailed, .speechUnavailable, .sessionEnded,
        ] {
            var state = SessionSpeechState()
            state.armStartingRecording(on: UUID())
            _ = state.apply(event)
            #expect(state.mode == .off, "\(event)")

            // Two more cards go by, and still nothing records on its own.
            _ = state.apply(.cardChanged)
            _ = state.apply(.cardChanged)
            #expect(state.shouldStartRecording(
                for: UUID(), direction: .germanToChinese, isRevealed: false, phase: .ready
            ) == false, "\(event) must not wear off")
        }
    }

    @Test("While an assessment waits, nothing records")
    func nothingRecordsDuringAssessment() {
        // `hasAttemptedCurrentCard: false` on purpose — otherwise this test
        // passes on the loop guard instead of on the thing it names, which is
        // what the audit found in its first version. The card is revealed for
        // exactly as long as the four buttons are up, and that alone has to
        // keep the microphone shut.
        #expect(SessionSpeechRules.shouldStartRecording(
            mode: .armed, direction: .germanToChinese, isRevealed: true,
            hasAttemptedCurrentCard: false, phase: .ready
        ) == false)
    }

    @Test("After an empty attempt an explicit tap is the only way back")
    func explicitRetryAfterNothingRecognized() {
        // Automatic: refused, twice over — the attempt marker and the phase.
        #expect(SessionSpeechRules.keepsModeActive(after: .nothingRecognized))
        #expect(SessionSpeechRules.shouldStartRecording(
            mode: .armed, direction: .germanToChinese, isRevealed: false,
            hasAttemptedCurrentCard: true, phase: .noSpeechDetected
        ) == false)
        // By hand: the button is enabled in that state, which is what makes
        // the retry possible at all.
        #expect(RecordAnswerButton.isEnabled(at: .noSpeechDetected))
        #expect(RecordAnswerButton.isHidden(at: .noSpeechDetected) == false)
    }

    @Test("A running recording is offered as a stop, not as a start")
    func recordingIsStoppedByTheSameControl() {
        // Requirement of the phase: the learner ends the recording, and the
        // control has to say so. Phase 9 already does this; pinned here
        // because phase 12 depends on it.
        #expect(RecordAnswerButton.isStopping(at: .recording))
        #expect(RecordAnswerButton.title(for: .recording) == "Aufnahme beenden")
        #expect(RecordAnswerButton.isStopping(at: .ready) == false)
    }
}
