//
//  SpeechModelWorkTests.swift
//  CAppTests
//

import Foundation
import Speech
import Testing
@testable import CApp

/// Who may start a model run, who may write its result, and what a run that
/// lost the race is allowed to do.
///
/// ## What this file can and cannot prove
///
/// `prepare()` itself is unreachable from a test — it talks to
/// `SpeechTranscriber` and `AssetInventory`, and the project decided in phase
/// 9 against mocking Apple's speech stack. What **is** reachable is the
/// machinery `prepare()` is built out of, and that is where the two defects
/// of the second review lived: the state was written after the download
/// instead of before it, and nothing stopped a second run from starting
/// beside the first.
///
/// So these tests prove the rules, and — where a guard sits **before** the
/// first `await` — that the production entry points consult them. What stays
/// structural is everything inside `prepare()` behind an Apple call: the
/// order of the steps, and which state each late exit writes. The device
/// checklist covers the observable half.
///
/// One test here (`refreshClearsOnlyTheModelFailure`) does reach Apple's
/// stack through `refreshModelStatus()`. No assertion depends on the answer —
/// what it checks happens before the first `await` — but the file is not
/// entirely device-free, and saying otherwise would be the kind of claim this
/// project does not make.
@MainActor
struct SpeechModelWorkTests {

    // MARK: - Starting

    @Test("A run claims the state, and says so")
    func startingClaimsTheState() throws {
        let service = SpeechRecognitionService()
        #expect(service.modelState == .unknown)

        let run = try #require(service.beginModelWork(), "an idle service must let a run start")
        #expect(service.modelState == .preparing)
        #expect(service.canPrepareModel == false, "no second invitation while this one runs")
        #expect(service.canRemoveModel == false)
        #expect(service.isCurrentModelWork(run))
    }

    @Test("A second run is refused while the first is preparing")
    func noSecondRunWhilePreparing() throws {
        let service = SpeechRecognitionService()
        let first = try #require(service.beginModelWork())

        #expect(service.beginModelWork() == nil, "this is what stops the second download")

        // And the refusal changes nothing: the first run still owns the state.
        #expect(service.modelState == .preparing)
        #expect(service.isCurrentModelWork(first))
    }

    @Test("A second run is refused while the first is downloading")
    func noSecondRunWhileDownloading() throws {
        // The window the review measured. It lasts minutes, not milliseconds:
        // `downloadAndInstall()` is the longest `await` in the app.
        let service = SpeechRecognitionService()
        let run = try #require(service.beginModelWork())
        #expect(service.applyModelState(.downloading, for: run))

        #expect(service.modelState == .downloading)
        #expect(service.canPrepareModel == false, "the button that invited the second tap")
        #expect(service.beginModelWork() == nil, "and the rule behind the button")
    }

    @Test("Apple downloading on its own does not block a run of ours")
    func systemDownloadIsNotOurWork() throws {
        // `.assets(.downloading)` is Apple's answer, not a run of ours — a
        // later status read may correct it, and nothing of ours owns it.
        let service = SpeechRecognitionService()
        let first = try #require(service.beginModelWork())
        #expect(service.applyModelState(.assets(.downloading), for: first))

        #expect(service.modelState.isBusy == false)
        #expect(service.beginModelWork() != nil)
    }

    // MARK: - Staleness

    @Test("A superseded run cannot write the state")
    func staleRunWritesNothing() throws {
        let service = SpeechRecognitionService()
        let old = try #require(service.beginModelWork())
        #expect(service.applyModelState(.downloading, for: old))

        // Something outranks it — releasing the model is the user's explicit
        // decision and takes the generation with it.
        let new = service.takeOverModelWork(claiming: .releasing)
        #expect(service.isCurrentModelWork(old) == false)
        #expect(service.isCurrentModelWork(new))

        // The old run comes back from its `await` and tries to finish.
        #expect(service.applyModelState(.assets(.installed), for: old) == false)
        #expect(service.modelState == .releasing, "what the taking-over run claimed, untouched")

        // And the state it left behind is not orphaned: the takeover owns it
        // and can end it. The first version only moved the generation, which
        // barred the old run from writing its ending and left nobody able to
        // write one — the settings froze on „Wird geladen …" until the app
        // was restarted.
        #expect(service.applyModelState(.assets(.installed), for: new))
        #expect(service.modelState.isBusy == false)
    }

