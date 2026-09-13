//
//  SpeechRecognitionService.swift
//  CApp
//

import AVFoundation
import Foundation
import OSLog
import Speech

/// Turns spoken Mandarin into text, and nothing else.
///
/// ## What this owns and what it refuses to know
///
/// Locale resolution, asset readiness, the microphone, audio conversion, the
/// analyzer, start and stop, the final recognised text, technical errors.
/// **Not**: cards, learning status, Pinyin, any judgement about the answer.
/// It hands back a `String` and the caller decides what that means — which is
/// why the comparison lives in `SpeechCheck` and the card association lives in
/// `LearnSessionModel`.
///
/// ## The iOS 26 pipeline, and why it is not Apple's example
///
/// Apple's own `SpeechAnalyzer` overview uses `CaptureInputSequenceProvider`
/// and `AnalyzerInputConverter`. Both are **iOS 27.0** and do not exist on
/// this app's deployment target — the example does not compile here. The
/// phase-9 spike verified that symbol by symbol. So the pipeline is the one
/// from Apple's sample project, which does target 26.0: `AVAudioEngine` with
/// a tap, an `AVAudioConverter` onto the format the analyzer asks for, and
/// `AnalyzerInput` values pushed into an `AsyncStream`.
///
/// The analyzer **does not convert audio** — Apple states that outright — so
/// the conversion is a requirement, not an optimisation. The target format is
/// read at runtime from `bestAvailableAudioFormat(compatibleWith:)`; the
/// 16 kHz mono Int16 the spike measured is a device reading, not an API
/// contract, and appears nowhere in this file.
///
/// ## Permissions
///
/// Microphone only. `NSSpeechRecognitionUsageDescription` and
/// `SFSpeechRecognizer.requestAuthorization` belong to the legacy path that
/// sends audio to Apple's servers; Apple states that `SpeechAnalyzer`
/// transcriber modules do not (Q4). Permission is requested when the user
/// first taps the microphone, never at launch.
@MainActor
@Observable
final class SpeechRecognitionService {

    /// Where the feature stands. Drives the button, and nothing else reads
    /// into it.
    ///
    /// `CaseIterable` purely so tests can walk every state — the button's
    /// label, note and symbol are switched over this type, and a new case
    /// must not be able to slip in with a symbol name nobody checked.
    enum Phase: Equatable, CaseIterable {
        /// Nothing has been asked yet.
        case idle
        /// This device cannot do it: no transcriber, or no Mainland
        /// Simplified locale. Permanent for this device — not an error the
        /// user can retry away.
        case unavailable
        /// The microphone was refused. Also not retryable in-app.
        case permissionDenied
        /// Checking availability, reserving, querying asset status.
        case preparing
        /// Downloading the speech model. `downloadProgress` carries Apple's
        /// own `Progress`.
        case downloading
        /// Ready to record.
        case ready
        /// Recording.
        case recording
        /// Recording stopped, the analyzer is finishing.
        case finalizing
        /// The recording finished and produced no usable text.
        ///
        /// Its own state rather than a silent return to `.ready`: without it
        /// a learner who spoke too quietly got a button that went busy and
        /// came back, with no card opening and no word of explanation —
        /// indistinguishable from a bug. Informative only; it judges nothing
        /// about the speaking, because nothing here measured it.
        case noSpeechDetected
        /// Something technical went wrong. `failure` says what. Retryable.
        case failed
    }

    private static let logger = Logger(subsystem: "de.belaunsch.CApp", category: "speech-recognition")

    private(set) var phase: Phase = .idle

    /// Apple's own progress object during a model download. Deliberately the
    /// real one: a fake percentage that moves on a timer would be a lie about
    /// something the user is waiting for.
    private(set) var downloadProgress: Progress?

    /// The last technical failure, for the UI to show.
    ///
    /// Publicly settable so the view can clear it, the same shape
    /// `SpeechSynthesisService.failure` has. Task 9.3 asks for progress
    /// **and errors** to be visible; an error nobody can read claims
    /// coverage and provides none.
    var failure: AppError?

    /// The resolved locale, once validated. `nil` until `prepare()` has run.
    private(set) var locale: Locale?

