//
//  LearnFlowTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// The phase-13 flow rules: `docs/learning-engine.md` §13.5 and the state table
/// in `docs/roadmap.md` § Phase 13.
///
/// These are the conditions that used to live in a `body`, which is why they are
/// here: a `body` is not reachable from a test, and the phase-7 audit measured
/// what that costs.
@MainActor
struct LearnFlowTests {

    // MARK: - The reveal button's title

    @Test("In mode A the button says Aufgeben, and the phase cannot change that")
    func modeAAlwaysSaysAufgeben() {
        // Including a refused microphone and a device that cannot recognise
        // Mandarin. A control that renames itself depending on the microphone is
        // harder to learn than one that does not, and the word describes the same
        // thing in all of those states.
        //
        // **That it holds for all ten phases is a property of the signature, not
        // of a loop**: `revealTitle(in:)` takes no phase, so a phase-dependent
        // title would not compile. An earlier version of this test iterated over
        // the ten phases and asserted the same phase-independent expression ten
        // times — it read like coverage of the state table and was none. The
        // audit was right to call that out.
        #expect(LearnFlow.revealTitle(in: .germanToChinese) == "Aufgeben")
    }

    @Test("Mode B keeps Antwort zeigen")
    func modeBKeepsItsOwnTitle() {
        // Revealing **is** the intended step of mode B, not giving up on an
        // attempt — there is nothing to attempt there in the first place.
        #expect(LearnFlow.revealTitle(in: .audioToGerman) == "Antwort zeigen")
    }

    @Test("Neither title makes a claim the app cannot support")
    func titlesSayNothingForbidden() {
        for direction in [SessionDirection.germanToChinese, .audioToGerman] {
            let title = LearnFlow.revealTitle(in: direction)
            for word in SpeechRecognitionTests.forbiddenWordings {
                #expect(title.contains(word) == false, "\(title) says \(word)")
            }
        }
    }

    // MARK: - Whether a recording was possible

