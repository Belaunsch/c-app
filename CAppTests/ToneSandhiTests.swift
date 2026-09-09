//
//  ToneSandhiTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// `ToneSandhi` as a pure function: syllables in, syllables out.
///
/// No lexicon, no ICU, no simulator-dependent behaviour, so every rule can be
/// stated as an input and an expected output. The cases here are the ones the
/// phase named, plus the boundaries that make the rules safe.
struct ToneSandhiTests {

    // MARK: - Building syllables by hand

    /// One toned syllable. `unit` is the sandhi domain — syllables sharing it
    /// came from one lexicon headword.
    /// One toned syllable. `unit` is the word, `foot` the constituent inside
    /// it — by default the same, which is the case where the bracketing is
    /// not decidable.
    /// One toned syllable. `unit` is the word, `foot` the constituent inside
    /// it — by default the same, which is the case where the bracketing is
    /// not decidable. `underlying` is the tone this syllable *triggers* a
    /// neighbouring rule with; it differs from `tone` only for a reduced
    /// syllable, and then it is the tone the lexicon census establishes.
    private func syllable(
        _ hanzi: Character,
        _ letters: String,
        _ tone: Int,
        underlying: Int? = nil,
        unit: Int = 0,
        foot: Int? = nil,
        startsWord: Bool = false
    ) -> PinyinSyllable {
        PinyinSyllable(
            hanzi: hanzi,
            letters: letters,
            lexicalTone: tone,
            tone: tone,
            underlyingTone: underlying ?? tone,
            unit: unit,
            foot: foot ?? unit,
            startsWord: startsWord
        )
    }

    /// The tones after the rules ran.
    private func tones(_ syllables: [PinyinSyllable]) -> [Int?] {
        ToneSandhi.applied(to: syllables).syllables.map(\.tone)
    }

    private func text(_ syllables: [PinyinSyllable]) -> String {
        PinyinSyllable.rendered(ToneSandhi.applied(to: syllables).syllables)
    }

    private func transformations(_ syllables: [PinyinSyllable]) -> Set<PinyinResolution.Transformation> {
        ToneSandhi.applied(to: syllables).transformations
    }

    // MARK: - Third tone

    @Test("Two third tones: the first is spoken as a second")
    func thirdBeforeThird() {
        // 你好 — BLCU 现代汉语: 两个上声前后行，前头那个变阳平
        let syllables = [syllable("你", "ni", 3, startsWord: true), syllable("好", "hao", 3)]
        #expect(tones(syllables) == [2, 3])
        #expect(text(syllables) == "níhǎo")
        #expect(transformations(syllables) == [.thirdTone])
    }

    @Test("Three third tones, left-bracketing: the first two are spoken as seconds")
    func threeThirdTonesLeftBracketing() {
        // 展览馆 = [[展览]馆], 双单格 → 2-2-3. Two cycles: the inner foot
        // [展览] makes 展 a second tone and leaves 览 alone, then the outer
        // cycle sees 览 still carrying a third tone before 馆 and changes it
        // too. Source: 北京语言大学, 现代汉语 — 三个上声 双单格, 前两个音节变阳平.
        let syllables = [
            syllable("展", "zhan", 3, foot: 0, startsWord: true),
            syllable("览", "lan", 3, foot: 0),
            syllable("馆", "guan", 3, foot: 1),
        ]
        #expect(tones(syllables) == [2, 2, 3])
        #expect(text(syllables) == "zhánlánguǎn")
    }

    @Test("Three third tones, right-bracketing: only the middle one changes")
    func threeThirdTonesRightBracketing() {
        // 小老鼠 = [小[老鼠]], 单双格 → 3-2-3. Same three third tones as
        // 展览馆, opposite result, and the bracketing is the whole difference:
        // the inner foot [老鼠] makes 老 a second tone, so the outer cycle
        // finds a second tone and leaves 小 alone. Applying the rule
        // uniformly from the left would give `xiáoláoshǔ`, which is neither
        // the dictionary form nor a form the sources give. Found by the
        // review; the first implementation did exactly that.
        let syllables = [
            syllable("小", "xiao", 3, foot: 0, startsWord: true),
            syllable("老", "lao", 3, foot: 1),
            syllable("鼠", "shu", 3, foot: 1),
        ]
        #expect(tones(syllables) == [3, 2, 3])
        #expect(text(syllables) == "xiǎoláoshǔ")
    }

