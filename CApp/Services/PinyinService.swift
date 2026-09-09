//
//  PinyinService.swift
//  CApp
//

import Foundation

/// How a Pinyin value came about.
///
/// Deliberately categorical: either the reading came out of the lexicon, or
/// something had to be guessed by transliteration. No percentages, no
/// confidence — a number would suggest a precision that does not exist.
struct PinyinResolution: Equatable {

    enum Source: Equatable {
        /// Every word came from the lexicon, with exactly one reading each.
        case lexicon
        /// Some words came from the lexicon, at least one had to fall back.
        case mixed
        /// Nothing could be looked up; the whole value is transliterated.
        case icuFallback
        /// Nothing to resolve — no Chinese in the input.
        case empty
    }

    /// Which class of tone rule changed the reading on its way to the
    /// spoken form.
    ///
    /// Three cases, not an event log: this exists so a test can show that a
    /// rule fired and so the benchmark can sort its failures by rule class.
    /// It says nothing about how often or where — that would be an analysis
    /// nobody asked for.
    enum Transformation: String, Equatable, Sendable, CaseIterable {
        /// A third tone before a third tone, spoken as a second.
        case thirdTone
        /// `一` before a tone that changes it.
        case yi
        /// `不` before a fourth tone.
        case bu
    }

    let text: String
    let source: Source

    /// The rule classes that fired. Empty means the visible text is exactly
    /// the lexicon's reading.
    var transformations: Set<Transformation> = []

    /// Whether the user should look at this value before trusting it.
    ///
    /// True exactly when a transliterated guess is part of the result — a
    /// tone rule never makes a reading uncertain, and never makes an
    /// uncertain one safe. That is the one thing the editor shows a hint for.
    var needsReview: Bool {
        source == .mixed || source == .icuFallback
    }

    /// Whether the visible text differs from the plain dictionary reading.
    ///
    /// The app shows the **spoken** form, which standard written Pinyin often
    /// does not (`docs/architecture.md` A29).
    var showsSpokenTones: Bool { transformations.isEmpty == false }

    static let empty = PinyinResolution(text: "", source: .empty)
}

/// Turns Hanzi into Pinyin with tone marks.
///
/// Runs entirely offline: the bundled CC-CEDICT readings plus the ICU data
/// that ships with the system. No network, no permission, no external
/// dependency.
///
/// Three questions, answered by whoever knows best:
///
/// 1. **Where are the word boundaries?** `CFStringTokenizer` with the
///    Simplified Chinese locale. Chinese is written without spaces, and ICU's
///    segmentation is good at this — measured: `火车站`, `洗手间` and `明白`
///    come back as single tokens.
/// 2. **How is a word read?** `ChineseLexicon`, and only it, whenever the
///    word has exactly one reading. This is where the neutral tone comes
///    from: `谢谢` is `xièxie` and `早上` is `zǎoshang`, both of which ICU
///    renders with a full second tone.
/// 3. **What if the lexicon cannot say?** Then, and only then, ICU's own
///    transcription — the tokenizer's, or `CFStringTransform` for the rare
///    characters it has none for. Flagged either way, so the editor can ask
///    the user to check it.
///
/// A token the lexicon has no headword for is decomposed into words it does
/// know before ICU is asked — `啤酒杯` is `啤酒` plus `杯` — so an ordinary
/// compound does not end up flagged for review over nothing.
///
/// The search runs longest-known-phrase-first over the ICU tokens, which is
/// what resolves ambiguity from context without a single hand-written rule:
/// `东西` alone has two readings and gets flagged, but in `买东西` the phrase
/// is in the lexicon and reads `mǎi dōngxi`, while `东西南北` reads
/// `dōngxī nánběi`. Using the ICU boundaries as the only candidate cut points
/// is what keeps this safe — a purely character-based longest match reads `我不明白`
/// as `不明` + `白`, which is wrong.
///
/// Known limit, deliberately not solved: a word with several readings that no
/// surrounding phrase disambiguates. The German side of the card would often
/// settle it — `etwas` versus `Osten und Westen` — but CC-CEDICT's glosses are
/// English and there is no dependable offline bridge from German to them. See
/// `docs/architecture.md` A24 and `docs/apple-frameworks.md` §10, Q6.
enum PinyinService {

