//
//  PinyinServiceTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// The expected values were measured against the system's ICU data and then
/// checked against what the Pinyin actually should be — not copied from the
/// implementation's output. Where ICU deviates from conventional Pinyin, that
/// is called out in its own test rather than quietly pinned as "correct".
struct PinyinServiceTests {

    // MARK: - Words

    @Test("A word becomes Pinyin with tone marks")
    func wordGetsToneMarks() {
        #expect(PinyinService.pinyin(for: "苹果") == "píngguǒ")
        #expect(PinyinService.pinyin(for: "水") == "shuǐ")
        #expect(PinyinService.pinyin(for: "茶") == "chá")
    }

    @Test("A multi-syllable word stays one word instead of separate syllables")
    func wordsAreNotSplitIntoSyllables() {
        // This is what the tokenizer buys us over plain transliteration:
        // "píngguǒ", not "píng guǒ".
        #expect(PinyinService.pinyin(for: "火车站") == "huǒchēzhàn")
        #expect(PinyinService.pinyin(for: "机场") == "jīchǎng")
        #expect(PinyinService.pinyin(for: "米饭") == "mǐfàn")
        #expect(PinyinService.pinyin(for: "账单") == "zhàngdān")
    }

    @Test("Polyphonic characters are resolved from their word context")
    func polyphonicCharactersUseWordContext() {
        // 行 reads xíng or háng, 长 cháng or zhǎng. Word segmentation gets
        // these right, which is exactly why it is the primary path.
        #expect(PinyinService.pinyin(for: "银行") == "yínháng")
        #expect(PinyinService.pinyin(for: "行走") == "xíngzǒu")
        #expect(PinyinService.pinyin(for: "长城") == "chángchéng")
        #expect(PinyinService.pinyin(for: "校长") == "xiàozhǎng")
    }

    // MARK: - Sentences

    @Test("A sentence is segmented into words")
    func sentenceIsSegmented() {
        #expect(PinyinService.pinyin(for: "洗手间在哪里？") == "xǐshǒujiān zài nǎlǐ")
        #expect(PinyinService.pinyin(for: "请结账。") == "qǐng jiézhàng")
    }

    @Test("Chinese punctuation does not end up in the Pinyin")
    func punctuationIsDropped() {
        // Measured in phase 3: the tokenizer does return a transcription for
        // "。" — it comes back as "｡" — so it has to be filtered out.
        for sentence in ["我来自德国。", "早上好！", "这个多少钱？"] {
            let result = PinyinService.pinyin(for: sentence)
            #expect(result.contains("。") == false)
            #expect(result.contains("｡") == false)
            #expect(result.contains("？") == false)
            #expect(result.contains("！") == false)
            #expect(result.hasSuffix(" ") == false)
        }
    }

    @Test("Pinyin words are separated by single spaces")
    func wordsAreSingleSpaced() {
        let result = PinyinService.pinyin(for: "我想吃点东西。")
        #expect(result.contains("  ") == false)
        #expect(result.hasPrefix(" ") == false)
        #expect(result.hasSuffix(" ") == false)
        #expect(result.split(separator: " ").count == 5, "我 想 吃 点 东西")
    }

