//
//  SpeechSynthesisServiceTests.swift
//  CAppTests
//

import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import CApp

/// What can be checked about speech without a speaker in the room.
///
/// The honest boundary of this file: **no test here proves that anything was
/// audible.** That was measured on a physical iPhone 16 Pro on 2026-09-09 and
/// recorded in `docs/apple-frameworks.md` Q5. What is checked here is what a
/// simulator can decide — which text goes to the synthesizer, what happens to
/// unusable input, that the rate is the one that was chosen, and that speaking
/// leaves the data alone.
@MainActor
struct SpeechSynthesisServiceTests {

    // MARK: - What gets spoken

    @Test("Text that is not Chinese is never spoken", arguments: [
        "", "   ", "\n", "asdf", "123", "。", "!!!", "Hello world",
    ])
    func nonChineseIsNotSpoken(input: String) {
        // The same Han-script test the Pinyin resolver uses, so "usable
        // Chinese" means one thing across the app.
        #expect(SpeechSynthesisService.canSpeak(input) == false)
    }

    @Test("Chinese is spoken, with or without surrounding noise", arguments: [
        "你好", "  你好  ", "一个", "东西", "我想吃点东西。", "Wi-Fi 密码",
    ])
    func chineseIsSpoken(input: String) {
        #expect(SpeechSynthesisService.canSpeak(input))
    }

    @Test("A card whose Pinyin needs review is still speakable")
    func reviewFlagDoesNotBlockSpeech() {
        // `东西` cannot be resolved to a single Pinyin reading and carries the
        // review hint. That says nothing about whether Apple can pronounce
        // the characters — coupling the two would silence exactly the cards a
        // learner most wants to hear (A31).
        let resolution = PinyinService.resolution(for: "东西")
        #expect(resolution.needsReview)
        #expect(SpeechSynthesisService.canSpeak("东西"))
    }

    @Test("Speech reads the Hanzi, never the Pinyin")
    func hanziIsTheInput() {
        // Pinyin is a **visual** aid (A29). Handing a Latin transcription to
        // a Mandarin voice would make it pronounce letters, and it would turn
        // our tone rules into a second speech engine (A31). The Pinyin of
        // `你好` is Latin text, so it fails the Han test — which is the
        // structural reason it can never become the utterance.
        let pinyin = PinyinService.pinyin(for: "你好")
        #expect(pinyin == "níhǎo")
        #expect(SpeechSynthesisService.canSpeak(pinyin) == false)
        #expect(SpeechSynthesisService.canSpeak("你好"))
    }

    // MARK: - Rate

    @Test("The rate is the one the listening test settled on")
    func rateIsTheChosenOne() {
        // Not a round number and not Apple's default: `0.45` came out of a
        // physical comparison of 0.40, 0.45 and 0.50 (Q5). Pinned so a later
        // tidy-up cannot quietly return it to the default.
        #expect(SpeechSynthesisService.rate == 0.45)
        #expect(SpeechSynthesisService.rate < AVSpeechUtteranceDefaultSpeechRate)
        #expect(SpeechSynthesisService.rate > AVSpeechUtteranceMinimumSpeechRate)
    }

    // MARK: - Availability

    @Test("Availability rests on a Mandarin voice, not on any voice")
    func availabilityRestsOnMandarin() {
        // An earlier version compared `isAvailable` with `voice != nil`,
        // which is how the property is written — the test could not fail.
        // Found by the review. What is worth asserting is the *rule* behind
        // it, and that lives in the pure selection: a machine full of voices
        // is still unavailable if none of them is Mainland Mandarin.
        let foreign = [
            VoiceCandidate(identifier: "a", language: "en-US", quality: .premium),
            VoiceCandidate(identifier: "b", language: "zh-TW", quality: .enhanced),
        ]
        #expect(MandarinVoiceSelection.best(from: foreign) == nil)

        let withMandarin = foreign + [
            VoiceCandidate(identifier: "c", language: "zh-CN", quality: .default)
        ]
        #expect(MandarinVoiceSelection.best(from: withMandarin)?.identifier == "c")

        // And on this machine, whatever it has: availability and the voice
        // agree, and any chosen voice passes the filter.
        let service = SpeechSynthesisService()
        defer { service.stop() }
        if let voice = service.voice {
            #expect(service.isAvailable)
            #expect(MandarinVoiceSelection.isMainlandMandarin(voice.language))
        } else {
            #expect(service.isAvailable == false)
        }
    }

