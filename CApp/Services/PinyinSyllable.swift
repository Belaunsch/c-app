//
//  PinyinSyllable.swift
//  CApp
//

import Foundation

/// One piece of a Pinyin reading, with the tone still separate from the
/// letters.
///
/// This is what the resolver produces and what `ToneSandhi` works on. Keeping
/// the tone as a number until the very end is the whole point: a rule like
/// "a third tone before a third tone is spoken as a second" is a statement
/// about tones, and re-deriving them from `hǎo` by looking at the diacritic
/// would be an analysis of our own output. `PinyinTone` turns this into
/// visible text, once, at the end.
///
/// `nonisolated` like the other pure types here — the target defaults to
/// main-actor isolation, and a value type has no business requiring an actor.
nonisolated struct PinyinSyllable: Equatable {

    /// The Han character this syllable reads. `nil` for a piece that is not a
    /// single character: a transliterated guess for a whole word, or Latin
    /// text handed through.
    let hanzi: Character?

    /// The letters without a tone mark, `ü` already expanded: `hao`, `nüe`,
    /// `Yi`. For a piece that is not a toned syllable this carries the
    /// finished text instead, and it is rendered as it stands.
    let letters: String

    /// The tone the lexicon gives this syllable, 1 to 5 with 5 as the neutral
    /// tone.
    ///
    /// `nil` means "not a toned syllable we know" — a guess, or non-Chinese
    /// text. No rule may touch such a piece, and it acts as a barrier for
    /// rules that need to look at a neighbour: what cannot be read cannot be
    /// a trigger either.
    let lexicalTone: Int?

    /// The tone that is actually spoken. Starts out equal to `lexicalTone`
    /// and is only ever changed by `ToneSandhi`.
    var tone: Int?

    /// The tone this syllable **triggers** a neighbouring rule with.
    ///
    /// Equal to `lexicalTone` in every ordinary case. It differs for a
    /// reduced syllable: `个` in `一个` is `ge5` in the data, but the `一` rule
    /// is triggered by what `个` is underlyingly — a fourth tone — so `一个`
    /// is spoken `yíge`. Two separate facts about one syllable, which is
    /// exactly what the phase-6.5 accuracy pass called for: the surface tone
    /// stays neutral in the output, and only the trigger reads deeper.
    ///
    /// `nil` when the base tone cannot be established. `ChineseLexicon`
    /// answers that from the bundled data and says `nil` rather than
    /// guessing, and a rule with no trigger does nothing.
    ///
    /// **Only the `一` and `不` rules read this.** The third-tone rule stays
    /// on `lexicalTone` on purpose: a third tone before a *neutral* tone is
    /// genuinely variable and is deliberately not applied (A28), so giving
    /// that rule a deeper trigger would turn a documented abstention into a
    /// guess.
    let underlyingTone: Int?

    /// Which lexical unit this syllable belongs to.
    ///
    /// Syllables sharing a unit came out of **one** lexicon headword. That is
    /// the domain within which third-tone sandhi is safe to apply, and
    /// outside of which it is a prosodic guess — see `docs/architecture.md`
    /// A28.
    let unit: Int

    /// The constituent inside the unit that this syllable belongs to.
    ///
    /// A three-syllable headword is one lexical word but two constituents, and
    /// which way it brackets decides the tones: `展览馆` is `[[展览]馆]` and
    /// spoken `zhánlánguǎn`, while `小老鼠` is `[小[老鼠]]` and spoken
    /// `xiǎoláoshǔ` — same shape, different result. `ToneSandhi` applies the
    /// rule to the inner constituent first and then across the boundary,
    /// which is what produces the difference. Where the bracketing is not
    /// decidable, the split goes down the middle, which is the conservative
    /// outcome. A28.
    let foot: Int

    /// Whether a space goes in front of this syllable when rendering. Follows
    /// the segmentation's word boundaries, not the lexicon's, which has none.
    let startsWord: Bool

    /// A syllable whose tone is known and can take part in a rule.
    var isToned: Bool { lexicalTone != nil }

    /// The lexicon's own reading, for diagnostics and for tests that want to
    /// show a rule changed something.
    var lexicalRendering: String {
        Self.rendered(letters: letters, tone: lexicalTone)
    }

    /// What the user sees.
    var rendered: String {
        Self.rendered(letters: letters, tone: tone)
    }

    private static func rendered(letters: String, tone: Int?) -> String {
        guard let tone else { return letters }
        return PinyinTone.marked(syllable: letters + String(tone))
    }
}

extension PinyinSyllable {