    @Test("Every syllable carries a tone mark")
    func everyWordCarriesAToneMark() {
        // Deliberately stricter than "somewhere in the result": a check for a
        // single tone mark anywhere would still pass if all but one syllable
        // lost theirs — and that does happen, see the known-limit test below.
        for hanzi in ["苹果", "我想吃点东西。", "火车站", "洗手间在哪里？", "请结账。"] {
            let result = PinyinService.pinyin(for: hanzi)
            for word in result.split(separator: " ") {
                #expect(
                    word.contains(where: Self.toneMarks.contains),
                    "\(hanzi) → \(result): word \(word) carries no tone mark"
                )
            }
        }
    }

    private static let toneMarks = Set("āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ")

    // MARK: - Edge cases

    @Test("Empty or blank input yields an empty result")
    func blankInputYieldsNothing() {
        #expect(PinyinService.pinyin(for: "") == "")
        #expect(PinyinService.pinyin(for: "   ") == "")
        #expect(PinyinService.pinyin(for: "\n\t ") == "")
    }

    @Test("Surrounding whitespace is ignored")
    func surroundingWhitespaceIsIgnored() {
        #expect(PinyinService.pinyin(for: "  苹果  ") == "píngguǒ")
    }

    @Test("Punctuation-only input yields nothing")
    func punctuationOnlyInputYieldsNothing() {
        // Stopped by the Han check now. Before it existed these reached the
        // `CFStringTransform` fallback, and "。" came back as "." — which
        // contradicted the promise that punctuation never ends up in Pinyin.
        // Both guards stay: the fallback is still reachable for rare Han
        // characters, see `rareIdeographUsesTheFallbackPath`.
        #expect(PinyinService.pinyin(for: "。") == "")
        #expect(PinyinService.pinyin(for: "。。。") == "")
        #expect(PinyinService.pinyin(for: "？！") == "")
        #expect(PinyinService.pinyin(for: "、") == "")
        // The iteration mark is Han script, but not an ideograph, so the
        // source check already rejects it. Its transcription would be "⓶"
        // anyway — measured.
        #expect(PinyinService.pinyin(for: "々") == "")
    }

    // MARK: - Input that is not Chinese

    @Test("Input without Han characters yields nothing")
    func inputWithoutHanYieldsNothing() {
        // Measured on the device in phase 4, and the reason the Han check
        // exists: ICU transliterates what it recognises and hands the rest
        // back, so "asdf" typed into the Hanzi field arrived in the Pinyin
        // field as "asdf". Neither path recognises "this is not Chinese".
        #expect(PinyinService.pinyin(for: "asdf") == "")
        #expect(PinyinService.pinyin(for: "Apfel") == "")
        #expect(PinyinService.pinyin(for: "123") == "")
        #expect(PinyinService.pinyin(for: "🙂🎉") == "")
        // Kana and Hangul are not Han script.
        #expect(PinyinService.pinyin(for: "ひらがな") == "")
        #expect(PinyinService.pinyin(for: "한국어") == "")
    }

    @Test("Han script is recognised across scripts and extensions")
    func hanScriptDetection() {
        #expect(PinyinService.containsHanScript("苹果"))
        #expect(PinyinService.containsHanScript("我想吃东西"))
        #expect(PinyinService.containsHanScript("水"))
        // Kanji are Han characters and do have a Mandarin reading.
        #expect(PinyinService.containsHanScript("漢字"))
        // CJK extension A and B, and the ideographic zero.
        #expect(PinyinService.containsHanScript("\u{3400}"))
        #expect(PinyinService.containsHanScript("\u{20000}"))
        #expect(PinyinService.containsHanScript("〇"))
        // One Han character in mixed input is enough.
        #expect(PinyinService.containsHanScript("苹果 asdf"))

        #expect(PinyinService.containsHanScript("asdf") == false)
        #expect(PinyinService.containsHanScript("123") == false)
        #expect(PinyinService.containsHanScript("。？！、") == false)
        #expect(PinyinService.containsHanScript("🙂") == false)
        #expect(PinyinService.containsHanScript("ひらがな") == false)
        #expect(PinyinService.containsHanScript("한국어") == false)
        #expect(PinyinService.containsHanScript("Привет") == false)
        #expect(PinyinService.containsHanScript("") == false)
        #expect(PinyinService.containsHanScript("   ") == false)
    }

    @Test("Mixed input is transliterated as a whole")
    func mixedInputIsTransliteratedAsAWhole() {
        // Deliberately defined rather than forbidden: one Han character is
        // enough to generate, and the whole string is then transliterated.
        // Latin letters and digits come back unchanged.
        #expect(PinyinService.pinyin(for: "苹果 asdf") == "píngguǒ asdf")
        #expect(PinyinService.pinyin(for: "A苹果1") == "A píngguǒ 1")
        #expect(PinyinService.pinyin(for: "苹果 123") == "píngguǒ 123")

        // Other scripts are *not* passed through — ICU romanises them too.
        // Measured, and worth pinning: it is the kind of output that looks
        // like a bug when you meet it for the first time, and it is exactly
        // why the field stays editable.
        #expect(PinyinService.pinyin(for: "хорошо苹果") == "horošo píngguǒ")
        #expect(PinyinService.pinyin(for: "苹果ひらがな") == "píngguǒ hi ra ga na")
    }

    @Test("An ideograph ICU cannot transcribe yields nothing, not itself")
    func untranscribableIdeographYieldsNothing() {
        // This pins the *second* guard. The Han check alone does not catch
        // these: U+2A700 (CJK extension C), U+17000 (Tangut) and U+1B170
        // (Nüshu) all carry the Ideographic property, and ICU hands them
        // straight back instead of transcribing them. Measured — without the
        // plausibility check the Hanzi field's own content would appear in
        // the Pinyin field.
        #expect(PinyinService.containsHanScript("\u{2A700}"))
        #expect(PinyinService.pinyin(for: "\u{2A700}") == "")
        #expect(PinyinService.pinyin(for: "\u{17000}") == "")
        #expect(PinyinService.pinyin(for: "\u{1B170}") == "")
    }

    @Test("A rare ideograph falls through to the transliteration path")
    func rareIdeographUsesTheFallbackPath() {
        // U+20000, the first character of CJK extension B: the tokenizer
        // returns no transcription for it, so this is the one case in these
        // tests that proves path 2 is reachable with valid Chinese input —
        // not just with punctuation.
        #expect(PinyinService.pinyin(for: "\u{20000}") == "hē")
    }

    // MARK: - Known ICU limits

    @Test("Known limit: the neutral tone is rendered as a full tone")
    func neutralToneIsRenderedAsFullTone() {
        // Conventional Pinyin writes "xièxie" and "dōngxi" — the second
        // syllable is neutral. ICU gives it a full tone. Not a defect in this
        // service, and the reason the field stays editable. Should ICU ever
        // improve, this test tells us.
        #expect(PinyinService.pinyin(for: "谢谢") == "xièxiè")
        #expect(PinyinService.pinyin(for: "东西") == "dōngxī")
    }

    @Test("Known limit: the reading of 不 and 一 is unreliable")
    func readingOfBuAndYiIsUnreliable() {
        // ICU does **not** implement tone sandhi — it simply picks the reading
        // inconsistently. Measured in phase 3:
        //   不是   → bú shì    sandhi is correct here, and applied
        //   不明白 → bú míngbái  no sandhi applies (明 is 2nd tone) — wrong
        //   不对   → bùduì     sandhi should apply (对 is 4th tone) — not applied
        //   一点   → yīdiǎn    should be yìdiǎn — not applied
        // So the deviation goes in both directions. Another reason the field
        // stays editable.
        #expect(PinyinService.pinyin(for: "我不明白。").hasPrefix("wǒ bú"))
        #expect(PinyinService.pinyin(for: "不对") == "bùduì")
        #expect(PinyinService.pinyin(for: "一点") == "yīdiǎn")
    }

    @Test("Known limit: the neutral tone in 东西 — neither path delivers it")
    func neutralToneOfDongxiIsNotDelivered() {
        // Found on the device in phase 4 with the sentence "Ich möchte etwas
        // essen." → 我想吃点东西. In the sense "thing" the standard reading is
        // "dōngxi" with a neutral second syllable; ICU gives "dōngxī".
        //
        // Measured separately for both paths, so this is not a tokenizer
        // quirk that path 2 would fix:
        //   tokenizer: 东西 → dōngxī        我想吃点东西 → wǒ xiǎng chī diǎn dōngxī
        //   fallback : 东西 → dōng xī       我想吃点东西 → wǒ xiǎng chī diǎn dōng xī
        // The fallback is worse: full tone *and* split syllables.
        //
        // The value below is pinned as **what ICU does**, not as correct
        // Pinyin. Nothing Apple-native produces "dōngxi", because the reading
        // depends on the word sense: in 东西南北 ("east and west") the full
        // tone is right, and ICU renders both the same way. Fixing it would
        // take a dictionary of our own — out of scope here, and the reason the
        // Pinyin field stays editable.
        #expect(PinyinService.pinyin(for: "东西") == "dōngxī")
        #expect(PinyinService.pinyin(for: "我想吃点东西。") == "wǒ xiǎng chī diǎn dōngxī")
        #expect(PinyinService.pinyin(for: "东西南北") == "dōngxī nánběi")
    }

    @Test("Known limit: single syllables can lose their tone mark")
    func someSyllablesLoseTheirToneMark() {
        // 钱 is qián. ICU drops the mark entirely — the one deviation that is
        // not about the neutral tone.
        #expect(PinyinService.pinyin(for: "钱") == "qian")
        #expect(PinyinService.pinyin(for: "这个多少钱？") == "zhègè duōshǎo qian")
    }
}
