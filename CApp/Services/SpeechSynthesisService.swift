//
//  SpeechSynthesisService.swift
//  CApp
//

import AVFoundation
import Observation
import OSLog
import SwiftUI

/// Speaks Chinese out loud, on a deliberate tap.
///
/// One instance for the whole app, created in `CAppApp` and handed down
/// through the environment. Not a singleton: the app already owns its
/// `ModelContainer` that way, so a second lifetime-scoped object needs no new
/// pattern — and definitely no DI container (`docs/architecture.md` §1).
///
/// ## What it speaks
///
/// **Hanzi, always.** The Pinyin the app shows is a *visual* learning aid
/// (A29); handing a Latin transcription to a Mandarin synthesizer would turn
/// our tone rules into a second speech engine, and Apple would be
/// pronouncing letters instead of Chinese. A29 and A31.
///
/// ## Lifetime
///
/// Two things must be retained, both because Apple says so: the synthesizer
/// (`Note`: "The system doesn't automatically retain the speech synthesizer,
/// so you need to manually retain it until speech concludes"), and the
/// delegate, because `AVSpeechSynthesizer.delegate` is `weak`. A synthesizer
/// created inside `speak()` is the classic way to get speech that cuts off
/// immediately.
///
/// ## Audio session
///
/// `usesApplicationAudioSession` is `true` by default — measured on the
/// device, and only documented in the SDK header and WWDC20, not in the API
/// reference. So the synthesizer uses the app's shared session and does
/// **not** manage it: configuring and activating are this class's job.
/// `.playback` is what keeps playback audible with the Ring/Silent switch on
/// silent, which is the whole point for a learning app; `.voicePrompt` is
/// documented as the mode for text-to-speech. The combination is not
/// explicitly documented as valid, and an invalid one would silently fall
/// back rather than throw — so it was verified on the device through
/// `availableModes` (Q5).
///
/// The session is activated per utterance and deactivated when speech ends,
/// with `notifyOthersOnDeactivation` so that anything we interrupted can
/// resume.
@MainActor
@Observable
final class SpeechSynthesisService {

    /// The voice the app speaks with, or `nil` when the device has no
    /// Mainland Mandarin voice installed.
    private(set) var voice: VoiceCandidate?

    /// Whether speech is running. Drives the button's active look, nothing
    /// else.
    private(set) var isSpeaking = false

    /// The text currently being spoken, so a button can tell whether *it* is
    /// the one playing. Without it the card list would fill every visible
    /// speaker at once.
    private(set) var spokenText: String?

    /// Set when the audio session refused to start, cleared when the user has
    /// seen it. Never blocks anything: a card must stay learnable without
    /// sound (`CLAUDE.md` rule 5, applied to audio).
    var failure: AppError?

    /// Whether the app can speak at all. The play buttons use this to
    /// disappear rather than to sit there dead.
    var isAvailable: Bool { voice != nil }

    /// The one long-lived synthesizer.
    private let synthesizer = AVSpeechSynthesizer()

    /// Held explicitly, because `delegate` is a weak reference.
    private let observer: SpeechObserver

    /// The utterance the newest tap started.
    ///
    /// This is what makes a fast second tap replace the first instead of
    /// queueing behind it, and it is deliberately *not* built on the delegate
    /// callbacks: `didCancel` is documented **not** to fire while the
    /// synthesizer sits in a delay between utterances or for utterances that
    /// were never spoken, and its order against a `speak(_:)` issued right
    /// afterwards is not documented at all. So the state is set synchronously
    /// on the tap, and any callback for a different utterance is discarded by
    /// identity.
    ///
    /// Two properties for one thing: `current` retains the utterance so it
    /// cannot be deallocated mid-speech, and `currentIdentity` is what the
    /// comparison actually uses — `AVSpeechUtterance` is not `Sendable`, so
    /// the object must not cross the actor hop from the delegate, while an
    /// `ObjectIdentifier` may.
    private var current: AVSpeechUtterance?
    private var currentIdentity: ObjectIdentifier?

    /// The rate a learner hears. `0.45` against Apple's default of `0.5`,
    /// chosen in a physical listening test on 2026-09-09 that compared
    /// `0.40`, `0.45` and `0.50`: the fastest was intelligible but too quick
    /// for the learning mode, the slowest a useful option but not the
    /// default, and `0.45` kept the sentence rhythm natural. Q5 records it.
    /// A three-step setting comes in phase 10.
    static let rate: Float = 0.45

