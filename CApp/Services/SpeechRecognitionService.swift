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
    enum Phase: Equatable {
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
        guard phase != .recording, phase != .finalizing else { return }

        failure = nil
        phase = .preparing

        // 1. Does this device support the transcriber at all? Apple's own
        //    hardware check, and the first thing it names under "Check device
        //    support".
        guard SpeechTranscriber.isAvailable else {
            Self.logger.info("SpeechTranscriber.isAvailable == false")
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
            phase = .unavailable
            return
        }
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
                    downloadProgress = request.progress
                    phase = .downloading
                }
                try await request.downloadAndInstall()
                downloadProgress = nil
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
            if finalStatus == .downloading {
                phase = .downloading
                failure = nil
                return
            }
            guard finalStatus == .installed else {
                phase = .failed
                failure = .speechAssetsUnavailable(String(describing: finalStatus))
                return
            }
        } catch {
            downloadProgress = nil
            phase = .failed
            failure = .speechAssetsFailed(error)
            Self.logger.error("asset preparation failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        phase = .ready
    }

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
            await prepare()
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
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
        downloadProgress = nil
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