    /// A syllable from one CC-CEDICT field: `zhan3`, `nu:e4`, `Yi1`.
    ///
    /// `nil` when the field is not a syllable plus tone digit. That covers
    /// the malformed entries in the data — 13 of them write two syllables
    /// without the separating space, `兙` reads `shi2ke4` — and it replaces
    /// the digit check the resolver used to run on the *rendered* string.
    /// Deciding it here is both earlier and stricter: `shi2ke4` fails because
    /// its letters contain a digit, not because the output happens to show
    /// one.
    static func lexical(
        _ numbered: String,
        hanzi: Character?,
        unit: Int,
        foot: Int,
        startsWord: Bool,
        underlyingTone: (_ syllable: String) -> Int? = { _ in nil }
    ) -> PinyinSyllable? {
        let expanded = numbered
            .replacingOccurrences(of: "u:", with: "ü")
            .replacingOccurrences(of: "U:", with: "Ü")

        guard let last = expanded.last,
              let tone = last.wholeNumberValue,
              (1...5).contains(tone) else { return nil }

        let letters = String(expanded.dropLast())
        guard letters.isEmpty == false,
              letters.allSatisfy(\.isLetter) else { return nil }

        // Only a reduced syllable needs to be asked about: everything else
        // already carries the tone a rule would look at.
        let underlying = tone == 5 ? underlyingTone(letters) : tone
        return PinyinSyllable(
            hanzi: hanzi,
            letters: letters,
            lexicalTone: tone,
            tone: tone,
            underlyingTone: underlying,
            unit: unit,
            foot: foot,
            startsWord: startsWord
        )
    }

    /// Punctuation: invisible in the output, but it ends a sentence and
    /// therefore ends the reach of every rule.
    ///
    /// Without it `他不。对了` would let `不` see the fourth tone of `对`
    /// across a full stop and become `bú`. Carrying an empty piece is
    /// cheaper than teaching each rule about sentence ends, and it cannot be
    /// forgotten by a later rule: it has no tone, so it blocks by the same
    /// mechanism a transliterated guess does.
    static func barrier(unit: Int) -> PinyinSyllable {
        PinyinSyllable(
            hanzi: nil,
            letters: "",
            lexicalTone: nil,
            tone: nil,
            underlyingTone: nil,
            unit: unit,
            foot: unit,
            startsWord: true
        )
    }

    /// A piece that is not a reading we know: a transliterated guess, or text
    /// handed through unchanged. Carries no tone, so no rule applies to it
    /// and none reaches across it.
    static func opaque(_ text: String, unit: Int, startsWord: Bool) -> PinyinSyllable {
        PinyinSyllable(
            hanzi: nil,
            letters: text,
            lexicalTone: nil,
            tone: nil,
            underlyingTone: nil,
            unit: unit,
            foot: unit,
            startsWord: startsWord
        )
    }

    /// The syllables of one lexicon reading, split over the characters of the
    /// headword.
    ///
    /// `nil` when the reading cannot be trusted: the syllable count has to
    /// match the character count, and every syllable has to parse. The count
    /// condition holds for every pure-Han headword in the data — verified
    /// across all 124.202 of them in the snapshot, and checked here rather
    /// than assumed.
    static func lexical(
        reading: String,
        of word: String,
        unit: Int,
        footSplit: Int?,
        wordStartOffsets: Set<Int>,
        underlyingTone: (_ character: Character, _ syllable: String) -> Int? = { _, _ in nil }
    ) -> [PinyinSyllable]? {
        let fields = reading.split(separator: " ").map(String.init)
        let characters = Array(word)
        guard fields.count == characters.count else { return nil }

        var syllables: [PinyinSyllable] = []
        for (offset, field) in fields.enumerated() {
            // Two feet at most: a binary split is what a sub-headword can
            // tell us, and guessing a deeper structure would be inventing
            // one. No split means one foot, which is the conservative case.
            let foot = (footSplit.map { offset >= $0 } ?? false) ? unit * 2 + 1 : unit * 2
            let character = characters[offset]
            guard let syllable = lexical(
                field,
                hanzi: character,
                unit: unit,
                foot: foot,
                startsWord: wordStartOffsets.contains(offset),
                underlyingTone: { underlyingTone(character, $0) }
            ) else { return nil }
            syllables.append(syllable)
        }
        return syllables
    }

    /// The visible Pinyin for a whole reading.
    ///
    /// Words are separated by a single space, syllables inside a word by
    /// nothing — `zǎoshang hǎo`, not `zǎo shang hǎo` and not `zǎoshanghǎo`.
    /// Barriers render as nothing at all: Pinyin is written without the
    /// Chinese punctuation, and a barrier exists only to stop a rule.
    static func rendered(_ syllables: [PinyinSyllable]) -> String {
        var text = ""
        for syllable in syllables where syllable.letters.isEmpty == false {
            if syllable.startsWord, text.isEmpty == false {
                text += " "
            }
            text += syllable.rendered
        }
        return text
    }
}
