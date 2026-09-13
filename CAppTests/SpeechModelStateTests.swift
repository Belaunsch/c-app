//
//  SpeechModelStateTests.swift
//  CAppTests
//

import Speech
import Testing
@testable import CApp

/// The rules behind the speech-model section of the settings.
///
/// None of this needs a microphone, a download or a device — which is the
/// point. `canRemove` unlocks an action whose only undo needs an internet
/// connection, and `canPrepare` decides whether a button invites a second
/// press while a download is already running. Both were unreachable by test
/// until the decision moved out of the service.
@MainActor
struct SpeechModelStateTests {

    /// Every state the settings screen can show.
    static let allStates: [SpeechModelState] = [
        .unknown, .deviceUnsupported, .localeUnsupported,
        .preparing, .downloading, .releasing, .released, .failed,
        .assets(.installed), .assets(.downloading),
        .assets(.supported), .assets(.unsupported),
    ]

    @Test("Each state shows exactly the sentence it is supposed to show")
    func theSentencesArePinned() {
        // Pinned literally, not just checked for being different. The audit
        // found the weaker version: it would have survived swapping „Bereit"
        // and „Noch nicht geladen", which puts „Bereit" next to a button
        // offering to load it — the exact contradiction this type was split
        // out of the service to prevent.
        #expect(SpeechModelState.unknown.text == "Wird geprüft …")
        #expect(SpeechModelState.deviceUnsupported.text == "Auf diesem Gerät nicht verfügbar")
        #expect(SpeechModelState.localeUnsupported.text == "Für Chinesisch auf diesem Gerät nicht verfügbar")
        #expect(SpeechModelState.preparing.text == "Wird vorbereitet …")
        #expect(SpeechModelState.downloading.text == "Wird geladen …")
        #expect(SpeechModelState.releasing.text == "Wird entfernt …")
        #expect(SpeechModelState.released.text == "Freigegeben — das System löscht die Daten später")
        #expect(SpeechModelState.failed.text == "Nicht geladen")
        #expect(SpeechModelState.assets(.installed).text == "Bereit")
        #expect(SpeechModelState.assets(.downloading).text == "Wird geladen …")
        #expect(SpeechModelState.assets(.supported).text == "Noch nicht geladen")
        #expect(SpeechModelState.assets(.unsupported).text == "Nicht unterstützt")
    }

    @Test("Every state says something, and the distinct ones read differently")
    func everyStateHasItsOwnSentence() {
        #expect(Self.allStates.allSatisfy { $0.text.isEmpty == false })

        // The two permanent refusals must not collapse into one sentence:
        // „this device cannot do it" and „it cannot do Chinese" send the user
        // to different places.
        #expect(SpeechModelState.deviceUnsupported.text != SpeechModelState.localeUnsupported.text)

        // Deliberately **not** all-distinct: `.downloading` (this app) and
        // `.assets(.downloading)` (the system, on its own) are two origins of
        // one situation, and the learner waiting for a model does not care
        // which of the two is true. The states stay separate because
        // `isBusy` differs; the sentence is the same on purpose.
        #expect(SpeechModelState.downloading.text == SpeechModelState.assets(.downloading).text)
        let others = Self.allStates.filter { $0 != .assets(.downloading) }.map(\.text)
        #expect(Set(others).count == others.count, "any other pair reading alike is a state too few")
    }

    @Test("Only this app's own run counts as busy")
    func busyMeansOurOwnWork() {
        #expect(SpeechModelState.preparing.isBusy)
        #expect(SpeechModelState.downloading.isBusy)
        #expect(SpeechModelState.releasing.isBusy)
        // Not `.released`: that is a finished run reporting its outcome, and
        // the screen must be able to move on from it.
        #expect(SpeechModelState.released.isBusy == false)
        // Apple downloading on its own is not a run of ours: nothing of ours
        // owns it, and a later status read may correct it.
        #expect(SpeechModelState.assets(.downloading).isBusy == false)
        for state in Self.allStates
        where state != .preparing && state != .downloading && state != .releasing {
            #expect(state.isBusy == false, "\(state) must not claim to be our work")
        }
    }

    @Test("Preparing is offered exactly when something could be downloaded")
    func prepareIsOfferedOnlyWhenItWouldDoSomething() {
        #expect(SpeechModelState.assets(.supported).canPrepare)
        // And after a failed attempt — otherwise the screen is a dead end.
        #expect(SpeechModelState.failed.canPrepare)
        // And after giving the model back, which is when fetching it again is
        // the only thing left to do.
        #expect(SpeechModelState.released.canPrepare)

        // Never while this app is working. Both of these were the defect:
        // the button stood next to its own progress bar and invited the tap
        // that started a second download.
        #expect(SpeechModelState.preparing.canPrepare == false)
        #expect(SpeechModelState.downloading.canPrepare == false)
        #expect(SpeechModelState.releasing.canPrepare == false)

        // The one the review found: after pressing „Vorbereiten" the normal
        // answer on a fresh device is `.downloading`. Leaving the button
        // enabled there invites a second press that runs the whole
        // reserve-and-install path again.
        #expect(SpeechModelState.assets(.downloading).canPrepare == false)
        #expect(SpeechModelState.assets(.installed).canPrepare == false)
        #expect(SpeechModelState.assets(.unsupported).canPrepare == false)

        // Before the first answer there is nothing to promise.
        #expect(SpeechModelState.unknown.canPrepare == false)
        #expect(SpeechModelState.deviceUnsupported.canPrepare == false)
        #expect(SpeechModelState.localeUnsupported.canPrepare == false)
    }

    @Test("Removing is offered only when something is demonstrably installed")
    func removeIsOfferedOnlyWhenThereIsSomethingToRemove() {
        #expect(SpeechModelState.assets(.installed).canRemove)
        // Deliberately **not** after a successful release: Apple deletes the
        // data later, so the status still reads „installed" — and offering to
        // remove it again produced „es gab keine Reservierung zurückzugeben"
        // after a removal that had worked.
        #expect(SpeechModelState.released.canRemove == false)

        // Everything else. A destructive action offered on a guess is worse
        // than one missing for a moment: the way back needs a connection.
        for state in Self.allStates where state != .assets(.installed) {
            #expect(state.canRemove == false, "\(state) must not offer removal")
        }
    }

    @Test("The two buttons are never offered at the same time")
    func theButtonsAreMutuallyExclusive() {
        // Not a tautology of the two rules above but the thing the settings
        // screen shows: preparing and removing next to each other would be a
        // contradiction in the same section.
        #expect(Self.allStates.allSatisfy { ($0.canPrepare && $0.canRemove) == false })
    }

    @Test("The unreleasable case has its own German sentence and no system text")
    func releaseFailureSpeaksForItself() {
        // `release(reservedLocale:)` returns `false` instead of throwing, so
        // there is no system message to append — and after an explicit
        // confirmation the user still has to learn that nothing happened.
        let error = AppError.speechModelNotReleased
        #expect(error.technicalDetail == nil)
        #expect(error.message.contains("bleibt auf dem Gerät"))
        #expect(error.userText == error.message)
    }
}
