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

    @Test("Speech output on a covered card ends the mode")
    func speechOutputOnACoveredCardEndsTheMode() {
        // The roadmap's own product rule: somebody who is listening is not
        // speaking, and a mode that records again right afterwards takes that
        // decision away from them. Re-arming needs a deliberate tap.
        #expect(SessionSpeechRules.keepsModeActive(after: .speechOutputStartedWhileCovered) == false)
        #expect(SessionSpeechRules.cancelsRecording(on: .speechOutputStartedWhileCovered))
    }

    @Test("Speech output on the revealed card does not end the mode (A44)")
    func speechOutputOnARevealedCardKeepsTheMode() {
        // The phase-13 narrowing. Without it phase 13 would have abolished the
        // phase-12 feature: the learner now lands on **every** card in the
        // revealed state, where the big speaker sits, so listening to one answer
        // would have cost the speech mode every single time.
        //
        // The reason the covered case ends the mode does not apply here: this
        // attempt's recording is over, and the next one cannot start before the
        // card changes — which stops speech first.
        #expect(SessionSpeechRules.keepsModeActive(after: .speechOutputStartedWhileRevealed))
        #expect(
            SessionSpeechRules.cancelsRecording(on: .speechOutputStartedWhileRevealed) == false,
            "there is no recording on a revealed card to cancel"
        )

        var state = SessionSpeechState(mode: .armed)
        let cancels = state.apply(.speechOutputStartedWhileRevealed)
        #expect(cancels == false)
        #expect(state.mode == .armed, "still armed after listening to the answer")
    }

    @Test("Which speech-output event it is comes from the card state, not the view")
    func speechOutputFactoryMapsTheCardState() {
        // A factory rather than an `if` in the `body`: the mapping belongs next
        // to the cases, and then the rules stay entirely inside the decision
        // table where a test can drive them.
        #expect(SessionSpeechEvent.speechOutputStarted(onRevealedCard: true)
            == .speechOutputStartedWhileRevealed)
        #expect(SessionSpeechEvent.speechOutputStarted(onRevealedCard: false)
            == .speechOutputStartedWhileCovered)
    }

    @Test("The learner's ■ throws the recording away and keeps the mode (A45)")
    func cancellingKeepsTheModeAndTheLoopGuard() {
        // An abandoned attempt is not an attempt: nothing is evaluated, nothing
        // is revealed, nothing is written. Cancelling one recording is not a
        // decision about the next card, so the mode survives.
        #expect(SessionSpeechRules.keepsModeActive(after: .recordingCancelledByLearner))
        #expect(SessionSpeechRules.cancelsRecording(on: .recordingCancelledByLearner))
        #expect(
            SessionSpeechEvent.recordingCancelledByLearner.startsANewAttempt == false,
            "and the loop guard stays set: a further attempt on this card takes a tap (A38)"
        )

        let card = UUID()
        var state = SessionSpeechState()
        state.armStartingRecording(on: card)
        let cancelled = state.apply(.recordingCancelledByLearner)
        #expect(cancelled, "the recording is thrown away")
        #expect(state.mode == .armed, "the mode survives")
        #expect(
            state.shouldStartRecording(
                for: card, direction: .germanToChinese, isRevealed: false, phase: .ready
            ) == false,
            "and nothing restarts on this card by itself"
        )
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
            .cardChanged,
            .speechOutputStartedWhileRevealed, .recordingCancelledByLearner,
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
            .nothingRecognized, .speechOutputStartedWhileRevealed,
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

        #expect(SessionSpeechEvent.allCases.count == 11, "a new event needs a decision above")
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

    @Test("After the attempt is closed the next card records on its own")
    func closingLeadsToTheNextRecording() {
        // The real sequence: a card was recorded, the learner closed the attempt
        // („Weiter", „Bestätigen" or „Ablehnen"), and the new card must get a
        // recording. The first version of this test compared two unrelated UUIDs
        // and proved nothing — it was a duplicate of `armedStartsOnAFreshCard` in
        // disguise. Found by the audit.
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
        // „Aufgeben" on the **last** card of a batch puts the same card back at
        // position zero — the card id never changes, so an id-only observer would
        // miss it entirely and the session would sit armed and silent on a card it
        // is meant to record. Found in the phase-12 review.
        //
        // What makes it a card change anyway is the composite key: it counts
        // closed attempts as well as the id
        // (`LearnFlowTests.theCycleKeyChangesOncePerTransition`). Phase 13 could
        // therefore drop the separate „a rating was recorded" event, which never
        // had a production caller.
        let card = UUID()
        var state = SessionSpeechState()
        state.armStartingRecording(on: card)

        let cancels = state.apply(.cardChanged)

        #expect(cancels, "whatever was running belonged to the previous appearance")
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

        let cancelled = state.apply(.speechOutputStartedWhileCovered)
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
            .speechOutputStartedWhileCovered, .appLeftForeground, .audioInterrupted,
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
        // Requirement of phase 12: the learner ends the recording, and the
        // control has to say so. **Phase 13 split the job in two** — „Fertig"
        // finalises and evaluates, the ■ beside it throws the attempt away — so
        // the wide control now cancels while recording, and its title says that
        // rather than „Aufnahme beenden".
        #expect(RecordAnswerButton.showsStopControl(at: .recording))
        #expect(RecordAnswerButton.title(for: .recording) == "Aufnahme abbrechen")
        #expect(RecordAnswerButton.showsStopControl(at: .recording), "and Fertig sits beside it")
        #expect(RecordAnswerButton.showsStopControl(at: .ready) == false)
    }
}