    /// The Pinyin for `hanzi`, or an empty string when nothing can be derived.
    ///
    /// Never throws and never blocks: an empty result simply means the user
    /// fills the field in by hand.
    static func pinyin(for hanzi: String) -> String {
        resolution(for: hanzi).text
    }

    /// The Pinyin plus where it came from.
    @MainActor
    static func resolution(for hanzi: String) -> PinyinResolution {
        let source = hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        // Neither the lexicon nor ICU recognises "this is not Chinese" — ICU
        // transliterates what it can and passes the rest through. So the
        // question is settled here, before anything else runs.
        guard containsHanScript(source) else { return .empty }

        let resolved = resolveWords(in: source)
        guard isPlausibleTranscription(resolved.text, of: source) else { return .empty }
        return resolved
    }

    /// Whether `text` contains at least one Han character.
    ///
    /// Uses the Unicode `Ideographic` property rather than character ranges of
    /// our own: it covers the CJK ideographs including every extension
    /// (measured: U+3400, U+20000 and U+3007 all qualify) and excludes Latin,
    /// digits, punctuation, emoji, Kana, Hangul and Cyrillic. Kanji qualify,
    /// which is correct — they are Han characters and do have a Mandarin
    /// reading.
    ///
    /// Not identical to "Han script" in both directions, which is why the
    /// result is checked as well: a few ideographic scripts Mandarin knows
    /// nothing about (Tangut, Nüshu) pass this test and then fail the result
    /// check, and a handful of Han characters that are not ideographs — the
    /// Kangxi radicals, the iteration mark `々` — do not pass it at all. Both
    /// gaps err towards "no Pinyin", which is the harmless direction.
    static func containsHanScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.properties.isIdeographic }
    }

    // MARK: - Resolution

    @MainActor
    private static func resolveWords(in text: String) -> PinyinResolution {
        let lexicon = ChineseLexicon.shared
        let tokens = segmentedTokens(of: text)

        var syllables: [PinyinSyllable] = []
        var usedLexicon = false
        var usedFallback = false
        var index = 0
        // Every lexicon headword match and every fallback piece gets its own
        // number. Third-tone sandhi may only look inside one of them.
        var unit = 0

        while index < tokens.count {
            let token = tokens[index]

            // A sentence boundary: nothing to read, but every rule stops.
            if token.isPunctuation {
                syllables.append(.barrier(unit: unit))
                unit += 1
                index += 1
                continue
            }

            // Not Chinese. Mixed input is allowed (see `containsHanScript`),
            // and what ICU does with it decides whether this counts as a
            // guess: Latin and digits come back unchanged, which is a
            // pass-through and nothing to review, but Cyrillic or Kana get
            // romanised — measured, `хорошо` becomes `horošo` — and that is
            // ICU guessing at a script it was not asked about.
            guard token.text.contains(where: { containsHanScript(String($0)) }) else {
                if let transcription = token.transcription, transcription.isEmpty == false {
                    syllables.append(.opaque(transcription, unit: unit, startsWord: true))
                    unit += 1
                    if transcription != token.text {
                        usedFallback = true
                    }
                }
                index += 1
                continue
            }

            // Longest known phrase first, cut only at ICU's word boundaries.
            if let match = longestKnownPhrase(in: tokens, from: index, unit: unit, lexicon: lexicon) {
                syllables.append(contentsOf: match.syllables)
                usedLexicon = true
                unit += 1
                index += match.tokenCount
                continue
            }

            // ICU sometimes returns a compound as one token that the
            // lexicon does not know as a headword, while every part of it is
            // in there — `啤酒杯` is `啤酒` plus `杯`. Taking ICU's reading for
            // the whole thing would put a review hint on a card where
            // nothing is uncertain, so the token is decomposed first.
            if let decomposed = decomposition(of: token.text, firstUnit: unit, lexicon: lexicon) {
                syllables.append(contentsOf: decomposed.syllables)
                usedLexicon = true
                unit = decomposed.nextUnit
                index += 1
                continue
            }

            // The lexicon has no single answer. Guess, and say that we did.
            if let guess = transliterationGuess(for: token) {
                syllables.append(.opaque(guess, unit: unit, startsWord: true))
                unit += 1
            }
            usedFallback = true
            index += 1
        }

        let spoken = ToneSandhi.applied(to: syllables)
        let rendered = PinyinSyllable.rendered(spoken.syllables)
        return PinyinResolution(
            text: rendered,
            source: source(lexicon: usedLexicon, fallback: usedFallback, text: rendered),
            transformations: spoken.transformations
        )
    }

    private static func source(lexicon: Bool, fallback: Bool, text: String) -> PinyinResolution.Source {
        guard text.isEmpty == false else { return .empty }
        switch (lexicon, fallback) {
        case (true, false): return .lexicon
        case (true, true): return .mixed
        case (false, true): return .icuFallback
        case (false, false): return .empty
        }
    }

    /// The longest run of tokens starting at `start` that the lexicon knows
    /// as one headword with a single reading.
    ///
    /// The syllables carry the word boundaries with them, so the spacing
    /// follows the segmentation rather than the lexicon, which has none:
    /// CC-CEDICT writes every syllable separately, `早上好` as
    /// `zao3 shang5 hao3`, and gives no hint that this is two words.
    /// Splitting the syllables back over the characters works because a
    /// headword of pure Han characters has exactly one syllable per character
    /// — verified across all 124.202 such entries in the snapshot, and
    /// checked in `PinyinSyllable.lexical(reading:of:unit:wordStartOffsets:)`
    /// rather than assumed.
    ///
    /// All of them share one unit number. That is the sandhi domain: one
    /// headword is one lexical word, and that is as far as an automatic tone
    /// change may reach.
    @MainActor
    private static func longestKnownPhrase(
        in tokens: [Token],
        from start: Int,
        unit: Int,
        lexicon: ChineseLexicon
    ) -> (syllables: [PinyinSyllable], tokenCount: Int)? {
        var count = tokens.count - start
        while count >= 1 {
            let group = tokens[start..<(start + count)]
            let word = group.map(\.text).joined()

            if word.count <= lexicon.longestHeadwordLength,
               word.allSatisfy({ containsHanScript(String($0)) }),
               let reading = lexicon.reading(for: word) {
                var offsets: Set<Int> = []
                var offset = 0
                for token in group {
                    offsets.insert(offset)
                    offset += token.text.count
                }
                if let syllables = PinyinSyllable.lexical(
                    reading: reading,
                    of: word,
                    unit: unit,
                    footSplit: footSplit(of: word, lexicon: lexicon),
                    wordStartOffsets: offsets,
                    underlyingTone: { lexicon.baseTone(ofSyllable: $1, character: $0) }
                ) {
                    return (syllables, count)
                }
            }
            count -= 1
        }
        return nil
    }

    /// Where a headword brackets, or `nil` when the data does not say.
    ///
    /// A three-syllable headword is one word but two constituents, and the
    /// bracketing decides the tones: `展览馆` is `[[展览]馆]` and spoken
    /// `zhánlánguǎn`, `小老鼠` is `[小[老鼠]]` and spoken `xiǎoláoshǔ`. The
    /// difference is not in the tones themselves — both are three third tones
    /// — but in which constituent the rule applies to first (A28).
    ///
    /// The structure is not in the data, but a **sub-headword** is a usable
    /// witness for it, and asking for one is what the phase brief asked for:
    /// determine the lexical unit before applying anything. Longest prefix and
    /// longest suffix are looked up; exactly one of them being a headword
    /// settles the bracketing. Measured over the third-tone words in the
    /// corpus: 14 of 17 are settled this way, and all 14 match what the
    /// sources give.
    ///
    /// When both are headwords (`小雨伞` is `小雨` **and** `雨伞`) or neither is
    /// (`导火索`), the split goes down the middle. That is the conservative
    /// outcome rather than a claim: for a right-bracketing word it is the form
    /// the sources give, and for a left-bracketing one it merely leaves the
    /// leading syllable at its dictionary tone. What it never produces is a
    /// third value no source supports — which is what applying the rule
    /// uniformly across three third tones would do, and what the first
    /// implementation did until the review caught it.
    ///
    /// This middle split *is* a positional heuristic inside the word, which
    /// the phase brief otherwise rules out. It is confined to the case where
    /// the data witnesses nothing, it errs towards the dictionary, and
    /// `水果酒` is in the corpus as a measured failure because of it.
    ///
    /// A word of two characters needs no split; the pair is unambiguous.
    @MainActor
    private static func footSplit(of word: String, lexicon: ChineseLexicon) -> Int? {
        let characters = Array(word)
        guard characters.count >= 3 else { return nil }

        func known(_ candidate: String) -> Bool {
            lexicon.reading(for: candidate) != nil || lexicon.isAmbiguous(candidate)
        }

        var prefix: Int?
        for length in stride(from: characters.count - 1, through: 2, by: -1)
        where known(String(characters[0..<length])) {
            prefix = length
            break
        }
        var suffix: Int?
        for start in 1...(characters.count - 2)
        where known(String(characters[start...])) {
            suffix = start
            break
        }

        switch (prefix, suffix) {
        case let (.some(index), .none): return index
        case let (.none, .some(index)): return index
        default:
            // Not decidable — `小雨伞` is both `小雨` and `雨伞`, `导火索` is
            // neither. Split down the middle, which is the conservative
            // outcome rather than a claim about the language: for a
            // right-bracketing word it is the form the sources give, and for
            // a left-bracketing one it merely leaves the leading syllable at
            // its dictionary tone. What it never produces is a third value
            // that no source supports — which is what applying the rule
            // uniformly across three third tones would do.
            return characters.count / 2
        }
    }

    /// Splits a token the lexicon does not know as a whole into words it does
    /// know, longest first.
    ///
    /// No word break in the result: the tokenizer considers this one word,
    /// and this only fills in a reading it has no headword for. Each part
    /// does get its **own** unit number, though — `啤酒杯` is two lexical
    /// words that happen to be written without a space, and a tone rule
    /// reaching across them would assume a prosody nobody stated.
    ///
    /// Gives up rather than guessing in two situations. A part that is not in
    /// the lexicon at all ends the attempt — and so does a part that is
    /// *known to have several readings*, because cutting such a word into
    /// single characters would silently pick one of them: `东西方` would
    /// become `dōngxīfāng` and look certain, when `东西` is exactly the word
    /// that cannot be settled without context.
    @MainActor
    private static func decomposition(
        of token: String,
        firstUnit: Int,
        lexicon: ChineseLexicon
    ) -> (syllables: [PinyinSyllable], nextUnit: Int)? {
        let characters = Array(token)
        guard characters.count > 1 else { return nil }

        var syllables: [PinyinSyllable] = []
        var unit = firstUnit
        var index = 0
        while index < characters.count {
            var length = min(lexicon.longestHeadwordLength, characters.count - index)
            var matched = false
            while length >= 1 {
                let candidate = String(characters[index..<(index + length)])
                if lexicon.isAmbiguous(candidate) { return nil }
                if let reading = lexicon.reading(for: candidate),
                   let parts = PinyinSyllable.lexical(
                       reading: reading,
                       of: candidate,
                       unit: unit,
                       footSplit: footSplit(of: candidate, lexicon: lexicon),
                       wordStartOffsets: index == 0 ? [0] : [],
                       underlyingTone: { lexicon.baseTone(ofSyllable: $1, character: $0) }
                   ) {
                    syllables.append(contentsOf: parts)
                    unit += 1
                    index += length
                    matched = true
                    break
                }
                length -= 1
            }
            guard matched else { return nil }
        }
        return (syllables, unit)
    }

    /// ICU's own reading for a token the lexicon cannot settle.
    ///
    /// The tokenizer's transcription first, then `CFStringTransform` for the
    /// rare characters it returns nothing for — measured: U+20000 has no
    /// transcription but transforms to `hē`. Both are guesses, which is why
    /// the caller marks the result for review either way.
    private static func transliterationGuess(for token: Token) -> String? {
        if let transcription = token.transcription,
           transcription.contains(where: { $0.isLetter }) {
            return transcription
        }
        guard let mutable = CFStringCreateMutableCopy(nil, 0, token.text as CFString),
              CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false) else {
            return nil
        }
        let transformed = (mutable as String)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard transformed.contains(where: { $0.isLetter }) else { return nil }
        return transformed
    }

    // MARK: - ICU segmentation

    private struct Token {
        let text: String
        /// ICU's own Latin transcription of this token, used only as the
        /// fallback when the lexicon has no single reading.
        let transcription: String?
        /// Punctuation carries no reading but does end a sentence, so it is
        /// kept as a boundary rather than dropped — see
        /// `PinyinSyllable.barrier(unit:)`.
        let isPunctuation: Bool
    }

    private static func segmentedTokens(of text: String) -> [Token] {
        let cfText = text as CFString
        let range = CFRangeMake(0, CFStringGetLength(cfText))
        // The Simplified Chinese locale is what makes the tokenizer split a
        // space-free string into words at all.
        let locale = Locale(identifier: "zh_Hans") as CFLocale
        guard let tokenizer = CFStringTokenizerCreate(
            nil, cfText, range, kCFStringTokenizerUnitWordBoundary, locale
        ) else {
            return []
        }

        let nsText = text as NSString
        var tokens: [Token] = []
        while CFStringTokenizerAdvanceToNextToken(tokenizer).rawValue != 0 {
            let tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            guard tokenRange.location >= 0, tokenRange.length > 0 else { continue }
            let word = nsText.substring(
                with: NSRange(location: tokenRange.location, length: tokenRange.length)
            )
            // Punctuation does carry a transcription — "。" comes back as
            // "｡". Measured in phase 3; taking it would put "wǒ xiǎng chī
            // diǎn dōngxī ｡" in the field, because Pinyin is written without
            // the Chinese punctuation. It is kept as a **boundary** instead
            // of dropped, so a tone rule cannot reach across a full stop.
            guard word.contains(where: { $0.isLetter || $0.isNumber }) else {
                tokens.append(Token(text: word, transcription: nil, isPunctuation: true))
                continue
            }

            let transcription = (CFStringTokenizerCopyCurrentTokenAttribute(
                tokenizer, kCFStringTokenizerAttributeLatinTranscription
            ) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

            tokens.append(Token(text: word, transcription: transcription, isPunctuation: false))
        }
        return tokens
    }

    // MARK: - Plausibility

    /// Whether `candidate` is a transcription rather than the input handed
    /// back.
    ///
    /// The Han check lets mixed input through, and the ideographic property
    /// covers a few scripts Mandarin transliteration knows nothing about, so
    /// the result is checked as well: it has to differ from the source and
    /// carry a cased letter. Han characters are letters but have no case, so
    /// a result that is merely a copy of the input fails here.
    private static func isPlausibleTranscription(_ candidate: String, of source: String) -> Bool {
        guard candidate.isEmpty == false, candidate != source else { return false }
        return candidate.contains { $0.isCased }
    }
}
