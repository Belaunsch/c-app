//
//  AccessibilityTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

/// What VoiceOver is told, where that is decided in code rather than in a view.
///
/// Most of accessibility is a device question — whether a label is reachable,
/// whether the reading order makes sense, whether anything is cut off at large
/// type sizes. Those are on the physical checklist. What **is** testable is the
/// content of the labels the app composes itself, and the one thing a reader
/// cannot check by looking: which language a run of text claims to be.
@MainActor
struct AccessibilityTests {

    private func card(hanzi: String = "苹果", pinyin: String = "píngguǒ") -> Card {
        Card(type: .word, german: "Apfel", hanzi: hanzi, pinyin: pinyin)
    }

    @Test("The Hanzi in the answer label is marked as Chinese")
    func hanziCarriesItsLanguage() {
        let label = LearnAnswer.accessibilityAttributedLabel(for: card())

        // The German prefix must stay unmarked, the characters must not.
        // Without the marking VoiceOver reads 苹果 with the German voice,
        // which produces mispronounced syllables or silence.
        let chineseRuns = label.runs.filter { $0.languageIdentifier == "zh-Hans-CN" }
        #expect(chineseRuns.isEmpty == false, "the characters claim no language")

        let chinese = chineseRuns.map { String(label[$0.range].characters) }.joined()
        #expect(chinese == "苹果", "exactly the Hanzi, nothing around it")

        let plain = String(label.characters)
        #expect(plain.hasPrefix("Antwort: "), "and the German stays German")
        #expect(plain.contains("píngguǒ"))
    }

    @Test("The Pinyin is deliberately left unmarked")
    func pinyinIsNotForcedIntoAMandarinVoice() {
        let label = LearnAnswer.accessibilityAttributedLabel(for: card())

        // Asserted first, and not for symmetry: without it the loop below
        // runs zero times as soon as the marking disappears entirely, and the
        // test would pass by having nothing to check. The audit found exactly
        // that shape.
        let marked = label.runs.filter { $0.languageIdentifier == ChineseText.languageIdentifier }
        #expect(marked.count == 1, "one marked run, and it has to exist to be checked")

        for run in marked {
            let text = String(label[run.range].characters)
            #expect(text.contains("píngguǒ") == false,
                    "a Mandarin voice would spell out the tone marks")
        }
    }

    @Test("A card without Pinyin still marks its Hanzi")
    func withoutPinyin() {
        let label = LearnAnswer.accessibilityAttributedLabel(for: card(pinyin: ""))
        #expect(String(label.characters) == "Antwort: 苹果")
        #expect(label.runs.contains { $0.languageIdentifier == "zh-Hans-CN" })
    }

    @Test("The wording is what phase 6 settled on")
    func theSentenceIsUnchanged() {
        // The attributed label replaced the plain one entirely — keeping both
        // left a `String` version with no caller but two tests, which the
        // audit rightly called dead code. What survives is the wording, which
        // is what a listener actually hears.
        #expect(String(LearnAnswer.accessibilityAttributedLabel(for: card()).characters)
            == "Antwort: 苹果, píngguǒ")
        #expect(String(LearnAnswer.accessibilityAttributedLabel(for: card(pinyin: "")).characters)
            == "Antwort: 苹果")
    }

    @Test("Standalone Chinese carries the same language identifier")
    func standaloneChinese() {
        // Used by the card list and by mode B's middle step, where Chinese
        // stands on its own with no German label around it.
        let text = ChineseText.spoken("水果")
        #expect(String(text.characters) == "水果")
        #expect(text.runs.allSatisfy { $0.languageIdentifier == ChineseText.languageIdentifier })
        #expect(ChineseText.languageIdentifier == "zh-Hans-CN")
        // The same locale the recognition validates against, so the app means
        // one thing by "Chinese" everywhere.
        #expect(MandarinRecognitionLocale.requested.identifier.contains("Hans"))
    }
}