    /// What the settings screen knows about the Mandarin model.
    ///
    /// Read fresh every time rather than remembered — Apple documents that
    /// the system may unsubscribe an app from assets it has not used in a
    /// while, so a cached "installed" is a claim that expires without telling
    /// anyone.
    ///
    /// A state rather than an `AssetInventory.Status?`, because the optional
    /// had to mean three different things at once: not asked yet, no
    /// transcriber on this device, and no Mainland Simplified locale. The
    /// review found what that costs — a device without a usable locale showed
    /// „Wird geprüft …" forever next to a button that did nothing and said
    /// nothing.
    ///
    /// Read-only from outside **and** from inside: every write goes through
    /// `applyModelState(_:for:)`, which refuses writes from a run that has
    /// been superseded. A stored property anyone could assign to is how the
    /// download window stayed open in the first place.
    var modelState: SpeechModelState { storedModelState }

    private var storedModelState: SpeechModelState = .unknown

    /// The last failure of the **model management** — preparing or removing.
    ///
    /// Separate from `failure`, which belongs to the recording path, because
    /// the two are read in different places and mean different things. The
    /// review found a recognition error from a learning session standing
    /// under „Sprachmodelle" in the settings, telling the reader that „die
    /// Selbsteinschätzung geht weiterhin" — true, and about a screen they
    /// were not on. One property per audience is the smallest fix that keeps
    /// both errors visible where they belong.
    private(set) var modelFailure: AppError?

    /// Counts model-management runs, so a suspended one can tell it has been
    /// replaced.
    ///
    /// The same device the recording path uses (`epoch`), for the same
    /// reason and now for a second sequence: `prepare()` holds the state
    /// across a download that takes minutes, and in that window a release —
    /// or a later prepare — may take over. A stale run comes back, finds a
    /// newer generation and touches nothing.
    private var modelEpoch = 0

    // MARK: - Who may write the model state
    //
    // These four are `internal` rather than `private` so the tests can drive
    // them directly. That is deliberate and worth naming: `prepare()` itself
    // cannot run in a test — it talks to `SpeechTranscriber` and
    // `AssetInventory` — so the rules it depends on are only checkable here.
    // What the tests therefore prove is the **machinery**: who may start, who
    // may write, and what a superseded run is allowed to do. That `prepare()`
    // uses it is structural and was read, not measured.

    /// Claims the model state for a new run, or refuses because one is
    /// already in flight.
    ///
    /// Returns the run's generation, which every later write has to present.
    /// `nil` means somebody else is working and this caller must do nothing
    /// at all — not wait, not retry, not force. That is the whole guard
    /// against a second download: it sits in the state, not on the button.
    func beginModelWork() -> Int? {
        guard storedModelState.isBusy == false else { return nil }
        modelEpoch += 1
        storedModelState = .preparing
        return modelEpoch
    }

    /// Invalidates whatever run is in flight and claims the next generation.
    ///
    /// For work that must proceed even though something else is running —
    /// releasing the model is the user's explicit decision and outranks a
    /// preparation nobody asked for twice.
    ///
    /// **It claims the state as well, and that is not a detail.** The first
    /// version only moved the generation: the superseded run was then barred
    /// from writing its own ending, so a `.preparing` or `.downloading` it had
    /// left behind belonged to nobody — and `refreshModelStatus()` refuses to
    /// correct a busy state on purpose. The settings screen froze on „Wird
    /// geladen …" until the app was restarted. Whoever takes over inherits
    /// the duty to end the state.
    func takeOverModelWork(claiming state: SpeechModelState) -> Int {
        modelEpoch += 1
        storedModelState = state
        return modelEpoch
    }

    /// Sets the model failure. Tests only.
    ///
    /// `modelFailure` is `private(set)` because only a run may write it, and
    /// the one state a test cannot otherwise produce is „a run has just
    /// failed" — reaching it for real needs a failing `AssetInventory`.
    func setModelFailureForTesting(_ error: AppError?) {
        modelFailure = error
    }

    /// Whether `run` still owns the model state.
    func isCurrentModelWork(_ run: Int) -> Bool {
        run == modelEpoch
    }

    /// Announces a download that is **about to** start.
    ///
    /// One operation rather than three assignments at the call site, because
    /// the three have to agree: the state, the progress bar and the phase all
    /// describe the same thing, and the defect this round fixed was exactly
    /// them drifting apart. `false` means a newer run owns the screen and
    /// this one must not start anything.
    @discardableResult
    func beginDownload(_ progress: Progress, for run: Int) -> Bool {
        guard applyModelState(.downloading, for: run) else { return false }
        downloadProgress = progress
        phase = .downloading
        return true
    }