    @Test("A takeover always leaves somebody able to end the busy state")
    func takeoverNeverOrphansTheState() throws {
        // The invariant in one line: whatever a takeover claims, the claiming
        // run can write over it. Without this, `refreshModelStatus()` — which
        // refuses to correct a busy state on purpose — is locked out too, and
        // nothing short of a restart helps.
        for claimed: SpeechModelState in [.preparing, .downloading, .releasing] {
            let service = SpeechRecognitionService()
            _ = try #require(service.beginModelWork())
            let taker = service.takeOverModelWork(claiming: claimed)

            #expect(service.modelState == claimed)
            #expect(service.applyModelState(.assets(.supported), for: taker))
            #expect(service.modelState.isBusy == false)
        }
    }

    @Test("Starting a download sets state, progress and phase together")
    func downloadStartIsOneOperation() throws {
        // The three used to be three assignments at the call site, which is
        // how they drifted apart. `beginDownload` is what `prepare()` calls
        // immediately before the long `await`, so the screen cannot say one
        // thing while the app does another.
        let service = SpeechRecognitionService()
        let run = try #require(service.beginModelWork())

        #expect(service.beginDownload(Progress(totalUnitCount: 10), for: run))
        #expect(service.modelState == .downloading)
        #expect(service.downloadProgress != nil, "a real Progress, not a made-up percentage")
        #expect(service.phase == .downloading)
        #expect(service.canPrepareModel == false)
    }

    @Test("A superseded run cannot start or finish a download")
    func staleRunLeavesProgressAlone() throws {
        // The second half of the same defect: two runs, the older one comes
        // back and sets `downloadProgress = nil` — and the bar for the newer
        // one disappears while it is still downloading.
        let service = SpeechRecognitionService()
        let old = try #require(service.beginModelWork())
        let new = service.takeOverModelWork(claiming: .preparing)
        #expect(service.beginDownload(Progress(totalUnitCount: 10), for: new))

        // The old run returns from its `await` and tries both halves.
        #expect(service.beginDownload(Progress(totalUnitCount: 99), for: old) == false)
        service.finishDownload(for: old)

        #expect(service.downloadProgress != nil, "the newer run's bar is still there")
        #expect(service.modelState == .downloading)

        // The owner may of course finish.
        service.finishDownload(for: new)
        #expect(service.downloadProgress == nil)
    }

    @Test("The newest run always wins, however many there were")
    func onlyTheNewestRunOwnsTheState() throws {
        let service = SpeechRecognitionService()
        let first = try #require(service.beginModelWork())
        let second = service.takeOverModelWork(claiming: .preparing)
        let third = service.takeOverModelWork(claiming: .preparing)

        #expect(service.isCurrentModelWork(first) == false)
        #expect(service.isCurrentModelWork(second) == false)
        #expect(service.isCurrentModelWork(third))
        #expect(service.applyModelState(.assets(.installed), for: third))
        #expect(service.modelState == .assets(.installed))
    }

    // MARK: - Leaving the busy states

    @Test("Success leaves the downloading state for good")
    func successLeavesDownloading() throws {
        // A loop rather than `arguments:` — `AssetInventory.Status` is not
        // `Sendable`, so a parameterised test would have to carry it across
        // an isolation boundary.
        for status: AssetInventory.Status in [.installed, .supported, .unsupported] {
            let service = SpeechRecognitionService()
            let run = try #require(service.beginModelWork())
            #expect(service.applyModelState(.downloading, for: run))

            #expect(service.applyModelState(.assets(status), for: run))
            #expect(service.modelState.isBusy == false, "nothing may keep claiming work that ended")
            #expect(service.beginModelWork() != nil, "and the next attempt is possible again")
        }
    }

    @Test("Failure leaves the downloading state, and offers another try")
    func failureLeavesDownloading() throws {
        let service = SpeechRecognitionService()
        let run = try #require(service.beginModelWork())
        #expect(service.applyModelState(.downloading, for: run))

        #expect(service.applyModelState(.failed, for: run))
        #expect(service.modelState.isBusy == false)
        #expect(service.canPrepareModel, "a failed attempt must not be a dead end")
        #expect(service.canRemoveModel == false, "and must not offer to remove what is not there")
    }

    // MARK: - Which failure belongs to which screen

    @Test("A recognition failure from the learning screen stays out of the settings")
    func recordingFailureIsNotAModelFailure() {
        // The sentence the review found under „Sprachmodelle": „Die
        // Selbsteinschätzung geht weiterhin." True, and about a screen the
        // reader was not on.
        let service = SpeechRecognitionService()
        service.failure = .speechRecognitionFailed(RecognitionTestError.any)

        #expect(service.modelFailure == nil, "the settings read this one, and it is empty")
        #expect(service.failure != nil, "while the learning screen keeps its own")
    }

