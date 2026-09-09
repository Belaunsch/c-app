//
//  ToneSandhi.swift
//  CApp
//

import Foundation

/// Turns the dictionary's tones into the tones a learner actually says.
///
/// CC-CEDICT stores the **lexical** tone: `你好` is `ni3 hao3`, `不对` is
/// `bu4 dui4`, `一点` is `yi1 dian3`. Spoken Mandarin changes some of those,
/// and this is where that happens — once, on structured syllables, never by
/// re-reading finished text.
///
/// ## Why the app shows the spoken form
///
/// GB/T 16159-2012 §6.5.2 settles the question for `一` and `不`: they are
/// normally written with the original tone, *and* the same clause adds
/// „在语言教学等方面，可根据需要按变调标写" — in language teaching the sandhi
/// form may be written where it is useful. This app is language teaching, so
/// it shows the spoken form. Decision A29.
///
/// ## What is applied, and what is deliberately not
///
/// Three rules, all obligatory and all local:
///
/// - **Third tone before third tone** becomes a second tone, but only inside
///   one lexical unit. `你好` is `níhǎo` and `展览馆` is `zhánlánguǎn`, while
///   a third tone meeting another across a word boundary is left alone.
/// - **`一`** becomes `yí` before a fourth tone and `yì` before a first,
///   second or third — with the exceptions below.
/// - **`不`** becomes `bú` before a fourth tone.
///
/// Not applied, each for a stated reason:
///
/// - **Across unit boundaries for the third tone.** Whether two words in a
///   phrase form one sandhi domain depends on prosodic grouping, syntactic
///   branching, focus and tempo — Duanmu's analysis has the rule applying
///   cyclically per foot and being *optional* between branches. An automatic
///   guess would be wrong as often as right. A28.
/// - **Third tone before a neutral tone.** Genuinely variable, and the
///   variation is not predictable from the data: 北京语言大学's 现代汉语
///   material gives both `214+轻声→35+轻声` (打扫, 想想) and
///   `214+轻声→21+轻声` (李子, 姐姐).
/// - **The neutral tone itself.** Lexical, never derived. `对不起` is
///   `dui4 bu5 qi3` in the data and stays that way; no rule here may turn a
///   neutral tone into anything else.
///
/// Pure and deterministic: same syllables in, same syllables out. No lexicon,
/// no ICU, no locale, so it is fully testable without a simulator.
nonisolated enum ToneSandhi {

    /// The spoken syllables plus which rule classes fired.
    struct Result: Equatable {
        let syllables: [PinyinSyllable]
        let transformations: Set<PinyinResolution.Transformation>

        static let none = Result(syllables: [], transformations: [])
    }

    /// Applies the three rules.
    ///
    /// A syllable only ever writes **its own** `tone`, never a neighbour's.
    /// Which tone a rule *reads* differs on purpose, and the three cases are
    /// worth naming because an earlier version of this comment claimed they
    /// were all the same — and the review pointed out that a reader believing
    /// it would "tidy up" the second cycle and restore `xiáoláoshǔ`:
    ///
    /// - The **first** third-tone cycle reads `lexicalTone`, so the rules
    ///   inside a foot cannot chain into each other. That is the standard
    ///   formulation — sandhi applies to the underlying representation — and
    ///   it is what makes `展览馆` come out `zhánlánguǎn`.
    /// - The **second** cycle, across the foot boundary, reads the surface
    ///   `tone` the first one produced. That is not an oversight: it is the
    ///   entire mechanism that separates `展览馆` from `小老鼠`.
    /// - The `一` and `不` rules read the neighbour's `underlyingTone`, so a
    ///   reduced fourth tone still triggers them (`一个` → `yíge`, A30).
    static func applied(to syllables: [PinyinSyllable]) -> Result {
        guard syllables.isEmpty == false else { return .none }

        var spoken = syllables
        var transformations: Set<PinyinResolution.Transformation> = []

        for index in spoken.indices {
            let syllable = syllables[index]
            guard let tone = syllable.lexicalTone else { continue }

            switch syllable.hanzi {
            case yi where tone == 1:
                if let changed = yiTone(at: index, in: syllables) {
                    spoken[index].tone = changed
                    transformations.insert(.yi)
                }
            case bu where tone == 4:
                if let changed = buTone(at: index, in: syllables) {
                    spoken[index].tone = changed
                    transformations.insert(.bu)
                }
            default:
                if tone == 3, isThirdToneBeforeThird(at: index, in: syllables) {
                    spoken[index].tone = 2
                    transformations.insert(.thirdTone)
                }
            }
        }

        // Second cycle: across the constituent boundary inside one word.
        //
        // This is where `展览馆` and `小老鼠` come apart, and it has to look at
        // the **surface** tone the first cycle produced rather than the
        // lexical one:
        //
        //   `[[展览]馆]` — the first cycle makes 展 a second tone and leaves 览
        //   alone, so 览 still carries a third tone when it meets 馆 and
        //   becomes a second: `zhánlánguǎn`.
        //
        //   `[小[老鼠]]` — the first cycle makes 老 a second tone, so 小 meets
        //   a second tone and stays put: `xiǎoláoshǔ`.
        //
        // Same three third tones, two different results, and the difference is
        // entirely the bracketing. Only one outer cycle runs: a binary split is
        // all a sub-headword can witness (A28).
        for index in spoken.indices {
            guard syllables[index].lexicalTone == 3,
                  spoken[index].tone == 3,
                  let next = spoken.element(after: index),
                  next.unit == spoken[index].unit,
                  next.foot != spoken[index].foot,
                  next.tone == 3 else { continue }
            spoken[index].tone = 2
            transformations.insert(.thirdTone)
        }

        return Result(syllables: spoken, transformations: transformations)
    }

    // MARK: - Third tone

    /// Whether this third tone is followed by another one **in the same
    /// constituent**.
    ///
    /// The unit is what makes this safe. Syllables share a unit when they came
    /// out of one lexicon headword, so `展览馆` is one domain and its three
    /// third tones are decidable, while `我很好` is not one headword and gets
    /// no automatic change. Erring towards the dictionary form is the
    /// harmless direction: it is what every dictionary prints.
    ///
    /// Inside the unit the **foot** narrows it further, and that is the first
    /// of the two cycles — see the second one in `applied(to:)`.
    private static func isThirdToneBeforeThird(at index: Int, in syllables: [PinyinSyllable]) -> Bool {
        guard let next = syllables.element(after: index) else { return false }
        return next.foot == syllables[index].foot && next.lexicalTone == 3
    }

    // MARK: - 一

    /// The tone `一` is spoken with, or `nil` to leave the lexical tone alone.
    ///
    /// 北京语言大学, 现代汉语: „『一』字基调是阴平，阴阳上前全降声；去声之前念中升,
    /// 叠字中间须读轻" — base tone first; fourth tone before a first, second or
    /// third; second tone before a fourth; neutral between reduplicated
    /// characters.
    private static func yiTone(at index: Int, in syllables: [PinyinSyllable]) -> Int? {
        // `underlyingTone`, not `lexicalTone`: `一个` is `yi1 ge5` and is
        // spoken `yíge`, because what triggers the rule is the fourth tone
        // `个` carries underneath its reduction. `个` itself stays neutral in
        // the output. `nil` where the base tone is not establishable, and
        // then no rule runs.
        guard let next = syllables.element(after: index),
              let nextTone = next.underlyingTone,
              nextTone != 5 else { return nil }
        guard isPlainNumber(at: index, in: syllables) == false,
              isReduplicated(at: index, in: syllables) == false,
              isProperNoun(syllables[index]) == false else { return nil }

        switch nextTone {
        case 4: return 2
        case 1, 2, 3: return 4
        default: return nil
        }
    }

    /// Whether `一` here is a plain number rather than "one" modifying what
    /// follows. Then it keeps its first tone.
    ///
    /// Three shapes, all decidable from the neighbouring characters:
    /// an ordinal after `第` (第一次), the last digit of a larger number
    /// (十一月), and a digit next to another digit (一二三, 一百).
    ///
    /// Not decidable, and therefore a documented limit: `一` as a label where
    /// no neighbour marks it as a number — `一号` for the first of the month
    /// reads `yīhào`, and nothing here distinguishes it from `一定`. Measured
    /// as wrong and kept in the corpus as such rather than papered over with
    /// a word list.
    private static func isPlainNumber(at index: Int, in syllables: [PinyinSyllable]) -> Bool {
        if let previous = syllables.element(before: index)?.hanzi,
           previous == ordinalPrefix || numberCharacters.contains(previous) {
            return true
        }
        if let next = syllables.element(after: index)?.hanzi,
           numberCharacters.contains(next) {
            return true
        }
        return false
    }

    /// Whether the syllable sits between two occurrences of the same
    /// character: `看一看`, `对不对`. The reduplication takes a neutral tone
    /// or none, and either way the plain rule does not apply.
    private static func isReduplicated(at index: Int, in syllables: [PinyinSyllable]) -> Bool {
        guard let previous = syllables.element(before: index)?.hanzi,
              let next = syllables.element(after: index)?.hanzi else { return false }
        return previous == next
    }

    /// Whether CC-CEDICT capitalises this syllable, which is the closest
    /// thing the data has to a proper-noun marking.
    ///
    /// A name keeps its base tone: `一月` is `Yi1 yue4` and stays `Yīyuè`,
    /// `一战` is `Yi1 zhan4` and stays `Yīzhàn`. Without this, `不列颠` —
    /// `Bu4 lie4 dian1`, the transliteration of *Britain* — would come out as
    /// `Búlièdiān`, applying a negation rule to a syllable that is not a
    /// negation.
    ///
    /// **Not a reliable criterion, and deliberately not claimed as one.**
    /// Capitalisation is per syllable and follows the entry, not the word
    /// class: `千禧一代` is `Qian1 xi3 Yi1 dai4` — an ordinary noun whose `一`
    /// is capitalised, so the rule is skipped and the form stays `Yīdài`
    /// instead of `yídài`. Found by the review. The error goes towards the
    /// dictionary form, which is the harmless direction, and the alternative
    /// — ignoring the signal — would put a wrong `bú` into every `不列颠`
    /// compound. Measured: 18.957 entries carry a capitalised first syllable,
    /// 24 of them with `一` and 21 with `不`.
    private static func isProperNoun(_ syllable: PinyinSyllable) -> Bool {
        syllable.letters.first?.isUppercase == true
    }

    // MARK: - 不

    /// The tone `不` is spoken with, or `nil` for the lexical tone.
    ///
    /// 北京语言大学, 现代汉语: „『不』字基调是去声，阴阳上前不变更；去声之前变中升,
    /// 叠字当中也念轻" — fourth tone by default, unchanged before a first,
    /// second or third, second tone before a fourth, neutral inside a
    /// reduplication.
    ///
    /// The neutral tone is not this function's business: it is already in the
    /// data wherever it is lexical (`对不起` is `dui4 bu5 qi3`, `差不多` is
    /// `cha4 bu5 duo1`), and a syllable whose lexical tone is 5 never reaches
    /// here — the caller only asks for `不` with tone 4.
    private static func buTone(at index: Int, in syllables: [PinyinSyllable]) -> Int? {
        // `underlyingTone` for the same reason as in `yiTone`: a reduced
        // fourth tone still triggers. `不` with a lexical neutral tone never
        // reaches here — the caller only asks for tone 4.
        guard let next = syllables.element(after: index),
              next.underlyingTone == 4 else { return nil }
        // `对不对` is `dui4 bu4 dui4` in the data, but an A-不-A question does
        // not take the fourth-tone sandhi — it reduces, which the data
        // encodes for `好不好` (`hao3 bu5 hao3`) and not here. Leaving the
        // lexical tone is the honest middle: no invented neutral tone, and no
        // wrong `bú`.
        guard isReduplicated(at: index, in: syllables) == false,
              isProperNoun(syllables[index]) == false else { return nil }
        return 2
    }

    // MARK: - Characters

    private static let yi: Character = "一"
    private static let bu: Character = "不"
    private static let ordinalPrefix: Character = "第"

    /// The characters that make `一` the tail of a number instead of "one":
    /// `十一`, `二十一`, `一百零一`.
    private static let numberCharacters: Set<Character> = [
        "一", "二", "三", "四", "五", "六", "七", "八", "九", "十",
        "百", "千", "万", "亿", "零", "两",
    ]
}

/// `nonisolated` for the same reason `ToneSandhi` itself is: the target sets
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so without it these helpers
/// would be main-actor-bound and calling them from the nonisolated engine
/// would be a warning today and an error under the Swift 6 language mode. The
/// module-wide decision is Q8 in `docs/apple-frameworks.md`.
nonisolated private extension Array where Element == PinyinSyllable {

    /// The next syllable, or `nil` at the end.
    func element(after index: Int) -> PinyinSyllable? {
        let next = index + 1
        return indices.contains(next) ? self[next] : nil
    }

    /// The previous syllable, or `nil` at the start.
    func element(before index: Int) -> PinyinSyllable? {
        let previous = index - 1
        return indices.contains(previous) ? self[previous] : nil
    }
}