    @Test("Four third tones in two halves: 2-3-2-3")
    func fourThirdTones() {
        // 养老保险 = [[养老][保险]], 双双格. Inside each half the pair rule
        // applies; across the boundary it does not, because the first
        // syllable of the second half has already become a second tone.
        let syllables = [
            syllable("养", "yang", 3, foot: 0, startsWord: true),
            syllable("老", "lao", 3, foot: 0),
            syllable("保", "bao", 3, foot: 1, startsWord: true),
            syllable("险", "xian", 3, foot: 1),
        ]
        #expect(tones(syllables) == [2, 3, 2, 3])
        #expect(text(syllables) == "yánglǎo báoxiǎn")
    }

    @Test("An undecidable bracketing is not a licence to apply everything")
    func undecidableBracketing() {
        // Where no sub-headword witnesses the structure, `PinyinService`
        // splits down the middle, so a three-syllable word arrives as
        // [A[BC]]. That is the conservative outcome: correct for a
        // right-bracketing word, and for a left-bracketing one it merely
        // leaves the leading syllable at its dictionary tone. What it never
        // produces is a third value no source supports.
        let syllables = [
            syllable("小", "xiao", 3, foot: 0, startsWord: true),
            syllable("雨", "yu", 3, foot: 1),
            syllable("伞", "san", 3, foot: 1),
        ]
        #expect(tones(syllables) == [3, 2, 3])
    }

    @Test("A third tone that ends the word is left alone")
    func trailingThirdTone() {
        let syllables = [syllable("很", "hen", 3, startsWord: true)]
        #expect(tones(syllables) == [3])
        #expect(transformations(syllables).isEmpty)
    }

    @Test("A third tone before a first, second or fourth is left alone", arguments: [1, 2, 4])
    func thirdBeforeOther(next: Int) {
        let syllables = [syllable("小", "xiao", 3, startsWord: true), syllable("说", "shuo", next)]
        #expect(tones(syllables) == [3, next])
    }

    @Test("No third-tone change across a word boundary")
    func noCrossWordThirdTone() {
        // Two units, so two lexical words: `我` and `很好`. Whether they form
        // one prosodic domain depends on grouping, focus and tempo — Duanmu
        // has the rule optional between cyclic branches — so the app does not
        // decide it. `我` keeps its third tone (A28).
        let syllables = [
            syllable("我", "wo", 3, unit: 0, startsWord: true),
            syllable("很", "hen", 3, unit: 1, startsWord: true),
            syllable("好", "hao", 3, unit: 1),
        ]
        #expect(tones(syllables) == [3, 2, 3])
        // One space, not two: `很好` is one unit and therefore one word, so
        // its two syllables render together.
        #expect(text(syllables) == "wǒ hénhǎo")
    }

    @Test("A third tone before a neutral tone is left alone")
    func thirdBeforeNeutral() {
        // 姐姐 is `jie3 jie5`. Genuinely variable: BLCU gives both
        // `214+轻声→35` (打扫, 想想) and `214+轻声→21` (李子, 姐姐), and the
        // data says nothing about which applies. Not guessing is the point.
        // The reduced `姐` arrives with `underlyingTone: 3`, which is what
        // the lexicon actually answers for `姐/jie`. That matters: with the
        // helper's default the syllable would carry an underlying 5, a value
        // the lexicon can never produce, and the mutation "third-tone rule
        // reads the base tone" would leave this test green — the very
        // abstention it documents. Found by the audit.
        let syllables = [
            syllable("姐", "jie", 3, startsWord: true),
            syllable("姐", "jie", 5, underlying: 3),
        ]
        #expect(tones(syllables) == [3, 5])
        #expect(text(syllables) == "jiějie")
        #expect(transformations(syllables).isEmpty)
    }