    @Test("A refresh does not lose an already-found voice")
    func refreshIsStable() {
        let service = SpeechSynthesisService()
        defer { service.stop() }
        let before = service.voice
        service.refreshVoice()
        #expect(service.voice == before, "the same device must answer the same way")
    }

    @Test("Any voice that is chosen is Mainland Mandarin")
    func chosenVoiceIsMainland() throws {
        // Whatever this machine happens to have installed, the one thing that
        // must hold is the filter. `#require` rather than `if let`, so a
        // runtime without a voice says so instead of passing silently.
        let service = SpeechSynthesisService()
        defer { service.stop() }
        let voice = try #require(service.voice, "keine zh-CN-Stimme auf dieser Laufzeit")
        #expect(MandarinVoiceSelection.isMainlandMandarin(voice.language))
    }

    @Test("Nothing is speaking before anything was asked for")
    func idleAtStart() {
        let service = SpeechSynthesisService()
        #expect(service.isSpeaking == false)
        #expect(service.failure == nil)
    }

    @Test("Unusable input leaves the state untouched")
    func unusableInputChangesNothing() {
        let service = SpeechSynthesisService()
        defer { service.stop() }
        service.speak("asdf")
        service.speak("")
        #expect(service.isSpeaking == false, "nothing started, so nothing is running")
        #expect(service.failure == nil, "and it is not an error either")
    }

    // MARK: - The hinge the voice decision turns on

    @Test("Apple's three quality classes map to lowest, middle and highest")
    func appleQualityMapsToOurOrder() {
        // `MandarinVoiceSelection` ranks `VoiceQuality` values, and every
        // test of that ranking builds them by hand. So none of them can
        // notice if the conversion **into** those values is wrong. The audit
        // showed that swapping two cases in `quality(of:)` leaves the whole
        // suite green while the app quietly demotes the best installed voice
        // and falls back through the tiebreak — the inversion of the
        // phase-7 result. That is why this one `switch` is internal.
        let low = SpeechSynthesisService.quality(of: .default)
        let middle = SpeechSynthesisService.quality(of: .enhanced)
        let high = SpeechSynthesisService.quality(of: .premium)

        // Ordering, because ordering is what the selection actually uses.
        // Two strict comparisons also settle that no two of Apple's classes
        // collapse into one rank.
        #expect(low < middle, ".default must not outrank .enhanced")
        #expect(middle < high, ".enhanced must not outrank .premium")

        // And the ends are really the ends, asked against every class that
        // exists rather than against a literal: should a fourth class ever
        // be added, this stops passing and the question gets asked again
        // instead of being answered by an old assumption.
        #expect(low == VoiceQuality.allCases.min(), ".default is the lowest class")
        #expect(high == VoiceQuality.allCases.max(), ".premium is the highest class")
    }

    // MARK: - Wiring the audit found unguarded

    @Test("The synthesizer has its delegate, and the service holds exactly one")
    func delegateIsWired() throws {
        // Deleting `synthesizer.delegate = observer` once passed the entire
        // suite. In production that means: after every naturally finished
        // utterance `isSpeaking` stays true, `spokenText` stays set, and the
        // `.playback` session is never released — because `speechEnded` is
        // the only teardown that runs in normal use. Found by the audit,
        // which measured the whole delegate path at 0 %. No test count here
        // on purpose: it moves with every phase, and a comment that cites a
        // stale measurement claims more than it knows.
        //
        // Reached through `Mirror`, the same idiom `engineUntouched` uses:
        // the properties are private on purpose, and the alternative would be
        // opening them up for a test.
        let service = SpeechSynthesisService()
        defer { service.stop() }

        let synthesizers = Mirror(reflecting: service).children
            .compactMap { $0.value as? AVSpeechSynthesizer }
        #expect(synthesizers.count == 1, "exactly one, and it lives as long as the app")

        let synthesizer = try #require(synthesizers.first)
        #expect(synthesizer.delegate != nil, "otherwise nothing ever ends the speech")
    }

    @Test("Speaking configures the session so the silent switch cannot mute it")
    func sessionIsConfiguredForPlayback() throws {
        // `.playback` → `.ambient` passed every test, and that single line is
        // what the criterion "the Ring/Silent switch does not suppress TTS"
        // hangs on: the default session is documented to be silenced by it.
        // Found by the audit. This does not prove audibility — that is the
        // device's job — it proves the configuration the device exercises.
        let service = SpeechSynthesisService()
        defer { service.stop() }
        try #require(service.isAvailable, "keine zh-CN-Stimme auf dieser Laufzeit")

        service.speak("你好")

        let session = AVAudioSession.sharedInstance()
        #expect(session.category == .playback)
        #expect(session.mode == .voicePrompt)
    }

