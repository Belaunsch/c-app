//
//  MandarinVoiceSelectionTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// Which voice the app speaks with, as a pure function.
///
/// No `AVSpeechSynthesisVoice` anywhere: the type is awkward to construct for
/// a test and the decision does not need it. The candidates here are made up
/// on purpose — a test that pinned the voices of one device would freeze that
/// device's inventory as if it were the rule, and the measured device carries
/// nine `.default` voices that another one will not have.
struct MandarinVoiceSelectionTests {

    private func candidate(
        _ identifier: String,
        _ language: String = "zh-CN",
        _ quality: VoiceQuality = .default
    ) -> VoiceCandidate {
        VoiceCandidate(identifier: identifier, language: language, quality: quality)
    }

    // MARK: - Quality

    @Test("Premium beats enhanced")
    func premiumBeatsEnhanced() {
        let best = MandarinVoiceSelection.best(from: [
            candidate("a", "zh-CN", .enhanced),
            candidate("b", "zh-CN", .premium),
        ])
        #expect(best?.identifier == "b")
    }

    @Test("Enhanced beats default")
    func enhancedBeatsDefault() {
        let best = MandarinVoiceSelection.best(from: [
            candidate("a", "zh-CN", .default),
            candidate("b", "zh-CN", .enhanced),
        ])
        #expect(best?.identifier == "b")
    }

    @Test("Default is taken when there is nothing better")
    func defaultIsTaken() {
        let best = MandarinVoiceSelection.best(from: [candidate("only")])
        #expect(best?.identifier == "only")
    }

    @Test("A better class wins even over the preferred identifier")
    func qualityOutranksThePreference() {
        // The preference exists to separate voices of the *same* class. If a
        // device ever carries an enhanced or premium Mandarin voice, it wins
        // — and its audible quality is then **not** covered by the phase-7
        // listening test, which is why Q5 says so.
        let best = MandarinVoiceSelection.best(
            from: [candidate("preferred"), candidate("better", "zh-CN", .premium)],
            preferring: ["preferred"]
        )
        #expect(best?.identifier == "better")
    }

    // MARK: - Language

    @Test("Voices of other languages are out", arguments: [
        "en-US", "de-DE", "ja-JP", "ko-KR", "th-TH",
    ])
    func otherLanguagesExcluded(language: String) {
        #expect(MandarinVoiceSelection.best(from: [candidate("x", language)]) == nil)
    }

    @Test("Taiwan and Hong Kong are not Mainland Mandarin", arguments: [
        "zh-TW", "zh-HK", "zh-Hant-TW", "yue-HK",
    ])
    func otherChineseRegionsExcluded(language: String) {
        // The device carries nine `zh-TW` voices. Taiwanese Mandarin reads
        // some characters differently, and Cantonese is another language —
        // picking one of those for a Mainland-Mandarin card would be wrong,
        // not merely imprecise.
        #expect(MandarinVoiceSelection.best(from: [candidate("x", language)]) == nil)
    }

    @Test("A Mainland tag is recognised however it is written", arguments: [
        "zh-CN", "zh-Hans-CN", "zh_CN", "zh-hans-cn",
    ])
    func mainlandSpellings(language: String) {
        // `language` is documented as BCP 47, and the same request has
        // several valid spellings. Comparing strings would miss them, so the
        // tag is parsed.
        #expect(MandarinVoiceSelection.best(from: [candidate("x", language)])?.identifier == "x")
    }

    @Test("A Chinese tag without a region is not assumed to be Mainland")
    func chineseWithoutRegion() {
        // `zh` alone says nothing about the region, and guessing "probably
        // China" is exactly the kind of assumption that gets Taiwanese
        // readings into a Mainland card.
        #expect(MandarinVoiceSelection.best(from: [candidate("x", "zh")]) == nil)
        #expect(MandarinVoiceSelection.best(from: [candidate("x", "zh-Hans")]) == nil)
    }

    // MARK: - The tie inside one class