    // MARK: - 一

    @Test("一 before a fourth tone is spoken yí")
    func yiBeforeFourth() {
        let syllables = [syllable("一", "yi", 1, startsWord: true), syllable("下", "xia", 4)]
        #expect(text(syllables) == "yíxià")
        #expect(transformations(syllables) == [.yi])
    }

    @Test("一 before a first, second or third tone is spoken yì", arguments: [
        (1, "天", "tian", "yìtiān"),
        (2, "年", "nian", "yìnián"),
        (3, "点", "dian", "yìdiǎn"),
    ])
    func yiBeforeOthers(tone: Int, hanzi: Character, letters: String, expected: String) {
        let syllables = [syllable("一", "yi", 1, startsWord: true), syllable(hanzi, letters, tone)]
        #expect(text(syllables) == expected)
        #expect(transformations(syllables) == [.yi])
    }

    @Test("一 on its own keeps its first tone")
    func isolatedYi() {
        let syllables = [syllable("一", "yi", 1, startsWord: true)]
        #expect(text(syllables) == "yī")
        #expect(transformations(syllables).isEmpty)
    }

    @Test("一 as an ordinal after 第 keeps its first tone")
    func ordinalYi() {
        // 第一次 — the 一 counts rather than modifying, so no sandhi even
        // though a fourth tone follows.
        let syllables = [
            syllable("第", "di", 4, startsWord: true),
            syllable("一", "yi", 1),
            syllable("次", "ci", 4),
        ]
        #expect(text(syllables) == "dìyīcì")
        #expect(transformations(syllables).isEmpty)
    }

    @Test("一 inside a number keeps its first tone")
    func yiInNumber() {
        // 十一月 — 一 is the tail of "eleven", not "one month".
        let syllables = [
            syllable("十", "shi", 2, startsWord: true),
            syllable("一", "yi", 1),
            syllable("月", "yue", 4),
        ]
        #expect(text(syllables) == "shíyīyuè")
        #expect(transformations(syllables).isEmpty)
    }

    @Test("一 next to another digit keeps its first tone")
    func yiInDigitSequence() {
        // 一二三 — counting, not "one of something".
        let syllables = [
            syllable("一", "yi", 1, startsWord: true),
            syllable("二", "er", 4),
            syllable("三", "san", 1),
        ]
        #expect(text(syllables) == "yīèrsān")
        #expect(transformations(syllables).isEmpty)
    }

    @Test("一 in a name keeps its first tone")
    func yiInProperNoun() {
        // 一月 is `Yi1 yue4` in the data. The capital is CC-CEDICT's own
        // proper-noun marking, and a name keeps its base tone.
        let syllables = [syllable("一", "Yi", 1, startsWord: true), syllable("月", "yue", 4)]
        #expect(text(syllables) == "Yīyuè")
        #expect(transformations(syllables).isEmpty)
    }

    @Test("一 between two identical characters is left alone")
    func yiInReduplication() {
        // 看一看 — BLCU: 叠字中间须读轻. The data gives `yi1`, and inventing a
        // neutral tone the data does not have would be guessing.
        let syllables = [
            syllable("看", "kan", 4, startsWord: true),
            syllable("一", "yi", 1),
            syllable("看", "kan", 4),
        ]
        #expect(text(syllables) == "kànyīkàn")
        #expect(transformations(syllables).isEmpty)
    }

    @Test("一 before a reduced fourth tone is spoken yí, and the neighbour stays reduced")
    func yiBeforeReducedFourthTone() {
        // 一个 is `yi1 ge5` and is spoken `yíge`: the trigger is what 个 is
        // underlyingly — a fourth tone — not the neutral tone it surfaces
        // with. Two facts about one syllable, which is what the accuracy pass
        // asked the representation to be able to hold.
        let syllables = [
            syllable("一", "yi", 1, startsWord: true),
            syllable("个", "ge", 5, underlying: 4),
        ]
        #expect(text(syllables) == "yíge")
        #expect(transformations(syllables) == [.yi])
        // And the reduction is untouched: no rule turns a neutral tone back
        // into a full one.
        #expect(ToneSandhi.applied(to: syllables).syllables[1].tone == 5)
    }