    /// Where the installed voices come from.
    ///
    /// Injected the same way the learning engine takes its clock and its
    /// generator: the app passes the real thing, a test passes a list. That
    /// is what makes "no Mandarin voice installed" reachable at all — the
    /// nine `zh-CN` voices are system components and cannot be uninstalled,
    /// so without this seam the whole missing-voice path could only be
    /// reasoned about. The audit found exactly that gap.
    private let installedVoices: @MainActor () -> [VoiceCandidate]

    init(
        installedVoices: @escaping @MainActor () -> [VoiceCandidate]
            = SpeechSynthesisService.systemVoices
    ) {
        self.installedVoices = installedVoices
        observer = SpeechObserver()
        // The callback is wired **before** the delegate is set, so "written
        // before the synthesizer can call back" holds by construction rather
        // than by the accident that nothing has spoken yet.
        observer.onEnd = { [weak self] identity in
            self?.speechEnded(identity)
        }
        synthesizer.delegate = observer
        refreshVoice()
        observeVoiceChanges()
    }

    // MARK: - Voices

    /// Looks the voice up again.
    ///
    /// Called on init, whenever the system reports a change, and before
    /// speaking. The last one matters: a voice the user installs in Settings
    /// must work when they come back, without reinstalling the app. Caching
    /// `nil` once at launch and giving up forever would be the bug here.
    func refreshVoice() {
        voice = MandarinVoiceSelection.best(from: installedVoices())
    }

    /// The voices actually installed on this device.
    static func systemVoices() -> [VoiceCandidate] {
        AVSpeechSynthesisVoice.speechVoices().map(candidate)
    }