    @Test("Re-opening the settings drops a stale model failure, not the recording one")
    func refreshClearsOnlyTheModelFailure() async {
        let service = SpeechRecognitionService()
        service.failure = .speechRecognitionFailed(RecognitionTestError.any)

        // A release that gave nothing back, from an earlier visit.
        await service.releaseModel()
        service.failure = .speechRecognitionFailed(RecognitionTestError.any)

        // Opening the screen again asks for a fresh answer.
        await service.refreshModelStatus()

        #expect(service.modelFailure == nil, "no stale message on a fresh look")
        #expect(service.failure != nil, "and the recording path is none of its business")
    }

    // MARK: - That the production entry points actually consult the rules

    @Test("prepare() refuses while a run of ours is in flight")
    func prepareConsultsTheGuard() async throws {
        // Reachable in a test because the guard sits **before** the first
        // `await`: a busy service must return from `prepare()` having touched
        // nothing at all. Without this, replacing the guard with an
        // unconditional takeover would leave the whole suite green.
        //
        // One caveat, stated rather than hidden: a mutant without the guard
        // would not fail here cleanly — it would walk into `SpeechTranscriber`
        // and possibly a real asset request. The green path below touches
        // neither.
        let service = SpeechRecognitionService()
        let run = try #require(service.beginModelWork())
        #expect(service.applyModelState(.downloading, for: run))
        service.failure = .speechRecognitionFailed(RecognitionTestError.any)

        await service.prepare()

        #expect(service.modelState == .downloading, "the running download is untouched")
        #expect(service.isCurrentModelWork(run), "and still owns the state")
        #expect(service.failure != nil, "a refused run clears nothing either")
    }

    @Test("refreshModelStatus() leaves a running download alone")
    func refreshConsultsTheGuard() async throws {
        // The other guard before the first `await`. Re-opening the settings
        // while a download runs must not overwrite „Wird geladen …" with
        // Apple's older answer — which would put the prepare button back and
        // reopen the very window this round closed.
        let service = SpeechRecognitionService()
        let run = try #require(service.beginModelWork())
        #expect(service.applyModelState(.downloading, for: run))

        await service.refreshModelStatus()

        #expect(service.modelState == .downloading)
        #expect(service.canPrepareModel == false)
    }

    @Test("A fresh look keeps the explanation of a failed attempt")
    func refreshKeepsTheCurrentFailure() async {
        // The learner taps the microphone, the preparation fails, and she
        // goes to the settings to find out why. The first version of the
        // clearing deleted the message on the way in — the `.failed` state
        // exists to carry exactly that explanation.
        let service = SpeechRecognitionService()
        let run = service.takeOverModelWork(claiming: .preparing)
        #expect(service.applyModelState(.failed, for: run))
        service.setModelFailureForTesting(.speechAssetsFailed(RecognitionTestError.any))

        await service.refreshModelStatus()

        #expect(service.modelFailure != nil, "the sentence that explains the state stays")
    }

    @Test("The settings section shows the model failure and never the recording one")
    func onlyTheModelFailureReachesTheSettings() {
        let recording = AppError.speechRecognitionFailed(RecognitionTestError.any)
        let model = AppError.speechModelNotReleased

        #expect(SettingsView.modelMessage(modelFailure: nil, recordingFailure: recording) == nil,
                "this is the sentence the review found in the model section")
        #expect(SettingsView.modelMessage(modelFailure: model, recordingFailure: nil) == model.message)
        #expect(SettingsView.modelMessage(modelFailure: model, recordingFailure: recording) == model.message)
        #expect(SettingsView.modelMessage(modelFailure: nil, recordingFailure: nil) == nil)
    }

    @Test("Releasing without a resolved locale says so instead of doing nothing")
    func releaseWithoutLocaleReports() async {
        // Reachable only if the state claimed something was installed without
        // a locale ever having been resolved. Silence after a confirmed
        // destructive dialog is the one outcome that must not happen.
        let service = SpeechRecognitionService()
        #expect(service.locale == nil)

        await service.releaseModel()

        // `AppError` is not `Equatable` — it carries system errors — so the
        // case is matched rather than compared.
        if case .speechModelNotReleased = service.modelFailure {} else {
            Issue.record("expected speechModelNotReleased, got \(String(describing: service.modelFailure))")
        }
    }
}

/// A stand-in error, because `AppError` carries a real one.
private enum RecognitionTestError: Error { case any }