    @Test("一 before a reduced first, second or third tone is spoken yì", arguments: [
        (1, "yìzi"), (2, "yìzi"), (3, "yìzi"),
    ])
    func yiBeforeReducedOtherTone(underlying: Int, expected: String) {
        // The other branch of the same rule, stated synthetically because
        // the data barely exercises it: across the whole snapshot only two
        // syllable pairs put `一` or `不` directly before a reduced syllable
        // — `一`+`个` and `不`+`得`. The mechanism is general, the corpus
        // instances are not, so the rule is written down here.
        let syllables = [
            syllable("一", "yi", 1, startsWord: true),
            syllable("子", "zi", 5, underlying: underlying),
        ]
        #expect(text(syllables) == expected)
        #expect(transformations(syllables) == [.yi])
    }

    @Test("一 before a reduction with no establishable base tone is left alone")
    func yiBeforeUndecidableReduction() {
        // 131 of the 538 reduced syllables in the snapshot get no base tone:
        // no full reading at all, no dominant one, or too few occurrences to
        // call it dominant. There the lexicon answers `nil`, and `nil` has to
        // mean "apply nothing" rather than "pick something".
        let syllables = [
            syllable("一", "yi", 1, startsWord: true),
            PinyinSyllable(
                hanzi: "么", letters: "me", lexicalTone: 5, tone: 5,
                underlyingTone: nil, unit: 0, foot: 0, startsWord: false
            ),
        ]
        #expect(text(syllables) == "yīme")
        #expect(transformations(syllables).isEmpty)
    }

    @Test("不 before a reduced fourth tone is spoken bú")
    func buBeforeReducedFourthTone() {
        // The same mechanism on the other rule, so the two cannot drift.
        let syllables = [
            syllable("不", "bu", 4, startsWord: true),
            syllable("过", "guo", 5, underlying: 4),
        ]
        #expect(text(syllables) == "búguo")
        #expect(transformations(syllables) == [.bu])
    }

    // MARK: - 不

    @Test("不 before a fourth tone is spoken bú")
    func buBeforeFourth() {
        let syllables = [syllable("不", "bu", 4, startsWord: true), syllable("对", "dui", 4)]
        #expect(text(syllables) == "búduì")
        #expect(transformations(syllables) == [.bu])
    }

    @Test("不 before a first, second or third tone stays bù", arguments: [
        (1, "多", "duo", "bùduō"),
        (2, "难", "nan", "bùnán"),
        (3, "好", "hao", "bùhǎo"),
    ])
    func buBeforeOthers(tone: Int, hanzi: Character, letters: String, expected: String) {
        let syllables = [syllable("不", "bu", 4, startsWord: true), syllable(hanzi, letters, tone)]
        #expect(text(syllables) == expected)
        #expect(transformations(syllables).isEmpty)
    }

    @Test("A lexical neutral 不 is never turned into a tone")
    func lexicalNeutralBuStays() {
        // 看不见 is `kan4 bu5 jian4`. A fourth tone follows, so the plain rule
        // would fire — but the neutral tone is lexical and outranks it. This
        // is the case the phase called out by name.
        let syllables = [
            syllable("看", "kan", 4, startsWord: true),
            syllable("不", "bu", 5),
            syllable("见", "jian", 4),
        ]
        #expect(text(syllables) == "kànbujiàn")
        #expect(transformations(syllables).isEmpty)
    }

    @Test("对不起 keeps its neutral 不")
    func duibuqi() {
        let syllables = [
            syllable("对", "dui", 4, startsWord: true),
            syllable("不", "bu", 5),
            syllable("起", "qi", 3),
        ]
        #expect(text(syllables) == "duìbuqǐ")
    }