    /// Takes the progress bar away again once the download has returned.
    ///
    /// Guarded, because a run that lost ownership while downloading must not
    /// clear the bar of the one that took over.
    func finishDownload(for run: Int) {
        guard isCurrentModelWork(run) else {
            Self.logger.info("stale download \(run, privacy: .public) kept its hands off the progress")
            return
        }
        downloadProgress = nil
    }

    /// Writes the state on behalf of `run`, or refuses if it is stale.
    ///
    /// The return value is the caller's cue to stop: `false` means a newer
    /// run owns the screen now, and continuing would overwrite its truth
    /// with an older one.
    @discardableResult
    func applyModelState(_ state: SpeechModelState, for run: Int) -> Bool {
        guard isCurrentModelWork(run) else {
            Self.logger.info("stale model run \(run, privacy: .public) dropped")
            return false
        }
        storedModelState = state
        return true
    }

    // MARK: - Live session state

    private var analyzer: SpeechAnalyzer?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?

    /// Counts recordings, so a suspended one can tell it has been replaced.
    ///
    /// `stopAndFinalize` holds its analyzer across an `await` that can take a
    /// while. In that window the learner can reveal by hand, rate, move on
    /// and start recording again — and the old continuation would come back
    /// and tear down the **new** recording's engine and session. The epoch is
    /// compared after every suspension: a stale one returns and touches
    /// nothing.
    private var epoch = 0
    private var resultsTask: Task<Void, Never>?
    private var engine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private var analyzerFormat: AVAudioFormat?

    /// The best final text seen so far in this recording.
    ///
    /// Collected as results arrive rather than read at the end, because the
    /// transcriber publishes finalised phrases as it goes and the stream is
    /// done by the time `finalizeAndFinishThroughEndOfInput()` returns.
    private var finalText = ""

    // MARK: - Preparation

    /// Availability, locale, reservation, assets — in that order.
    ///
    /// Safe to call repeatedly: it re-reads the state every time rather than
    /// trusting a flag. That is not caution but a documented requirement —
    /// Apple may unsubscribe an app from assets that have not been used in a
    /// while, so "we downloaded it once" is never an answer.
    func prepare() async {
        await prepare(forRecording: false)
    }