    @Test("The preferred identifier wins inside the same class")
    func preferredIdentifierWins() {
        // This is the real decision on the measured device: all nine `zh-CN`
        // voices report `.default`, `voiceTraits` is `0` for every one of
        // them, and the documented rule of
        // `AVSpeechSynthesisVoice(language:)` decides nothing among them. So
        // the tie is broken by a listening test, recorded in Q5 — not by a
        // claim of technical superiority.
        let best = MandarinVoiceSelection.best(
            from: [
                candidate("com.apple.eloquence.zh-CN.Eddy"),
                candidate("com.apple.eloquence.zh-CN.Sandy"),
                candidate("com.apple.voice.super-compact.zh-CN.Tingting"),
            ]
        )
        #expect(best?.identifier == "com.apple.voice.super-compact.zh-CN.Tingting")
    }

    @Test("An Eloquence voice is never picked over the preferred one")
    func eloquenceNeverOutranksThePreference() {
        // Alphabetically `com.apple.eloquence...` sorts before
        // `com.apple.voice...`, so a plain sort would pick Eddy. The
        // listening comparison found Sandy clearly worse — robotic, audibly
        // poorer, partly distorted — so a positive preference is expressed
        // instead of a blocklist: it states what was tested rather than
        // guessing about what was not.
        let candidates = (1...8).map { candidate("com.apple.eloquence.zh-CN.\($0)") }
            + [candidate("com.apple.voice.super-compact.zh-CN.Tingting")]
        let best = MandarinVoiceSelection.best(from: candidates)
        #expect(best?.identifier.contains("eloquence") == false)
    }

    @Test("Without the preferred voice the choice is still deterministic")
    func stableWithoutThePreference() {
        // `speechVoices()` has no documented order, so the same device must
        // not answer differently between launches. The fallback is the
        // smallest identifier — arbitrary, but stable and inspectable.
        let voices = [candidate("c"), candidate("a"), candidate("b")]
        #expect(MandarinVoiceSelection.best(from: voices)?.identifier == "a")
        #expect(MandarinVoiceSelection.best(from: voices.reversed())?.identifier == "a")
        #expect(MandarinVoiceSelection.best(from: voices.shuffled())?.identifier == "a")
    }

    @Test("The preference order is honoured, not just membership")
    func preferenceIsOrdered() {
        let best = MandarinVoiceSelection.best(
            from: [candidate("second"), candidate("first")],
            preferring: ["first", "second"]
        )
        #expect(best?.identifier == "first")
    }

    // MARK: - Nothing there

    @Test("No voices at all means unavailable")
    func emptyMeansUnavailable() {
        #expect(MandarinVoiceSelection.best(from: []) == nil)
    }

    @Test("Only foreign voices also means unavailable")
    func onlyForeignMeansUnavailable() {
        let best = MandarinVoiceSelection.best(from: [
            candidate("a", "en-US"), candidate("b", "zh-TW"), candidate("c", "ja-JP"),
        ])
        #expect(best == nil)
    }

    @Test("A refresh can turn unavailable into available")
    func refreshCanBecomeAvailable() {
        // The situation from Q5: the user installs a Mandarin voice in
        // Settings and comes back. The selection has to answer differently
        // for the new list — nothing may be cached from the first `nil`.
        var installed: [VoiceCandidate] = [candidate("en", "en-US")]
        #expect(MandarinVoiceSelection.best(from: installed) == nil)

        installed.append(candidate("com.apple.voice.super-compact.zh-CN.Tingting"))
        #expect(MandarinVoiceSelection.best(from: installed) != nil)
    }

    // MARK: - The quality order itself

    @Test("The quality order is written down, not inherited from Apple")
    func qualityOrder() {
        // `AVSpeechSynthesisVoiceQuality` is not `Comparable` and Apple
        // documents no ordering; the raw values happen to rise with quality,
        // but that is not a contract. So the order lives here.
        #expect(VoiceQuality.default < .enhanced)
        #expect(VoiceQuality.enhanced < .premium)
        #expect(VoiceQuality.allCases.max() == .premium)
    }
}