    @Test("Only the two permanently impossible phases rule a recording out")
    func recordingIsPossibleExceptWhenItCannotBe() {
        let impossible: Set<SpeechRecognitionService.Phase> = [.unavailable, .permissionDenied]

        for phase in SpeechRecognitionService.Phase.allCases {
            #expect(
                LearnFlow.allowsRecording(at: phase) == (impossible.contains(phase) == false),
                "\(phase)"
            )
        }
    }

    // MARK: - Reinsertion (§13.5)

    @Test("Giving up in mode A puts the card back")
    func givingUpReinserts() {
        #expect(LearnFlow.reinserts(
            in: .germanToChinese,
            wasManualReveal: true,
            recordingWasPossible: true
        ))
    }

    @Test("Without a manual reveal nothing is put back")
    func aFinishedAttemptDoesNotReinsert() {
        // This is the mismatch case, and it is the one that matters: a mismatch
        // reveals the card through `applyRecognition`, not by hand, so it closes
        // with no reinsertion. A mismatch is explicitly not negative evidence —
        // scheduling a repetition on it would be acting on a signal the app says
        // it does not trust.
        #expect(LearnFlow.reinserts(
            in: .germanToChinese,
            wasManualReveal: false,
            recordingWasPossible: true
        ) == false)
    }

    @Test("On a device that cannot record, nothing is put back")
    func withoutRecognitionNothingIsReinserted() {
        // Without this the batch would double on such a device: revealing is the
        // only way forward there, so every card would come back once — seven
        // cards would become fourteen questions, every card twice, always.
        #expect(LearnFlow.reinserts(
            in: .germanToChinese,
            wasManualReveal: true,
            recordingWasPossible: false
        ) == false)
    }

    @Test("Mode B never puts a card back")
    func modeBNeverReinserts() {
        for possible in [true, false] {
            #expect(LearnFlow.reinserts(
                in: .audioToGerman,
                wasManualReveal: true,
                recordingWasPossible: possible
            ) == false, "recordingWasPossible: \(possible)")
        }
    }

    @Test("The label and the reinsertion are two separate rules")
    func labelAndReinsertionAreDecoupled() {
        // The decoupling is the decision of §13.5, and it is easy to undo by
        // accident: the obvious refactor is „one predicate for both", which would
        // either rename the button on a device without a microphone or double
        // every batch there.
        // The label is constant in mode A (checked once above — it takes no
        // phase), so what this has to show is the other half: in exactly the two
        // states where the label still says *Aufgeben*, the scheduling says no.
        for phase in [SpeechRecognitionService.Phase.unavailable, .permissionDenied] {
            #expect(LearnFlow.reinserts(
                in: .germanToChinese,
                wasManualReveal: true,
                recordingWasPossible: LearnFlow.allowsRecording(at: phase)
            ) == false, "\(phase): the label still says Aufgeben, but nothing is put back")
        }
        // And in a state where a recording *is* possible, the same call does put
        // the card back — otherwise the loop above would pass on a predicate that
        // always returns `false`.
        #expect(LearnFlow.reinserts(
            in: .germanToChinese,
            wasManualReveal: true,
            recordingWasPossible: LearnFlow.allowsRecording(at: .ready)
        ))
    }

    // MARK: - The revealed card's decision bar

    @Test("Either Weiter or the offer, never both")
    func exactlyOneClosingControl() {
        // The offer replaces „Weiter" rather than joining it: „Ablehnen" **is**
        // the neutral way out, and a third button with the same outcome under a
        // different name would only ask the learner to invent a difference.
        //
        // **What this pins is the predicate, not the layout.** That the two are
        // mutually exclusive is the `if/else` in `RevealedDecisionBar.body`, which
        // no test reaches; this rules out an inverted predicate and nothing more.
        #expect(RevealedDecisionBar.showsProposal(nil) == false, "no offer means Weiter")
        for status in LearningStatus.allCases {
            #expect(RevealedDecisionBar.showsProposal(status), "\(status) is an offer")
        }
    }

    @Test("The offer reads as a transition between two named statuses")
    func offerNamesBothSides() {
        #expect(RevealedDecisionBar.transitionTitle(from: .medium, to: .good) == "Mittel → Gut")
        #expect(RevealedDecisionBar.transitionTitle(from: .new, to: .medium) == "Neu → Mittel")

        // VoiceOver gets the arrow spelled out — an arrow is not a word.
        #expect(
            RevealedDecisionBar.accessibilityLabel(from: .medium, to: .good)
                == "Neue Einstufung: von Mittel auf Gut"
        )
        #expect(
            RevealedDecisionBar.accessibilityLabel(from: .medium, to: .good).contains("→") == false,
            "the spoken version must not contain the arrow"
        )
    }

    @Test("Nothing the decision bar says claims more than the app can support")
    func decisionBarSaysNothingForbidden() {
        // Hard rule 7 and hard rule 6 as a string check, over every pair the
        // ladder can actually produce plus the fixed labels.
        var visible = ["Neue Einstufung", "Weiter", "Ablehnen", "Bestätigen"]
        for status in LearningStatus.allCases {
            guard let proposal = AssistedAssessment.proposedStatus(from: status) else { continue }
            visible.append(RevealedDecisionBar.transitionTitle(from: status, to: proposal))
            visible.append(RevealedDecisionBar.accessibilityLabel(from: status, to: proposal))
        }

        for text in visible {
            for word in SpeechRecognitionTests.forbiddenWordings {
                #expect(text.contains(word) == false, "\(text) says \(word)")
            }
        }
    }

    // MARK: - One card transition, one key (F1 of the phase-13 audit)

    @Test("The cycle key changes exactly once per card transition")
    func theCycleKeyChangesOncePerTransition() {
        // This is the half of the „stop speech → change card → record" sequence
        // that a test can reach. The other half — that `speech.stop()` runs first —
        // lives in a `body` and is named as structural in the roadmap.
        //
        // Both halves of the key are load-bearing, and both have already been
        // wrong once: the phase-12 review found that an id-only observer misses a
        // reinsertion, and that a count-only observer misses a deleted card.
        let first = UUID()
        let second = UUID()

        let atFirst = LearnFlow.cardCycleKey(cardID: first, answeredCount: 0)

        #expect(LearnFlow.cardCycleKey(cardID: first, answeredCount: 0) == atFirst,
                "nothing changed, so the key must not change — otherwise every redraw is a transition")
        #expect(LearnFlow.cardCycleKey(cardID: second, answeredCount: 1) != atFirst,
                "a different card is a transition")
        #expect(LearnFlow.cardCycleKey(cardID: first, answeredCount: 1) != atFirst,
                "the **same** card coming back after a give-up is a transition too")
        #expect(LearnFlow.cardCycleKey(cardID: nil, answeredCount: 0) != atFirst,
                "a card deleted mid-session is a transition")

        // And distinctness across a whole reinsertion sequence: A, B, A again.
        let keys = [
            LearnFlow.cardCycleKey(cardID: first, answeredCount: 0),
            LearnFlow.cardCycleKey(cardID: second, answeredCount: 1),
            LearnFlow.cardCycleKey(cardID: first, answeredCount: 2),
        ]
        #expect(Set(keys).count == 3, "three appearances, three keys")
    }

    // MARK: - „Fertig" has exactly one meaning (F7)

    @Test("Fertig means one thing on the learning screen")
    func fertigMeansOneThing() {
        // Acceptance criterion 17. Until phase 13 „Fertig" was the toolbar button
        // that **left the session**; now it finalises a recording, and the toolbar
        // says „Beenden". Both strings used to be literals inside a `body`, where
        // no test could reach them — so this criterion was structural for exactly
        // as long as it took the audit to say so.
        let visible = LearnFlow.ownLabels
            + SpeechRecognitionService.Phase.allCases.map { RecordAnswerButton.title(for: $0) }
            + ["Weiter", "Ablehnen", "Bestätigen", "Hanzi anzeigen"]

        #expect(visible.filter { $0 == LearnFlow.finishRecordingTitle }.count == 1,
                "Fertig may appear exactly once, with one meaning")
        #expect(LearnFlow.endSessionTitle == "Beenden")
        #expect(LearnFlow.finishRecordingTitle == "Fertig")
        #expect(LearnFlow.endSessionTitle != LearnFlow.finishRecordingTitle)
    }

    @Test("Every state of the recording row has its own exact wording")
    func everyRowStateHasItsExactWording() {
        // The state table of the roadmap, pinned word for word rather than only
        // „not empty". The audit found two of ten titles exactly pinned; a table
        // that is the acceptance criterion deserves all ten.
        let expected: [SpeechRecognitionService.Phase: String] = [
            .idle: "Antwort sprechen",
            .ready: "Antwort sprechen",
            .failed: "Antwort sprechen",
            .noSpeechDetected: "Antwort sprechen",
            .unavailable: "Spracherkennung nicht verfügbar",
            .permissionDenied: "Mikrofon nicht freigegeben",
            .preparing: "Wird vorbereitet …",
            .downloading: "Sprachmodell wird geladen …",
            .recording: "Aufnahme abbrechen",
            .finalizing: "Wird ausgewertet …",
        ]
        #expect(expected.count == SpeechRecognitionService.Phase.allCases.count,
                "a new phase needs a wording above")
        for phase in SpeechRecognitionService.Phase.allCases {
            #expect(RecordAnswerButton.title(for: phase) == expected[phase], "\(phase)")
        }
    }

    // MARK: - The two-state recording row

    @Test("The split row is derived from the phase and nothing else")
    func stopControlIsDerivedFromThePhase() {
        for phase in SpeechRecognitionService.Phase.allCases {
            #expect(
                RecordAnswerButton.showsStopControl(at: phase) == (phase == .recording),
                "\(phase)"
            )
            // One predicate drives the layout, the action and the tint — phase 13
            // briefly had three spellings of it, which is three chances to drift.
            #expect(RecordAnswerButton.isEnabled(at: phase) || phase != .recording,
                    "\(phase): a running recording has to stay tappable")
        }
    }

    @Test("An automatically started recording shows the same split row")
    func autoStartedRecordingLooksIdentical() {
        // Phase 12 arms the session and starts the recording; this row only
        // reports what the service is doing. Because it reads the phase and not
        // who started it, a new card in speech mode shows „Fertig" plus the ■
        // straight away rather than „Antwort sprechen".
        #expect(RecordAnswerButton.showsStopControl(at: .recording))
        #expect(RecordAnswerButton.title(for: .ready) == "Antwort sprechen")
    }

    @Test("The wide control cancels while recording and says so")
    func wideControlCancelsWhileRecording() {
        #expect(RecordAnswerButton.title(for: .recording) == "Aufnahme abbrechen")
        #expect(RecordAnswerButton.symbol(for: .recording) == "stop.circle")
        #expect(RecordAnswerButton.isEnabled(at: .recording), "and it has to be tappable")
    }

    @Test("Finalising is not tappable, so Fertig cannot fire twice")
    func finalizingIsNotTappable() {
        #expect(RecordAnswerButton.isEnabled(at: .finalizing) == false)
        #expect(RecordAnswerButton.showsStopControl(at: .finalizing) == false, "and the ■ is gone with it")
    }
}