    @Test("不 between two identical characters is left alone")
    func buInAAB() {
        // 对不对 is `dui4 bu4 dui4` in the data. An A-不-A question reduces
        // rather than taking the fourth-tone sandhi; the data encodes that for
        // 好不好 (`hao3 bu5 hao3`) and not here. Keeping the lexical tone is
        // the honest middle — no invented neutral tone, and no wrong `bú`.
        let syllables = [
            syllable("对", "dui", 4, startsWord: true),
            syllable("不", "bu", 4),
            syllable("对", "dui", 4),
        ]
        #expect(text(syllables) == "duìbùduì")
        #expect(transformations(syllables).isEmpty)
    }

    // MARK: - Boundaries

    @Test("Punctuation stops every rule")
    func punctuationIsABarrier() {
        // 他不。对了 — without the barrier, 不 would see the fourth tone of 对
        // across a full stop.
        let syllables = [
            syllable("他", "ta", 1, unit: 0, startsWord: true),
            syllable("不", "bu", 4, unit: 1, startsWord: true),
            PinyinSyllable.barrier(unit: 2),
            syllable("对", "dui", 4, unit: 3, startsWord: true),
        ]
        #expect(text(syllables) == "tā bù duì")
        #expect(transformations(syllables).isEmpty)
    }

    @Test("An untoned piece stops every rule")
    func opaquePieceIsABarrier() {
        // A transliterated guess has no tone, so it can neither be changed nor
        // trigger a change: what cannot be read cannot be a trigger.
        let syllables = [
            syllable("不", "bu", 4, unit: 0, startsWord: true),
            PinyinSyllable.opaque("kàn", unit: 1, startsWord: true),
        ]
        #expect(text(syllables) == "bù kàn")
        #expect(transformations(syllables).isEmpty)
    }

    @Test("Mixed input passes through untouched")
    func mixedInput() {
        let syllables = [
            PinyinSyllable.opaque("Wi-Fi", unit: 0, startsWord: true),
            syllable("密", "mi", 4, unit: 1, startsWord: true),
            syllable("码", "ma", 3, unit: 1),
        ]
        #expect(text(syllables) == "Wi-Fi mìmǎ")
        #expect(transformations(syllables).isEmpty)
    }

    @Test("Nothing in, nothing out")
    func emptyInput() {
        #expect(ToneSandhi.applied(to: []) == .none)
    }

    @Test("The lexical tones are never overwritten")
    func lexicalTonesSurvive() {
        // The rules write `tone` and read `lexicalTone`, so the dictionary
        // reading stays available — which is what makes the rules
        // non-chaining and what a diagnostic can fall back on.
        let syllables = [syllable("你", "ni", 3, startsWord: true), syllable("好", "hao", 3)]
        let result = ToneSandhi.applied(to: syllables)
        #expect(result.syllables.map(\.lexicalTone) == [3, 3])
        #expect(result.syllables.map(\.tone) == [2, 3])
        #expect(result.syllables[0].lexicalRendering == "nǐ")
        #expect(result.syllables[0].rendered == "ní")
    }

    @Test("Applying the rules twice changes nothing more")
    func idempotent() {
        // Cheap proof that the rules do not chain: running them on their own
        // output has to be a no-op, because they read the lexical tones.
        let syllables = [
            syllable("展", "zhan", 3, startsWord: true),
            syllable("览", "lan", 3),
            syllable("馆", "guan", 3),
        ]
        let once = ToneSandhi.applied(to: syllables)
        let twice = ToneSandhi.applied(to: once.syllables)
        #expect(once == twice)
    }

    @Test("Both 一 and 不 in one word, each on the lexical tones")
    func yiAndBuTogether() {
        // 不一样 is `bu4 yi1 yang4`: 不 sees 一's first tone and stays bù,
        // 一 sees 样's fourth tone and becomes yí. If the rules chained, 不
        // would see the fourth tone 一 just took and become bú.
        let syllables = [
            syllable("不", "bu", 4, startsWord: true),
            syllable("一", "yi", 1),
            syllable("样", "yang", 4),
        ]
        #expect(text(syllables) == "bùyíyàng")
        #expect(transformations(syllables) == [.yi])
    }
}
