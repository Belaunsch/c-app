//
//  PinyinTone.swift
//  CApp
//

import Foundation

/// Turns CC-CEDICT's tone-number notation into Hanyu Pinyin with tone marks.
///
/// `dong1 xi5` becomes `dōngxi`. Pure and deterministic — no ICU, no locale,
/// no state — because it is the one step where correctness is fully decidable
/// from the input, and this is where the neutral tone comes from that ICU
/// never produces.
///
/// `nonisolated` for the same reason `CardType` and `LearningStatus` are:
/// the target defaults to main-actor isolation, and a pure function has no
/// business requiring an actor. It also keeps its tests free of an isolation
/// they do not need.
nonisolated enum PinyinTone {

    /// The syllables of one dictionary entry, joined into one word.
    ///
    /// CC-CEDICT separates every syllable with a space, including inside a
    /// single word (`ping2 guo3`). Pinyin is written without those spaces
    /// (`píngguǒ`), so they are dropped — with two exceptions that are
    /// punctuation rather than syllables: `,` and `·`, which CC-CEDICT uses
    /// in enumerations and transliterated names.
    static func marked(_ numbered: String) -> String {
        var result = ""
        for syllable in numbered.split(separator: " ") {
            let piece = String(syllable)
            if piece == "," {
                result += ", "
                continue
            }
            if piece == "·" {
                result += "·"
                continue
            }
            result += marked(syllable: piece)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// One syllable: `guo3` becomes `guǒ`, `nu:e4` becomes `nüè`, `xi5`
    /// becomes `xi`.
    ///
    /// Anything that does not look like a syllable plus tone digit is handed
    /// back unchanged. CC-CEDICT contains such fields — `11 Qu1` for `11区`,
    /// and a handful of malformed ones — and mangling them would be worse
    /// than passing them through.
    static func marked(syllable: String) -> String {
        let expanded = syllable.replacingOccurrences(of: "u:", with: "ü")
            .replacingOccurrences(of: "U:", with: "Ü")

        guard let last = expanded.last, let tone = last.wholeNumberValue,
              (1...5).contains(tone) else {
            return expanded
        }
        let letters = String(expanded.dropLast())
        guard letters.isEmpty == false,
              letters.allSatisfy({ $0.isLetter }) else {
            return expanded
        }
        // The neutral tone carries no mark. That is the whole point of tone 5
        // in the data: `xie4 xie5` is `xièxie`, not `xièxiè`.
        guard tone != 5 else { return letters }
        guard let index = markedVowelIndex(in: letters) else { return letters }

        var characters = Array(letters)
        characters[index] = marked(vowel: characters[index], tone: tone)
        return String(characters)
    }

    // MARK: - Placement

    /// Which vowel carries the mark.
    ///
    /// The standard rule, in this order: an `a`, `o` or `e` takes it; in `iu`
    /// the `u` takes it and in `ui` the `i`; otherwise the only vowel does.
    /// `iao` has an `a` and so is covered by the first rule, `üe` by the `e`.
    private static func markedVowelIndex(in letters: String) -> Int? {
        let lowercased = Array(letters.lowercased())

        for vowel in ["a", "o", "e"] {
            if let index = lowercased.firstIndex(of: Character(vowel)) {
                return index
            }
        }
        if let index = indexOfSecondVowel(in: lowercased, pair: ["i", "u"]) { return index }
        if let index = indexOfSecondVowel(in: lowercased, pair: ["u", "i"]) { return index }

        return lowercased.lastIndex { vowels.contains($0) }
    }

    /// The index of the second letter of `pair`, if the two appear in that
    /// order next to each other.
    private static func indexOfSecondVowel(in letters: [Character], pair: [Character]) -> Int? {
        guard letters.count >= 2 else { return nil }
        for index in 0..<(letters.count - 1) where letters[index] == pair[0] && letters[index + 1] == pair[1] {
            return index + 1
        }
        return nil
    }

    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "ü"]

    // MARK: - The marks themselves

    private static func marked(vowel: Character, tone: Int) -> Character {
        let lowercase = Character(vowel.lowercased())
        guard let marks = marks[lowercase], tone >= 1, tone <= marks.count else { return vowel }
        let marked = marks[tone - 1]
        return vowel.isUppercase ? Character(marked.uppercased()) : marked
    }

    /// Tones 1 to 4 per vowel. Precomposed characters rather than combining
    /// diacritics, so a comparison against a literal in a test succeeds
    /// without normalising first.
    private static let marks: [Character: [Character]] = [
        "a": ["ā", "á", "ǎ", "à"],
        "e": ["ē", "é", "ě", "è"],
        "i": ["ī", "í", "ǐ", "ì"],
        "o": ["ō", "ó", "ǒ", "ò"],
        "u": ["ū", "ú", "ǔ", "ù"],
        "ü": ["ǖ", "ǘ", "ǚ", "ǜ"],
    ]
}
