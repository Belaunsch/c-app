//
//  PinyinService.swift
//  CApp
//

import Foundation

/// Turns Hanzi into Pinyin with tone marks.
///
/// Runs entirely offline on ICU data shipped with the system: no network, no
/// permission, no dictionary of our own, no external dependency.
///
/// Two paths, in this order:
///
/// 1. `CFStringTokenizer` with `kCFStringTokenizerAttributeLatinTranscription`.
///    Chinese is written without spaces, and the tokenizer knows where the
///    word boundaries are, so `苹果` comes back as one word `píngguǒ` rather
///    than the two syllables `píng guǒ`.
/// 2. `CFStringTransform` with `kCFStringTransformMandarinLatin` as a
///    fallback, for input the tokenizer yields nothing for.
///
/// Both paths are guarded twice, because ICU happily hands non-Chinese input
/// straight back: the source has to contain Han script, and the result has to
/// look like a transcription rather than a copy of the input. Measured in
/// phase 4 on the device: without those guards `asdf` typed into the Hanzi
/// field ended up as the Pinyin `asdf`.
///
/// Known limit, deliberately not solved: ICU has no word sense. It picks one
/// reading per word, which is wrong for polyphonic characters (多音字) in the
/// less common reading and for the neutral tone — `东西` comes back as
/// `dōngxī`, right for "east and west" and wrong for "thing". Word
/// segmentation improves the odds but guarantees nothing, which is exactly
/// why the Pinyin field stays editable and a hand-corrected value is never
/// overwritten silently. Details in
/// `docs/apple-frameworks.md` §10, Q6.
enum PinyinService {

    /// The Pinyin for `hanzi`, or an empty string when nothing can be derived.
    ///
    /// Never throws and never blocks: an empty result simply means the user
    /// fills the field in by hand.
    static func pinyin(for hanzi: String) -> String {
        let source = hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        // Neither path recognises "this is not Chinese" — they transliterate
        // what they can and pass the rest through. So the question is settled
        // here, before either of them runs.
        guard containsHanScript(source) else { return "" }

        let candidate = segmentedTranscription(of: source) ?? transliteration(of: source)
        guard isPlausibleTranscription(candidate, of: source) else { return "" }
        return candidate
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

    // MARK: - Path 1: word-segmented transcription

    private static func segmentedTranscription(of text: String) -> String? {
        let cfText = text as CFString
        let range = CFRangeMake(0, CFStringGetLength(cfText))
        // The Simplified Chinese locale is what makes the tokenizer split a
        // space-free string into words at all.
        let locale = Locale(identifier: "zh_Hans") as CFLocale
        guard let tokenizer = CFStringTokenizerCreate(
            nil, cfText, range, kCFStringTokenizerUnitWordBoundary, locale
        ) else {
            return nil
        }

        var words: [String] = []
        while CFStringTokenizerAdvanceToNextToken(tokenizer).rawValue != 0 {
            let attribute = CFStringTokenizerCopyCurrentTokenAttribute(
                tokenizer, kCFStringTokenizerAttributeLatinTranscription
            )
            guard let transcription = attribute as? String else { continue }
            let word = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
            // Punctuation does carry a transcription — "。" comes back as "｡".
            // Measured in phase 3; without this filter a sentence ended up as
            // "wǒ xiǎng chī diǎn dōngxī ｡". Pinyin is written without the
            // Chinese punctuation, so anything without a letter or digit goes.
            guard word.contains(where: { $0.isLetter || $0.isNumber }) else { continue }
            words.append(word)
        }

        return words.isEmpty ? nil : words.joined(separator: " ")
    }

    // MARK: - Path 2: plain transliteration

    private static func transliteration(of text: String) -> String {
        guard let mutable = CFStringCreateMutableCopy(nil, 0, text as CFString) else { return "" }
        guard CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false) else {
            return ""
        }
        let transformed = collapsingWhitespace(in: mutable as String)
        // Same filter as path 1, for the same reason.
        guard transformed.contains(where: { $0.isLetter || $0.isNumber }) else { return "" }
        return transformed
    }

    // MARK: - Shared

    /// Whether `candidate` is a transcription rather than the input handed
    /// back.
    ///
    /// The Han check above lets mixed input through, and the ideographic
    /// property covers a few scripts Mandarin transliteration knows nothing
    /// about, so the result is checked as well: it has to differ from the
    /// source and carry a cased letter. Han characters are letters but have
    /// no case, so a result that is merely a copy of the input fails here.
    private static func isPlausibleTranscription(_ candidate: String, of source: String) -> Bool {
        guard candidate.isEmpty == false, candidate != source else { return false }
        return candidate.contains { $0.isCased }
    }

    /// Single spaces between words, nothing at the ends. Tone marks stay —
    /// they are the whole point.
    private static func collapsingWhitespace(in text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