    /// Subscribes to the system's own notification, which is more honest than
    /// polling: it fires when the user downloads or deletes a voice
    /// (iOS 17+).
    ///
    /// `assumeIsolated` is safe **here** and would not be in the delegate:
    /// the queue is one this call chose, so main-thread delivery is
    /// guaranteed by this code rather than assumed about someone else's.
    private func observeVoiceChanges() {
        NotificationCenter.default.addObserver(
            forName: AVSpeechSynthesizer.availableVoicesDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshVoice()
            }
        }
    }

    private static func candidate(_ voice: AVSpeechSynthesisVoice) -> VoiceCandidate {
        VoiceCandidate(
            identifier: voice.identifier,
            language: voice.language,
            quality: quality(of: voice.quality),
            name: voice.name
        )
    }

    /// Maps Apple's quality to ours. An explicit `switch` with `@unknown
    /// default` rather than a raw-value cast, because Apple documents no
    /// ordering and a future case must not quietly rank itself.
    ///
    /// Internal rather than `private`, so a test can reach it. This is the
    /// single hinge the whole voice decision turns on: swapping two cases
    /// here would leave every test green while the app silently demoted the
    /// best installed voice and fell back through the tiebreak. The audit
    /// found it unfalsifiable, which for one `switch` is a bad trade.
    static func quality(of quality: AVSpeechSynthesisVoiceQuality) -> VoiceQuality {
        switch quality {
        case .default: .default
        case .enhanced: .enhanced
        case .premium: .premium
        @unknown default: .default
        }
    }

    // MARK: - Speaking

    /// Whether `hanzi` is worth speaking.
    ///
    /// The same Han-script test the Pinyin resolver uses, so "usable Chinese"
    /// means one thing in the app. Deliberately **not** coupled to
    /// `needsReview`: a word whose Pinyin could not be settled — `东西` — is
    /// still perfectly speakable, and Apple decides its reading itself. A31.
    static func canSpeak(_ hanzi: String) -> Bool {
        PinyinService.containsHanScript(hanzi.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Speaks `hanzi`, replacing whatever is currently playing.
    ///
    /// A pure audio action: nothing about the card, the learning status, the
    /// counters or any manual-edit flag is touched, and nothing is saved.
    func speak(_ hanzi: String) {
        let text = hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.canSpeak(text) else { return }

        // A voice may have arrived since the last look.
        if voice == nil { refreshVoice() }
        guard let voice else { return }
        guard let systemVoice = AVSpeechSynthesisVoice(identifier: voice.identifier) else {
            // The identifier is valid but the voice is gone — the user
            // deleted it. Look again so the button disappears instead of
            // staying visible and dead.
            refreshVoice()
            return
        }

        // A fresh utterance every time: enqueueing the same one twice throws,
        // and `rate` has no effect once it is enqueued.
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = systemVoice
        utterance.rate = Self.rate

        // Claim the slot *before* cancelling, so the old utterance's callback
        // cannot tear down the session under the new one.
        current = utterance
        currentIdentity = ObjectIdentifier(utterance)

        // Unconditionally, and that matters: whether `isSpeaking` is already
        // `true` right after a `speak(_:)` is **not** documented. Guarding on
        // it meant a second tap inside that window cancelled nothing, and
        // `speak(_:)` is documented to *enqueue* — so the first utterance
        // would finish and the second play after it. Exactly the queue this
        // phase rules out. Stopping when nothing runs is documented as
        // harmless: it returns `false` and removes every unspoken utterance.
        // Found by the review.
        synthesizer.stopSpeaking(at: .immediate)

        do {
            try activateSession()
        } catch {
            current = nil
            currentIdentity = nil
            isSpeaking = false
            spokenText = nil
            // Give the session back. Without this it is the one path that
            // leaks it: the previous utterance was already cancelled, its
            // callback now finds no matching identity and is discarded, so
            // nobody else would ever deactivate — and other apps stay ducked
            // until the app quits. Found by the review.
            deactivateSession()
            failure = .speechUnavailable(error)
            Self.logger.error("Audio session refused: \(error.localizedDescription, privacy: .public)")
            return
        }

        isSpeaking = true
        spokenText = text
        synthesizer.speak(utterance)
    }

    /// Stops immediately.
    ///
    /// Called when a view that offered speech goes away — the learn session,
    /// the editor sheet — so the previous card does not talk into the next
    /// one. It is also the only teardown that does **not** depend on a
    /// delegate callback: if an interruption swallows both `didFinish` and
    /// `didCancel`, this is what releases the session.
    ///
    /// Checks the service's own state, not `synthesizer.isSpeaking`, for the
    /// same reason `speak` no longer does: that property's timing is
    /// undocumented, and a `stop()` that does nothing in exactly the window
    /// where it is needed is worse than none.
    func stop() {
        guard currentIdentity != nil || isSpeaking else { return }
        current = nil
        currentIdentity = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        spokenText = nil
        deactivateSession()
    }

    /// One utterance finished or was cancelled.
    ///
    /// Discards anything that is not the current utterance. That is the race
    /// from a fast double tap: the first utterance's cancel callback arrives
    /// after the second one is already speaking, and it must not stop it or
    /// deactivate the session.
    private func speechEnded(_ identity: ObjectIdentifier) {
        guard identity == currentIdentity else { return }
        current = nil
        currentIdentity = nil
        isSpeaking = false
        spokenText = nil
        deactivateSession()
    }

    // MARK: - Audio session

    private func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .voicePrompt)
        try session.setActive(true)
    }

    private func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            // Nothing to recover and nothing to tell the user: the speech
            // already happened. Worth a log, because a session that stays
            // active would keep other apps ducked.
            Self.logger.error("Audio session stayed active: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static let logger = Logger(subsystem: "de.belaunsch.CApp", category: "speech")
}

/// Receives the synthesizer's callbacks and forwards them to the main actor.
///
/// Its own object for one reason: the thread the delegate methods run on is
/// **not documented** — not in the reference, not in the header, not in
/// WWDC — and `AVSpeechSynthesizer` is not `Sendable` while the delegate
/// protocol is. So the callbacks are `nonisolated` and hop explicitly.
/// `MainActor.assumeIsolated` would be a claim about the calling thread that
/// nothing supports.
private final class SpeechObserver: NSObject, AVSpeechSynthesizerDelegate {

    /// Set once by the service. `@unchecked` because the callback thread is
    /// unknown and the closure is only ever written before the synthesizer
    /// can call back.
    nonisolated(unsafe) var onEnd: ((ObjectIdentifier) -> Void)?

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        end(utterance)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        end(utterance)
    }

    private nonisolated func end(_ utterance: AVSpeechUtterance) {
        // Only the identity travels. `AVSpeechUtterance` is not `Sendable`,
        // and `ObjectIdentifier` is — which is exactly enough to tell "the
        // utterance the newest tap started" from a stale callback.
        let identity = ObjectIdentifier(utterance)
        let callback = onEnd
        Task { @MainActor in
            callback?(identity)
        }
    }
}