    // MARK: - The visible consequence of having no voice

    @Test("The speaker is hidden without a voice, and hidden without Chinese")
    func speakerVisibility() {
        // The audit measured `SpeakButton.body` at 0 % and showed that
        // dropping either half of the condition passed the suite. The rule
        // lives in a function now, so it can be falsified.
        #expect(SpeakButton.isVisible(isAvailable: true, hanzi: "你好"))
        #expect(
            SpeakButton.isVisible(isAvailable: false, hanzi: "你好") == false,
            "no voice, no button — not a dead one"
        )
        #expect(SpeakButton.isVisible(isAvailable: true, hanzi: "") == false)
        #expect(SpeakButton.isVisible(isAvailable: true, hanzi: "asdf") == false)
        #expect(SpeakButton.isVisible(isAvailable: false, hanzi: "") == false)
    }

    @Test("Only the playing text's button looks active")
    func onlyOneButtonLooksActive() {
        // The bug this prevents: in the card list every visible speaker
        // filled at once, because `isSpeaking` is global. Deleting the
        // comparison passed the suite until this test existed.
        #expect(SpeakButton.isSpeaking("你好", isSpeaking: true, spokenText: "你好"))
        #expect(SpeakButton.isSpeaking("苹果", isSpeaking: true, spokenText: "你好") == false)
        #expect(SpeakButton.isSpeaking("你好", isSpeaking: false, spokenText: "你好") == false)
        #expect(SpeakButton.isSpeaking("你好", isSpeaking: true, spokenText: nil) == false)
        // Trimmed, so a card with stray whitespace still recognises itself.
        #expect(SpeakButton.isSpeaking("  你好 ", isSpeaking: true, spokenText: "你好"))
    }

    @Test("Without a Mandarin voice nothing is available, nothing speaks, nothing breaks")
    func withoutAnyMandarinVoice() {
        // The state the target device cannot produce: its nine `zh-CN`
        // voices are system components. Reached through the injected voice
        // list — the same seam the learning engine uses for its clock and
        // generator — because otherwise this whole path could only be
        // argued about. The audit showed `isAvailable` could be pinned to
        // `true` with every test still green.
        let service = SpeechSynthesisService(installedVoices: {
            [
                VoiceCandidate(identifier: "en", language: "en-US", quality: .premium),
                VoiceCandidate(identifier: "tw", language: "zh-TW", quality: .enhanced),
            ]
        })
        defer { service.stop() }

        #expect(service.voice == nil)
        #expect(service.isAvailable == false)
        #expect(SpeakButton.isVisible(isAvailable: service.isAvailable, hanzi: "你好") == false)
        #expect(RootView.shouldNotice(isAvailable: service.isAvailable))

        // And asking it to speak is a no-op rather than a crash or an error:
        // a card stays learnable without sound.
        service.speak("你好")
        #expect(service.isSpeaking == false)
        #expect(service.spokenText == nil)
        #expect(service.failure == nil)
    }

    @Test("A voice that appears later is picked up")
    func voiceAppearingLater() {
        // The situation from Q5: the user installs a voice in Settings and
        // comes back. Nothing may be cached from the first `nil`.
        // Ein Referenztyp statt einer eingefangenen Variablen: Ein `var`
        // nach dem Einfangen zu ändern ist im Swift-6-Modus ein Fehler.
        final class VoiceBox { var voices: [VoiceCandidate] = [] }
        let box = VoiceBox()
        let service = SpeechSynthesisService(installedVoices: { box.voices })
        defer { service.stop() }
        #expect(service.isAvailable == false)

        box.voices = [VoiceCandidate(
            identifier: "com.apple.voice.super-compact.zh-CN.Tingting",
            language: "zh-CN",
            quality: .default
        )]
        service.refreshVoice()
        #expect(service.isAvailable)
        #expect(service.voice?.identifier == "com.apple.voice.super-compact.zh-CN.Tingting")
    }

    @Test("The notice is due exactly when no voice is available")
    func noticeIsDueWithoutAVoice() {
        // `isAvailable` could be pinned to `true` without a test failing, so
        // the entire "no voice" consequence rested on a `body` no test can
        // reach. Found by the audit.
        #expect(RootView.shouldNotice(isAvailable: false))
        #expect(RootView.shouldNotice(isAvailable: true) == false)
        #expect(MissingVoiceNotice.shouldShow(alreadyShown: false))
        #expect(MissingVoiceNotice.shouldShow(alreadyShown: true) == false)
    }

    // MARK: - The notice about a missing voice

    @Test("The missing-voice notice asks to be shown once per app run")
    func noticeShowsOnce() {
        // The notice holds only the bookkeeping; the flag that drives the
        // alert lives in the view. That split came out of the review: with
        // the state here, `body` read no observable property and the alert
        // could not be relied on to appear.
        let notice = MissingVoiceNotice()
        #expect(notice.shouldShow(), "first time, yes")
        #expect(notice.shouldShow() == false, "and never again this run")
        #expect(notice.shouldShow() == false)

        // A fresh run asks again. There is no stored flag and no schema
        // field — intended, because the situation is still true and a
        // permanent "never again" would hide something the user can fix.
        #expect(MissingVoiceNotice().shouldShow())
    }

    @Test("The notice does not promise a Settings path that may not exist")
    func noticeAvoidsAFragilePath() {
        // Apple renames these screens between versions, so the message names
        // Accessibility and spoken content without claiming an exact
        // navigation sequence. A wrong instruction is worse than a general
        // one.
        let message = MissingVoiceNotice.message
        #expect(message.contains("Bedienungshilfen"))
        #expect(message.contains("Stimme"))
        #expect(message.isEmpty == false)
    }

    // MARK: - Speech changes no data

    @Test("Speaking leaves the card, its status and its counters alone")
    func speechChangesNoData() async throws {
        // Play is a pure audio action. Nothing about the card may move,
        // nothing may be saved — otherwise a tap on the speaker would quietly
        // rewrite learning progress.
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let card = Card(
            type: .word,
            german: "Apfel",
            hanzi: "苹果",
            pinyin: "píngguǒ",
            status: .medium
        )
        context.insert(card)
        try context.save()

        let before = (
            card.german, card.hanzi, card.pinyin, card.status,
            card.reviewCount, card.correctCount, card.lastReviewedAt,
            card.hanziWasEditedManually, card.pinyinWasEditedManually
        )

        let service = SpeechSynthesisService()
        // `stop()` in einem `defer`, damit die Suite keine aktive
        // `.playback`-Session zurücklässt — auch dann nicht, wenn eine
        // Erwartung darunter fehlschlägt. Aus dem Review.
        defer { service.stop() }
        service.speak(card.hanzi)

        #expect(card.german == before.0)
        #expect(card.hanzi == before.1)
        #expect(card.pinyin == before.2)
        #expect(card.status == before.3)
        #expect(card.reviewCount == before.4)
        #expect(card.correctCount == before.5)
        #expect(card.lastReviewedAt == before.6)
        // The manual-edit flags too: a tap on the speaker must not make the
        // editor think the user touched a field (A17, A19).
        #expect(card.hanziWasEditedManually == before.7)
        #expect(card.pinyinWasEditedManually == before.8)
        #expect(context.hasChanges == false, "speech saves nothing")
    }

    @Test("Stopping releases the state without waiting for a callback")
    func stopReleasesWithoutCallback() throws {
        // The reason `stop()` exists and why it must not check
        // `synthesizer.isSpeaking`: if an interruption swallows both
        // `didFinish` and `didCancel`, this is the only path that clears
        // `isSpeaking` and gives the audio session back. Found by the
        // review, which also noted the method had no caller at all.
        let service = SpeechSynthesisService()
        // `try #require` statt `guard … else { return }`: Ein `guard` macht
        // den Test auf einer Laufzeit ohne Mandarin-Stimme zu einem leeren
        // Durchlauf, der von einem echten Erfolg nicht zu unterscheiden ist.
        // Aus dem Audit.
        try #require(service.isAvailable, "keine zh-CN-Stimme auf dieser Laufzeit")

        service.speak("你好")
        #expect(service.isSpeaking)
        #expect(service.spokenText == "你好")

        service.stop()
        #expect(service.isSpeaking == false)
        #expect(service.spokenText == nil)
    }

    @Test("Only the button whose text is playing looks active")
    func spokenTextIdentifiesTheButton() throws {
        // `isSpeaking` alone is global: in the card list every visible
        // speaker would fill at once. `spokenText` is what tells them apart.
        let service = SpeechSynthesisService()
        defer { service.stop() }
        #expect(service.spokenText == nil)

        try #require(service.isAvailable, "keine zh-CN-Stimme auf dieser Laufzeit")
        service.speak("  你好  ")
        #expect(service.spokenText == "你好", "trimmed, so the comparison matches the card")
    }

    @Test("Stopping when nothing runs is not an error")
    func stopWhenIdle() {
        let service = SpeechSynthesisService()
        service.stop()
        #expect(service.isSpeaking == false)
        #expect(service.failure == nil)
    }
}
