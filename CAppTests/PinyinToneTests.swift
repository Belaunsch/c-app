//
//  PinyinToneTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// The tone-number to tone-mark conversion. Pure input and output, so the
/// expected values here are the linguistically correct ones — not measured
/// behaviour like in `PinyinServiceTests`.
struct PinyinToneTests {

    // MARK: - The four tones and the neutral one

    @Test("Each tone lands on the right vowel")
    func tonesAreApplied() {
        #expect(PinyinTone.marked(syllable: "ma1") == "mā")
        #expect(PinyinTone.marked(syllable: "ma2") == "má")
        #expect(PinyinTone.marked(syllable: "ma3") == "mǎ")
        #expect(PinyinTone.marked(syllable: "ma4") == "mà")
    }

    @Test("The neutral tone carries no mark at all")
    func neutralToneHasNoMark() {
        // The reason this whole file exists: CC-CEDICT writes tone 5 for the
        // neutral tone, and ICU has no concept of it. `xie4 xie5` is the
        // difference between "xièxie" and the wrong "xièxiè".
        #expect(PinyinTone.marked(syllable: "xie5") == "xie")
        #expect(PinyinTone.marked(syllable: "shang5") == "shang")
        #expect(PinyinTone.marked(syllable: "de5") == "de")
        #expect(PinyinTone.marked("xie4 xie5") == "xièxie")
        #expect(PinyinTone.marked("zao3 shang5") == "zǎoshang")
        #expect(PinyinTone.marked("dong1 xi5") == "dōngxi")
    }

    // MARK: - Placement

    @Test("With a, o or e present, that vowel takes the mark")
    func aOrOOrETakesTheMark() {
        #expect(PinyinTone.marked(syllable: "hao3") == "hǎo")
        #expect(PinyinTone.marked(syllable: "guo3") == "guǒ")
        #expect(PinyinTone.marked(syllable: "xie4") == "xiè")
        #expect(PinyinTone.marked(syllable: "jiao1") == "jiāo")
        #expect(PinyinTone.marked(syllable: "zhuang4") == "zhuàng")
        #expect(PinyinTone.marked(syllable: "lve4") == "lvè", "no ü in the input, e still wins")
    }

    @Test("In iu the u takes the mark, in ui the i")
    func vowelPairsFollowTheStandardRule() {
        #expect(PinyinTone.marked(syllable: "liu2") == "liú")
        #expect(PinyinTone.marked(syllable: "jiu3") == "jiǔ")
        #expect(PinyinTone.marked(syllable: "gui1") == "guī")
        #expect(PinyinTone.marked(syllable: "shui3") == "shuǐ")
    }

    @Test("A single vowel takes the mark wherever it sits")
    func singleVowelTakesTheMark() {
        #expect(PinyinTone.marked(syllable: "shi4") == "shì")
        #expect(PinyinTone.marked(syllable: "wu3") == "wǔ")
        #expect(PinyinTone.marked(syllable: "ni3") == "nǐ")
    }

    @Test("A syllable with no vowel loses the tone rather than showing a digit")
    func vowellessSyllableDropsItsTone() {
        // Measured: these are real entries — 嗯 reads `ng2`/`ng4`, 呣 `m2`.
        // There is no vowel to put a mark on, so the tone is lost. That is a
        // real loss of information, and still better than leaking a digit
        // into the Pinyin field.
        #expect(PinyinTone.marked(syllable: "ng4") == "ng")
        #expect(PinyinTone.marked(syllable: "n2") == "n")
        #expect(PinyinTone.marked(syllable: "m2") == "m")
    }

    // MARK: - ü

    @Test("The u: notation becomes ü and can carry a tone")
    func uColonBecomesUmlautU() {
        // 1218 entries in the snapshot use this notation.
        #expect(PinyinTone.marked(syllable: "nu:3") == "nǚ")
        #expect(PinyinTone.marked(syllable: "lu:4") == "lǜ")
        #expect(PinyinTone.marked(syllable: "nu:e4") == "nüè", "e outranks ü")
        #expect(PinyinTone.marked("nu:3 hai2") == "nǚhái")
    }

    // MARK: - Case

    @Test("Capitalised readings stay capitalised")
    func capitalisationSurvives() {
        // CC-CEDICT capitalises proper nouns, and Pinyin keeps that.
        #expect(PinyinTone.marked("Bei3 jing1") == "Běijīng")
        #expect(PinyinTone.marked(syllable: "E4") == "È")
        #expect(PinyinTone.marked(syllable: "Ou1") == "Ōu")
    }

    // MARK: - Input the data really contains

    @Test("Syllables are joined into one word")
    func syllablesAreJoined() {
        // CC-CEDICT separates every syllable, Pinyin does not.
        #expect(PinyinTone.marked("ping2 guo3") == "píngguǒ")
        #expect(PinyinTone.marked("huo3 che1 zhan4") == "huǒchēzhàn")
    }

    @Test("Punctuation inside a reading is kept, not mangled")
    func punctuationIsKept() {
        // Measured in the snapshot: 455 readings contain a comma and 160 the
        // middle dot, both in names and enumerations.
        #expect(PinyinTone.marked("Ma3 ke4 · Tu1 wen1") == "Mǎkè·Tūwēn")
        #expect(PinyinTone.marked("yi1 , er4") == "yī, èr")
    }

    @Test("Anything that is not a syllable is handed back unchanged")
    func nonSyllablesArePassedThrough() {
        // `11区` has the reading `11 Qu1`, and a handful of entries are
        // malformed. Mangling them would be worse than passing them through.
        #expect(PinyinTone.marked("11 Qu1") == "11Qū")
        #expect(PinyinTone.marked(syllable: "11") == "11")
        #expect(PinyinTone.marked(syllable: "shi2ke4") == "shi2ke4")
        #expect(PinyinTone.marked(syllable: "") == "")
        #expect(PinyinTone.marked("") == "")
    }

    @Test("A syllable without a tone digit is left alone")
    func toneLessSyllableIsUnchanged() {
        #expect(PinyinTone.marked(syllable: "ma") == "ma")
        #expect(PinyinTone.marked(syllable: "hao") == "hao")
    }
}
