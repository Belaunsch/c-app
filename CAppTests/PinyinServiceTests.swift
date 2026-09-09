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
@MainActor
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
        // Proper noun in the lexicon, so it keeps its capital — conventional
        // Pinyin capitalises the Great Wall.
        #expect(PinyinService.pinyin(for: "长城") == "Chángchéng")
        #expect(PinyinService.pinyin(for: "校长") == "xiàozhǎng")
    }

    // MARK: - Sentences

    @Test("A sentence is segmented into words")
    func sentenceIsSegmented() {
        // Third-tone sandhi applies inside `洗手间` and inside `哪里`, and
        // deliberately not between `在` and `哪里` (A28).
        #expect(PinyinService.pinyin(for: "洗手间在哪里？") == "xíshǒujiān zài nálǐ")
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

        // Latin and digits come back unchanged, so nothing was guessed.
        #expect(PinyinService.resolution(for: "苹果 asdf").needsReview == false)

        // Other scripts are *not* passed through — ICU romanises them too.
        // Measured, and worth pinning: it is the kind of output that looks
        // like a bug when you meet it for the first time. Since ICU is
        // guessing at a script nobody asked it about, the result is flagged.
        #expect(PinyinService.pinyin(for: "хорошо苹果") == "horošo píngguǒ")
        #expect(PinyinService.resolution(for: "хорошо苹果").needsReview)
        #expect(PinyinService.pinyin(for: "苹果ひらがな") == "píngguǒ hi ra ga na")
        #expect(PinyinService.resolution(for: "苹果ひらがな").needsReview)
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

    // MARK: - What the lexicon fixed

    @Test("The neutral tone now comes from the lexicon")
    func neutralToneComesFromTheLexicon() {
        // Phase 3 had to pin the wrong values here, because ICU has no
        // neutral tone at all: "xièxiè" instead of "xièxie", "zǎoshàng"
        // instead of "zǎoshang". CC-CEDICT writes tone 5 for exactly this,
        // and these are now the linguistically correct values.
        #expect(PinyinService.pinyin(for: "谢谢") == "xièxie")
        #expect(PinyinService.pinyin(for: "早上") == "zǎoshang")
        #expect(PinyinService.pinyin(for: "明白") == "míngbai")
        #expect(PinyinService.resolution(for: "谢谢").source == .lexicon)
        #expect(PinyinService.resolution(for: "谢谢").needsReview == false)
    }

    @Test("A lone syllable keeps its tone mark now")
    func loneSyllableKeepsItsToneMark() {
        // 钱 is qián. ICU dropped the mark entirely — phase 3 had to pin
        // "qian". The lexicon has two entries, `Qian2` for the surname and
        // `qian2` for money; they agree on the reading, so it is unambiguous
        // and the common-noun spelling wins.
        #expect(PinyinService.pinyin(for: "钱") == "qián")
        #expect(PinyinService.pinyin(for: "这个多少钱？").hasSuffix("qián"))
    }

    @Test("Context resolves a word that is ambiguous on its own")
    func contextResolvesAmbiguity() {
        // 东西 has two readings: dōngxi (thing) and dōngxī (east and west).
        // Alone it cannot be decided — see `ambiguousWordIsFlagged`. Inside a
        // phrase the lexicon knows, it can, and this needs no rule of our
        // own: the longest known phrase wins.
        #expect(PinyinService.pinyin(for: "买东西") == "mǎi dōngxi")
        #expect(PinyinService.resolution(for: "买东西").needsReview == false)

        #expect(PinyinService.pinyin(for: "东西南北") == "dōngxī nánběi")
        #expect(PinyinService.resolution(for: "东西南北").needsReview == false)

        // 好 alone is ambiguous (hǎo/hào), 早上好 is not.
        #expect(PinyinService.pinyin(for: "早上好") == "zǎoshang hǎo")
        #expect(PinyinService.resolution(for: "早上好").needsReview == false)
    }

    @Test("Word boundaries come from the segmentation, not from the lexicon")
    func spacingFollowsWordBoundaries() {
        // CC-CEDICT separates every syllable and marks no word boundaries:
        // 早上好 is `zao3 shang5 hao3` exactly like 火车站 is
        // `huo3 che1 zhan4`. Joining everything would give "zǎoshanghǎo", so
        // the syllables are split back over the tokenizer's words — which is
        // only sound because a Han headword has exactly one syllable per
        // character, verified across all 124.202 such entries.
        #expect(PinyinService.pinyin(for: "火车站") == "huǒchēzhàn", "one word stays one word")
        #expect(PinyinService.pinyin(for: "早上好") == "zǎoshang hǎo", "two words stay two")
    }

    @Test("Segmentation is not a greedy character match")
    func segmentationUsesWordBoundaries() {
        // A purely character-based longest match reads 我不明白 as
        // 我 + 不明 + 白 — both are real headwords — and produces
        // "wǒ bùmíng bái". Cutting only at the tokenizer's boundaries gives
        // 我 + 不 + 明白 and the correct "wǒ bù míngbai".
        #expect(PinyinService.pinyin(for: "我不明白") == "wǒ bù míngbai")
        #expect(PinyinService.resolution(for: "我不明白").needsReview == false)
    }

    @Test("A compound the lexicon has no headword for is built from its parts")
    func unknownCompoundIsDecomposed() {
        // ICU returns these as one token, and CC-CEDICT has no headword for
        // them, but every part is in there with a single reading. Asking ICU
        // for the whole token would put a review hint on a card where
        // nothing is uncertain.
        // `水果` carries two third tones, so the spoken form has the first
        // as a second — the rule reaches inside a decomposed part because
        // that part is one lexicon headword and therefore one domain.
        for (hanzi, expected) in [("啤酒杯", "píjiǔbēi"), ("水果店", "shuíguǒdiàn"), ("苹果树", "píngguǒshù")] {
            let resolution = PinyinService.resolution(for: hanzi)
            #expect(resolution.text == expected)
            #expect(resolution.source == .lexicon, "\(hanzi) is built from known words")
            #expect(resolution.needsReview == false)
        }
    }

    @Test("Decomposition stops at a word with several readings")
    func decompositionRefusesToSplitAnAmbiguousWord() {
        // 东西风 is not a headword, while 东, 西 and 风 each have exactly one
        // reading — so a character-by-character split would succeed and
        // produce a confident "dōngxīfēng". But 东西 is precisely the word
        // that cannot be settled without context, and cutting it in half
        // would be a silent guess. (东西方 by contrast *is* a headword,
        // `dong1 xi1 fang1`, and resolves without any of this.)
        #expect(PinyinService.resolution(for: "东西风").needsReview, "no reading may be claimed here")
        #expect(PinyinService.resolution(for: "东西方").needsReview == false, "a real headword")
    }

    @Test("A malformed lexicon reading never reaches the field")
    func malformedReadingIsRejected() {
        // 13 entries write two syllables without the separating space — the
        // metric-unit characters, 兙 reads `shi2ke4`. `PinyinTone` hands back
        // what it cannot parse, so without a check the digits would show up
        // in the Pinyin field as a certain reading.
        for hanzi in ["兙", "瓩", "粨"] {
            let resolution = PinyinService.resolution(for: hanzi)
            #expect(resolution.text.contains(where: \.isNumber) == false, "no digits in Pinyin")
            #expect(resolution.source != .lexicon, "and not sold as a lexicon reading")
        }
    }

    // MARK: - Where it still has to guess

    @Test("An ambiguous word is flagged instead of guessed")
    func ambiguousWordIsFlagged() {
        // Measured: 1250 of 121.189 headwords (1,03 %) really have several
        // readings. Without context there is nothing to decide it with, so
        // the value falls back to ICU and says so. The German side of the
        // card would often settle it, but CC-CEDICT's glosses are English and
        // there is no dependable offline bridge — see architecture.md A24.
        let resolution = PinyinService.resolution(for: "东西")
        #expect(resolution.text == "dōngxī", "ICU's reading, pinned as measured behaviour")
        #expect(resolution.source == .icuFallback)
        #expect(resolution.needsReview)
    }

    @Test("A sentence with one unresolved word is flagged as a whole")
    func partlyResolvedSentenceIsFlagged() {
        // From the device test: "Ich möchte etwas essen." → 我想吃点东西.
        // 我, 想, 吃 and 点 all come from the lexicon. 东西 does not, and the
        // decisive reason is that it is **ambiguous**, not merely absent: no
        // phrase over the surrounding tokens is a headword (the candidates
        // from 吃 are 吃点东西, 吃点, 吃 and from 点 they are 点东西, 点), and
        // because 东西 has two readings the decomposition refuses to split it
        // into 东 + 西 either. One guess is enough to ask the user to look.
        let resolution = PinyinService.resolution(for: "我想吃点东西")
        #expect(resolution.text == "wǒ xiǎng chī diǎn dōngxī", "ICU's reading for 东西, pinned as measured behaviour")
        #expect(resolution.source == .mixed)
        #expect(resolution.needsReview)

        // Same with the full stop, which is dropped rather than transcribed.
        #expect(PinyinService.pinyin(for: "我想吃点东西。") == "wǒ xiǎng chī diǎn dōngxī")
    }

    @Test("A fully resolved result is not flagged")
    func resolvedResultIsNotFlagged() {
        for hanzi in ["苹果", "火车站", "洗手间在哪里？", "我来自德国。", "请结账。"] {
            let resolution = PinyinService.resolution(for: hanzi)
            #expect(resolution.source == .lexicon, "\(hanzi) should come entirely from the lexicon")
            #expect(resolution.needsReview == false)
        }
    }

    @Test("Nothing to resolve is not something to review")
    func emptyResultIsNotFlagged() {
        for input in ["", "   ", "asdf", "123", "。"] {
            let resolution = PinyinService.resolution(for: input)
            #expect(resolution.text.isEmpty)
            #expect(resolution.source == .empty)
            #expect(resolution.needsReview == false, "an empty field is not a wrong reading")
        }
    }

    @Test("Tone sandhi is applied now, and the lexical reading stays reachable")
    func sandhiIsApplied() {
        // This test used to pin the opposite. Until phase 6.5 the app showed
        // the dictionary tones — correct as written Pinyin, and not what a
        // learner says. GB/T 16159-2012 §6.5.2 marks `一` and `不` with their
        // original tone in general text and adds
        // „在语言教学等方面，可根据需要按变调标写"; this is language teaching,
        // so the spoken form is shown (A29).
        #expect(PinyinService.pinyin(for: "不对") == "búduì")
        #expect(PinyinService.pinyin(for: "一点") == "yìdiǎn")
        #expect(PinyinService.pinyin(for: "你好") == "níhǎo")
        #expect(PinyinService.pinyin(for: "展览馆") == "zhánlánguǎn")

        // Unchanged: the readings are the dictionary's, the neutral tone is
        // lexical, and `我不明白` is `不`+`明白` rather than `不明`+`白`.
        #expect(PinyinService.pinyin(for: "我不明白。") == "wǒ bù míngbai")
        #expect(PinyinService.pinyin(for: "对不起") == "duìbuqǐ", "lexical bu5 is untouched")

        // A rule fired, and it says which class — no percentages.
        #expect(PinyinService.resolution(for: "不对").transformations == [.bu])
        #expect(PinyinService.resolution(for: "一点").transformations == [.yi])
        #expect(PinyinService.resolution(for: "你好").transformations == [.thirdTone])
        #expect(PinyinService.resolution(for: "苹果").transformations.isEmpty)
        #expect(PinyinService.resolution(for: "你好").showsSpokenTones)
        #expect(PinyinService.resolution(for: "苹果").showsSpokenTones == false)

        // And all of it is still a lexicon result, not a guess: a tone rule
        // never makes a reading uncertain.
        for hanzi in ["我不明白。", "不对", "一点", "你好", "展览馆"] {
            #expect(PinyinService.resolution(for: hanzi).source == .lexicon)
            #expect(PinyinService.resolution(for: hanzi).needsReview == false)
        }
    }

    @Test("一 is triggered by the tone under a reduction, not by the reduction")
    func yiReadsTheBaseToneOfAReducedNeighbour() {
        // `一个` is `yi1 ge5` in the data and is spoken `yíge`, because the
        // rule is triggered by what `个` is underlyingly — a fourth tone.
        // This pins the **wiring**: the resolver has to ask the lexicon for
        // that base tone and put it on the syllable. The rule itself is
        // covered synthetically in `ToneSandhiTests`, and without this test
        // the wiring would only be measured by the corpus.
        //
        // The accuracy pass of phase 6.5 listed this as its highest-priority
        // error; before the fix the field showed `yīge`.
        #expect(PinyinService.pinyin(for: "一个") == "yí ge")
        #expect(PinyinService.pinyin(for: "我有一个问题") == "wǒ yǒu yí ge wèntí")
        #expect(PinyinService.resolution(for: "一个").transformations == [.yi])

        // Where `个` already carries the full tone, nothing changes.
        #expect(PinyinService.pinyin(for: "一个人") == "yí gè rén")

        // And no reduction is turned back into a full tone anywhere.
        for (hanzi, expected) in [("谢谢", "xièxie"), ("朋友", "péngyou"),
                                  ("对不起", "duìbuqǐ"), ("孩子", "háizi"),
                                  ("明白", "míngbai"), ("妈妈", "māma")] {
            #expect(PinyinService.pinyin(for: hanzi) == expected, "\(hanzi)")
        }
    }

    @Test("A guess is never healed by a tone rule")
    func sandhiDoesNotHealAGuess() {
        // `东西` has two readings, so it falls back to ICU and stays flagged.
        // No rule may turn that into something that looks settled.
        let resolution = PinyinService.resolution(for: "东西")
        #expect(resolution.source == .icuFallback)
        #expect(resolution.needsReview)
        #expect(resolution.transformations.isEmpty, "nothing to apply a rule to")
    }

    @Test("Known limit: an ambiguous word inside a sentence still guesses")
    func ambiguousWordInsideASentenceGuesses() {
        // 多少 has two readings, so that one word falls back to ICU while the
        // rest is resolved: 这个 and 钱 are lexicon readings, only `duōshǎo`
        // is ICU's guess and pinned as measured behaviour.
        let resolution = PinyinService.resolution(for: "这个多少钱？")
        #expect(resolution.text == "zhège duōshǎo qián")
        #expect(resolution.source == .mixed, "part lexicon, part guess")
        #expect(resolution.needsReview)
    }
}