    /// - Parameter forRecording: whether the run was started by the
    ///   microphone. Only then does a failure reach `failure` and with it the
    ///   note under the microphone button — a preparation the learner started
    ///   in the settings has no business explaining itself on the learning
    ///   card, which is the mirror image of the defect this round fixed.
    private func prepare(forRecording: Bool) async {
        guard phase != .recording, phase != .finalizing else { return }

        // The second tap, refused at its source. `beginModelWork()` says no
        // while a run of ours is in flight, so a second press cannot reserve,
        // request and install a second time beside the first. The button is
        // hidden as well (`canPrepare`), but a hidden button is a courtesy —
        // this is the rule.
        guard let run = beginModelWork() else {
            Self.logger.info("prepare ignored: a model run is already in flight")
            return
        }

        if forRecording { failure = nil }
        modelFailure = nil
        phase = .preparing

        // 1. Does this device support the transcriber at all? Apple's own
        //    hardware check, and the first thing it names under "Check device
        //    support".
        guard SpeechTranscriber.isAvailable else {
            Self.logger.info("SpeechTranscriber.isAvailable == false")
            guard applyModelState(.deviceUnsupported, for: run) else { return }
            phase = .unavailable
            return
        }

        // 2. Resolve the locale through Apple's seam, then **validate** it —
        //    see `MandarinRecognitionLocale` for why a non-nil answer is not
        //    enough.
        let resolved = await SpeechTranscriber.supportedLocale(
            equivalentTo: MandarinRecognitionLocale.requested
        )
        guard let locale = MandarinRecognitionLocale.accepted(resolved) else {
            Self.logger.info(
                "no Mainland Simplified locale; system offered \(resolved?.identifier ?? "nil", privacy: .public)"
            )
            // Named rather than left at `.preparing`: `refreshModelStatus()`
            // has told these two apart since the first review, and `prepare()`
            // used to leave the state untouched here — the same answer given
            // two different ways depending on which function got there first.
            guard applyModelState(.localeUnsupported, for: run) else { return }
            phase = .unavailable
            return
        }
        // Checked before the first write of this branch too, so a run that
        // was superseded while resolving the locale changes nothing at all —
        // not even a value that happens to be the same one.
        guard isCurrentModelWork(run) else { return }
        self.locale = locale

        // 3. The module, configured exactly as it will be used. That matters:
        //    asset status is reported for a module **with its configuration**,
        //    so asking about a different one would answer a different
        //    question. `.transcription` is the plain preset — no volatile
        //    results, no alternatives, no time indexing. The product only ever
        //    acts on a final result.
        let module = SpeechTranscriber(locale: locale, preset: .transcription)

        do {
            // 4. Reserve. Apple says the class does this automatically "if
            //    needed", but the spike measured a device where
            //    `installedLocales` listed zh_CN while the module status said
            //    assets still had to be downloaded — with zero reservations
            //    held. Reserving explicitly removes one unknown from that
            //    picture, and it is harmless: it returns `false` when the
            //    locale was already reserved rather than throwing.
            let statusBefore = await AssetInventory.status(forModules: [module])
            let didReserve = try await AssetInventory.reserve(locale: locale)
            let statusAfter = await AssetInventory.status(forModules: [module])

            // Logged, not shown. This is the open question from the spike,
            // and the phase-9 device test reads it out of the console.
            Self.logger.info(
                """
                asset diagnostics — before=\(String(describing: statusBefore), privacy: .public) \
                reserved=\(didReserve, privacy: .public) \
                after=\(String(describing: statusAfter), privacy: .public)
                """
            )

            // 5. Install if needed. The request is optional by design: `nil`
            //    means there is nothing to download, which is the normal case
            //    and not a failure.
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                // The button only claims a download when one is actually
                // due. The device test caught the difference: after a
                // "nothing recognised", a second attempt re-checks the
                // status — correctly, nothing here is cached — and briefly
                // flashed "Sprachmodell wird geladen …" although the
                // measured status was already `.installed`. Saying
                // "downloading" while nothing downloads is a small lie about
                // something the learner is waiting for, so the neutral
                // `.preparing` stays unless the measured status says work is
                // outstanding.
                if statusAfter != .installed {
                    // **Before** the download, not after it. This line is the
                    // fix for the hole the second review measured:
                    // `downloadAndInstall()` takes minutes, and until it
                    // existed the state said „noch nicht geladen" for every
                    // one of them — next to a button offering to start what
                    // was already running.
                    guard beginDownload(request.progress, for: run) else { return }
                }
                try await request.downloadAndInstall()
                finishDownload(for: run)
            }

            // 6. Never trust "it did not throw". Apple documents that a
            //    failed download is retried later and that the caller should
            //    check the status afterwards, so the status is what decides.
            let finalStatus = await AssetInventory.status(forModules: [module])
            Self.logger.info("asset status after install: \(String(describing: finalStatus), privacy: .public)")

            // `.downloading` means the system is still working and will
            // finish on its own — Apple documents that a failed attempt is
            // retried later. Calling that a failure would send the learner
            // away from a feature that is about to work.
            // Every exit from here on leaves `.preparing`/`.downloading`
            // behind — deterministically, and only if this run still owns the
            // state. A run that returns without doing so would leave the
            // screen claiming work that nobody is doing any more.
            guard applyModelState(.assets(finalStatus), for: run) else { return }

            if finalStatus == .downloading {
                // The system took the download over and will finish it on its
                // own; Apple documents that a failed attempt is retried later.
                // Calling that a failure would send the learner away from a
                // feature that is about to work.
                phase = .downloading
                if forRecording { failure = nil }
                return
            }
            guard finalStatus == .installed else {
                phase = .failed
                modelFailure = .speechAssetsUnavailable(String(describing: finalStatus))
                if forRecording { failure = modelFailure }
                return
            }
        } catch {
            guard isCurrentModelWork(run) else { return }
            downloadProgress = nil
            // `.failed` rather than the last measured status: after a throw
            // the app does not know what is on the device, and guessing would
            // be the kind of claim this project does not make. It is also the
            // one state that offers another try, so the screen does not end
            // here.
            applyModelState(.failed, for: run)
            phase = .failed
            modelFailure = .speechAssetsFailed(error)
            if forRecording { failure = modelFailure }
            Self.logger.error("asset preparation failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        phase = .ready
    }

    // MARK: - Model management (settings)

    /// Re-reads the model status without changing anything.
    ///
    /// Read-only on purpose: it neither reserves nor downloads. The settings
    /// screen calls it when it appears, so the line it shows is current
    /// rather than left over from the last session.
    func refreshModelStatus() async {
        // A run of ours knows more than a measurement taken beside it. Without
        // this line, re-opening the settings while a download runs would
        // overwrite „Wird geladen …" with Apple's older answer and put the
        // prepare button back on screen.
        guard storedModelState.isBusy == false else { return }

        // Opening the screen drops a **stale** message — and only a stale one.
        // The first version dropped every message, and the review found what
        // that costs: a preparation started from the learning screen fails,
        // the learner goes to the settings to find out why, and the screen
        // deletes the explanation on the way in. `.failed` is the state whose
        // whole purpose is to carry that explanation, so its message stays.
        // The recording path's `failure` is left alone either way; it belongs
        // to the learning screen and is none of this screen's business.
        if storedModelState != .failed {
            modelFailure = nil
        }

        // The generation is borrowed, not claimed: this is a measurement, not
        // a piece of work, and it must not invalidate anybody. Borrowing has
        // exactly the right effect — should a real run start while the status
        // is being read, the write below is refused.
        await measureModelStatus(for: modelEpoch)
    }

    /// Reads the status and writes it on behalf of `run`.
    ///
    /// Split out from `refreshModelStatus()` so a run that already owns the
    /// state can end it: the public entry refuses while anything is busy,
    /// which is right for a visitor and wrong for the owner.
    private func measureModelStatus(for run: Int) async {
        guard isCurrentModelWork(run) else { return }
        guard SpeechTranscriber.isAvailable else {
            applyModelState(.deviceUnsupported, for: run)
            return
        }
        let resolved = await SpeechTranscriber.supportedLocale(
            equivalentTo: MandarinRecognitionLocale.requested
        )
        // Told apart from the case above, because they are different answers
        // to the user: the device cannot do speech recognition at all, or it
        // can but not for Mainland Simplified Chinese. Both are permanent,
        // and neither is something a button can fix.
        guard let locale = MandarinRecognitionLocale.accepted(resolved) else {
            applyModelState(.localeUnsupported, for: run)
            return
        }
        guard isCurrentModelWork(run) else { return }
        self.locale = locale
        let module = SpeechTranscriber(locale: locale, preset: .transcription)
        let status = await AssetInventory.status(forModules: [module])
        guard applyModelState(.assets(status), for: run) else { return }

        // And the phase, when this measurement contradicts it. A download the
        // system took over ends `prepare()` with `phase = .downloading` and no
        // path back: the settings button is gone (correctly — nothing to
        // start), and `startRecording()` refuses while `.downloading`. The
        // microphone then said „Sprachmodell wird geladen …" for the rest of
        // the app's life, long after the settings said „Bereit". Older than
        // this round; this is the only place that can see both.
        guard phase == .downloading else { return }
        phase = status == .installed ? .ready : .idle
    }

    /// Gives the locale reservation back, on the user's explicit say-so.
    ///
    /// **The only release path in the app, and it is never automatic.**
    /// Apple: „When your app no longer needs assets for a particular locale,
    /// call `release(reservedLocale:)` … The system will remove the assets at
    /// a later time." Calling that routinely — on session end, on app exit —
    /// would force a fresh download afterwards and quietly undo the offline
    /// capability phase 9 achieved. So it happens here, once, after a
    /// confirmation that says what it costs.
    func releaseModel() async {
        // The same guard `prepare()` has, for the same reason: the settings
        // sheet is reachable while a recording is still finishing, and
        // resetting the state machine underneath it would leave the engine
        // running with nothing left that knows about it. Logged rather than
        // shown: the path needs the microphone to be live in the learning tab
        // while the settings sheet is open over the cards tab, which the
        // navigation does not offer — and inventing a user-facing sentence
        // for it would mean inventing the situation too.
        guard phase != .recording, phase != .finalizing else {
            Self.logger.info("release ignored: a recording is in flight")
            return
        }
        guard let locale else {
            // Not silent: the user just confirmed a destructive dialog, and
            // the sentence is literally true — nothing was given back.
            Self.logger.info("release ignored: no locale resolved")
            modelFailure = .speechModelNotReleased
            return
        }

        // Outranks a preparation in flight: removing is what the user just
        // asked for, twice. The generation moves, so the older run comes back
        // to a state it no longer owns and writes nothing — and the state is
        // claimed at the same time, so the screen says what is happening and
        // the ending is somebody's duty again.
        let run = takeOverModelWork(claiming: .releasing)
        let released = await AssetInventory.release(reservedLocale: locale)
        // The check the rest of this file has made after every suspension
        // since phase 9, and the one place that did not. A release that lost
        // the race must not reset the phase of whatever took over.
        guard isCurrentModelWork(run) else {
            Self.logger.info("release result dropped: superseded while releasing")
            return
        }
        Self.logger.info("released \(locale.identifier, privacy: .public): \(released, privacy: .public)")

        phase = .idle

        guard released else {
            // `false` is not an exception — it means this app held no
            // reservation, so there was nothing to give back and the model
            // stays where it is. Silence after an explicit confirmation would
            // look like the removal worked, so the state is measured again
            // and the sentence says what happened.
            await measureModelStatus(for: run)
            guard isCurrentModelWork(run) else { return }
            modelFailure = .speechModelNotReleased
            return
        }

        // Success does **not** get the measured status. Apple removes the
        // assets „at a later time", so the read right afterwards still says
        // „installed" — and „Bereit" next to a remove button is how a second
        // tap produced „es gab keine Reservierung zurückzugeben" after a
        // removal that had worked. `.released` says what is true: given back,
        // deletion pending, and fetchable again.
        applyModelState(.released, for: run)
        modelFailure = nil
    }

    // The settings screen reads these three. They forward to `SpeechModelState`
    // rather than deciding anything themselves, so the rules can be tested
    // without a device — the same split `RecordAnswerButton` uses for the
    // recording phase.

    /// What the settings screen shows for the model.
    var modelStatusText: String { modelState.text }

    /// Whether preparing would do anything.
    var canPrepareModel: Bool { modelState.canPrepare }

    /// Whether there is a reservation to give back.
    var canRemoveModel: Bool { modelState.canRemove }

    /// Whether the microphone is already granted, without asking.
    var hasMicrophonePermission: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    /// Asks for the microphone, if it has not been decided yet.
    ///
    /// Called on the first tap, never at launch: a permission dialog before
    /// the user has shown any interest in the feature is a dialog they cannot
    /// make sense of.
    func requestMicrophonePermission() async -> Bool {
        if AVAudioApplication.shared.recordPermission == .granted { return true }
        return await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Recording

    /// Starts recording and analysing.
    ///
    /// The caller is responsible for having stopped any speech output first —
    /// this app never records and speaks at the same time, and the two want
    /// different audio session categories.
    func startRecording() async {
        switch phase {
        case .ready, .failed, .idle, .noSpeechDetected, .permissionDenied:
            break
        case .unavailable, .preparing, .downloading, .recording, .finalizing:
            return
        }

        // Whatever a previous attempt left standing goes first. Re-entry from
        // `.failed` used to build a second engine and analyzer on top of the
        // old ones and simply overwrite the references.
        teardown()
        epoch += 1
        failure = nil
        finalText = ""

        guard await requestMicrophonePermission() else {
            phase = .permissionDenied
            return
        }

        // `prepare()` may not have run, or may have run long enough ago that
        // the system unsubscribed us. Cheap to re-check, expensive to assume.
        if phase != .ready {
            await prepare(forRecording: true)
            guard phase == .ready else { return }
        }

        guard let locale else {
            phase = .unavailable
            return
        }

        do {
            let module = SpeechTranscriber(locale: locale, preset: .transcription)
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) else {
                throw RecognitionSetupError.noCompatibleAudioFormat
            }
            analyzerFormat = format

            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            inputBuilder = continuation

            let analyzer = SpeechAnalyzer(modules: [module])
            self.analyzer = analyzer

            // Consume results before the audio starts, so nothing is missed.
            // Only finalised results are kept: a volatile one is a guess in
            // progress, and the product decision must not rest on it.
            resultsTask = Task { [weak self] in
                do {
                    for try await result in module.results where result.isFinal {
                        self?.appendFinal(result.text)
                    }
                } catch {
                    self?.recordingFailed(error)
                }
            }

            try await startEngine(feeding: continuation, into: format)
            try await analyzer.start(inputSequence: stream)

            phase = .recording
        } catch {
            teardown()
            phase = .failed
            failure = .speechRecognitionFailed(error)
            Self.logger.error("recording could not start: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Stops the recording and returns what was recognised.
    ///
    /// Returns `nil` when nothing usable came out — an empty result is a
    /// result, and the caller shows that rather than pretending a comparison
    /// happened.
    @discardableResult
    func stopAndFinalize() async -> String? {
        guard phase == .recording else {
            await cancelRecording()
            return nil
        }

        phase = .finalizing
        let mine = epoch

        do {
            stopEngine()
            // Terminating the input sequence does **not** finish the analysis
            // session — Apple documents that explicitly. The finalize call is
            // what forces the remaining audio to a final result and closes
            // the session.
            inputBuilder?.finish()
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
            await resultsTask?.value
        } catch {
            guard epoch == mine else { return nil }
            teardown()
            phase = .failed
            failure = .speechRecognitionFailed(error)
            Self.logger.error("finalizing failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        // Another recording started while this one was finalising. It owns
        // the engine and the session now.
        guard epoch == mine else { return nil }

        let text = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        teardown()
        guard text.isEmpty == false else {
            phase = .noSpeechDetected
            return nil
        }
        phase = .ready
        return text
    }

    /// Throws the recording away without a result.
    ///
    /// The path for "Antwort zeigen" during a recording, a card change, or
    /// leaving the session. Nothing that was being recognised may surface
    /// afterwards.
    func cancelRecording() async {
        guard analyzer != nil || engine != nil else { return }
        let mine = epoch
        stopEngine()
        inputBuilder?.finish()
        await analyzer?.cancelAndFinishNow()
        guard epoch == mine else { return }
        teardown()
        if phase == .recording || phase == .finalizing {
            phase = .ready
        }
    }

    // MARK: - Audio plumbing

    private func startEngine(
        feeding continuation: AsyncStream<AnalyzerInput>.Continuation,
        into analyzerFormat: AVAudioFormat
    ) async throws {
        let session = AVAudioSession.sharedInstance()
        // The smallest category that records. Not `.playAndRecord`: this app
        // never plays while recording, and asking for playback would keep
        // other audio ducked for no reason.
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)

        let engine = AVAudioEngine()
        self.engine = engine

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: inputFormat, to: analyzerFormat) else {
            throw RecognitionSetupError.noConverter(from: inputFormat, to: analyzerFormat)
        }
        // Apple's sample does this and says why: it sacrifices the quality of
        // the first samples to avoid timestamp drift against the source.
        converter.primeMethod = .none
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            // The tap runs on an audio thread. Converting here is fine — it
            // touches only the converter and the buffer — but reporting a
            // failure has to go back to the main actor.
            switch Self.convert(buffer, with: converter, to: analyzerFormat) {
            case .success(let converted):
                // An empty buffer carries no audio, and AVFoundation says so
                // itself: "mBuffers[0].mDataByteSize (0) should be non-zero"
                // appeared in the device log. The converter can legitimately
                // produce one at the tail of a conversion; passing it on
                // gives the analyzer nothing and the frameworks a complaint.
                guard converted.frameLength > 0 else { return }
                continuation.yield(AnalyzerInput(buffer: converted))
            case .failure(let error):
                Task { @MainActor [weak self] in
                    self?.recordingFailed(error)
                }
            }
        }

        engine.prepare()
        try engine.start()
    }

    /// Converts one buffer, or says why it could not.
    ///
    /// `nonisolated` and static so it can run on the audio thread without
    /// touching this object. **A conversion failure is returned, never
    /// swallowed** — silently dropping buffers would show up as a recognition
    /// that mysteriously misses half the sentence.
    private nonisolated static func convert(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> Result<AVAudioPCMBuffer, any Error> {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return .failure(RecognitionSetupError.noOutputBuffer)
        }

        // `AVAudioConverterInputBlock` is `@Sendable` and `AVAudioPCMBuffer`
        // is not `Sendable`, so handing the buffer through would warn. It is
        // sound here and the reason is narrow enough to state: `convert` is a
        // pull API that invokes this block **synchronously**, on this thread,
        // and returns before it does. The buffer never crosses a thread
        // boundary, and nothing else holds it. Marked rather than suppressed
        // module-wide with `@preconcurrency`, which would hide every future
        // AVFAudio warning as well.
        nonisolated(unsafe) let input = buffer
        var consumed = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return input
        }

        if let conversionError {
            return .failure(conversionError)
        }
        guard status != .error else {
            return .failure(RecognitionSetupError.conversionFailed)
        }
        return .success(output)
    }

    /// Stops the microphone **and hands the audio session back**, both
    /// synchronously.
    ///
    /// The session release lives here, not in `teardown()`, and that is the
    /// whole fix for a bug the device test found: the first speech output
    /// after a recording was silent, the second worked.
    ///
    /// The mechanism: `teardown()` used to deactivate the session, and in
    /// both stop paths it runs **after** an `await` — after
    /// `finalizeAndFinishThroughEndOfInput()` or after `cancelAndFinishNow()`.
    /// During that suspension the card reveals, the learner taps the speaker,
    /// and phase 7 activates `.playback` + `.voicePrompt`. Then the await
    /// returned and deactivated the session **under the running utterance**.
    /// The epoch guard could not see it, because no new *recording* had
    /// started — a different owner had taken the session, not a newer
    /// recording.
    ///
    /// Called from the top of every stop path, before anything suspends. A
    /// release that cannot be late cannot land on someone else's session.
    private func stopEngine() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            // Nothing to recover and nothing to tell the user: the recording
            // is over either way, and the next tap configures the session
            // again from scratch. Worth a line, because a `.record` session
            // that stays active keeps other apps ducked — and this was the
            // one `try?` in the app that swallowed its error without a trace.
            Self.logger.error(
                "audio session stayed active: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Releases everything and hands the audio session back.
    ///
    /// The deactivation matters beyond tidiness: phase 7's speech output
    /// configures `.playback` + `.voicePrompt`, and it can only do that once
    /// the recording session is out of the way.
    private func teardown() {
        // Stopping the engine belongs **here**, not only in the stop path. It
        // used to sit in `stopAndFinalize` alone, which left three ways to a
        // running microphone with no owner: a recognition error mid-recording,
        // a throw after the engine had started, and a second tap from
        // `.failed`. Cleanup in one place is the only version that stays true.
        stopEngine()
        resultsTask?.cancel()
        resultsTask = nil
        inputBuilder = nil
        analyzer = nil
        converter = nil
        analyzerFormat = nil
        engine = nil
        // Only when no model run owns it. The recording lifecycle clearing
        // the model lifecycle's progress bar is exactly the cross-talk this
        // round set out to remove — unreachable today, because the phase
        // guard in `startRecording()` refuses while a model run is busy, but
        // the next change to either path would not know that.
        if storedModelState.isBusy == false {
            downloadProgress = nil
        }
        // No session release here — see `stopEngine()`, which does it
        // synchronously and is called from the first line of this method.
    }

    private func appendFinal(_ text: AttributedString) {
        // `String(_.characters)` rather than `description`: the latter would
        // bring the attribute markup along.
        finalText += String(text.characters)
    }

    private func recordingFailed(_ error: any Error) {
        guard phase == .recording || phase == .finalizing else { return }
        // Tearing down is the point. Without it the microphone kept running
        // with an installed tap and the `.record` session stayed active while
        // the button went back to "Antwort sprechen" — and nothing the
        // learner could tap would stop it, because only the stop path
        // released the engine.
        teardown()
        failure = .speechRecognitionFailed(error)
        phase = .failed
        Self.logger.error("recognition failed: \(error.localizedDescription, privacy: .public)")
    }
}

/// Setup problems that have no Apple error of their own.
///
/// Deliberately small and local: these are the three places where this file
/// gives up before the Speech framework ever sees anything.
nonisolated enum RecognitionSetupError: LocalizedError {
    case noCompatibleAudioFormat
    case noConverter(from: AVAudioFormat, to: AVAudioFormat)
    case noOutputBuffer
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .noCompatibleAudioFormat:
            "Der Analyzer nennt kein passendes Audioformat."
        case .noConverter(let from, let to):
            "Keine Umwandlung von \(from.sampleRate) Hz nach \(to.sampleRate) Hz möglich."
        case .noOutputBuffer:
            "Der Audiopuffer konnte nicht angelegt werden."
        case .conversionFailed:
            "Die Audiodaten ließen sich nicht umwandeln."
        }
    }
}
