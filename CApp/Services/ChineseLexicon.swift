//
//  ChineseLexicon.swift
//  CApp
//

import Foundation
import OSLog

/// The bundled CC-CEDICT readings, and the two questions the Pinyin resolver
/// asks of them: what does this word read as, and is that reading the only
/// one?
///
/// Data, licence and the exact reductions made to the original are documented
/// in `CApp/Resources/ThirdParty/CC-CEDICT/SOURCE.md`. The short version: one
/// file maps each simplified headword with a single reading to that reading in
/// CC-CEDICT's tone-number notation, a second file lists the headwords that
/// have several readings. Nothing here interprets meaning — the ambiguous list
/// exists so the resolver knows when it must *not* pretend to be sure, which
/// is what stops it from cutting such a word into single characters.
///
/// Measured on the 2026-09-07 snapshot (Mac, release build): reading the file
/// 2 ms, building the dictionary 44 ms, 10 MB resident for 119.939 entries,
/// 80.000 lookups in 2,4 ms. Loading once and keeping it is therefore the
/// whole strategy — no database, no cache eviction, no index files.
@MainActor
final class ChineseLexicon {

    static let shared = ChineseLexicon()

    private var readings: [String: String] = [:]
    private var ambiguousWords: Set<String> = []
    /// Whether loading has been **attempted**, not whether it succeeded.
    ///
    /// A failed read is deliberately not retried: the file is either in the
    /// bundle or it is not, and retrying on every lookup would mean thousands
    /// of failed reads while the user types. The consequence is documented
    /// where it matters — an empty lexicon means every reading falls back to
    /// ICU and is marked for review, which is the same behaviour as for a
    /// word the lexicon does not know.
    private var hasAttemptedLoad = false

    /// The longest headword in the data, in characters. Read from the data
    /// rather than hard-coded, so the resolver's search window follows the
    /// lexicon instead of a guess. Measured: 19.
    ///
    /// Loads the data if that has not happened yet, like every other accessor
    /// here. It was a plain stored property first, and that was a real bug:
    /// the resolver reads the window *before* asking for a reading, so on the
    /// first lookup of a process the window was still 1 and no word longer
    /// than one character could match. The result depended on what had run
    /// before it.
    var longestHeadwordLength: Int {
        prepare()
        return storedLongestHeadwordLength
    }

    private var storedLongestHeadwordLength = 1

    /// `shared` is the one instance the app uses. Internal rather than
    /// private so a test can get an *unprepared* one: the ordering bug this
    /// class had could not be caught through the shared instance, because by
    /// the time a test ran, another one had already triggered the load.
    init() {}

    /// Loads the data if it has not been loaded yet. Idempotent and cheap to
    /// call again.
    ///
    /// Called from the editor's `task` so the work happens while the sheet is
    /// appearing, not when the user finishes typing.
    func prepare() {
        guard hasAttemptedLoad == false else { return }
        hasAttemptedLoad = true

        readings = Self.loadReadings()
        ambiguousWords = Self.loadAmbiguousWords()
        baseTones = Self.loadBaseTones()
        storedLongestHeadwordLength = readings.keys.reduce(1) { max($0, $1.count) }

        if readings.isEmpty {
            // Not fatal: the resolver falls back to ICU for everything and
            // marks it for review, which is exactly what it does for a word
            // the lexicon does not know.
            Self.logger.error("Lexicon is empty - Pinyin will fall back to ICU for every word")
        }
    }

    /// The single reading for `word`, or `nil` when the lexicon has no
    /// unambiguous answer — either because it does not know the word or
    /// because the word has several readings.
    ///
    /// Still in tone-number notation; `PinyinTone` turns it into tone marks.
    func reading(for word: String) -> String? {
        prepare()
        return readings[word]
    }

    /// The tone a syllable carries when it is **not** reduced, for a
    /// character whose reading here is the neutral tone.
    ///
    /// `一个` is `yi1 ge5` in the data and is spoken `yíge`, because the `一`
    /// rule is triggered by what `个` is underlyingly — a fourth tone — and
    /// not by the neutral tone it surfaces with. Without this the app said
    /// `yīge`, which the phase-6.5 accuracy pass listed as its
    /// highest-priority error.
    ///
    /// The answer comes from `cedict-base-tones.txt`, a derivation of the
    /// readings file that ships beside it: the same character appears with a
    /// full tone in other headwords — `一个人` gives `ge4` — and the file
    /// records the dominant one. Derived offline rather than counted at
    /// launch because the census over every headword measured **314 ms**, and
    /// this class is main-actor-bound: paying that while the editor sheet
    /// appears is exactly the stutter the phase forbids.
    ///
    /// `nil` means "not decidable", and every caller has to treat that as
    /// "apply no rule" rather than picking something. 131 of the 538 reduced
    /// syllables in the snapshot land there: no full reading at all, none
    /// dominant enough, or too few occurrences to call it dominant.
    func baseTone(ofSyllable syllable: String, character: Character) -> Int? {
        prepare()
        return baseTones[Key(character: character, syllable: syllable.lowercased())]
    }

    /// One character in one reading. The syllable is part of the key because
    /// a character with two readings has two base tones, and mixing them
    /// would answer for the wrong one.
    private struct Key: Hashable {
        let character: Character
        let syllable: String
    }

    private var baseTones: [Key: Int] = [:]

    private static func loadBaseTones() -> [Key: Int] {
        guard let text = bundledText(named: "cedict-base-tones") else { return [:] }
        var tones: [Key: Int] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: true)
        where line.hasPrefix("#") == false {
            let fields = line.split(separator: "\t")
            guard fields.count >= 3,
                  let character = fields[0].first, fields[0].count == 1,
                  let tone = Int(fields[2]), (1...4).contains(tone) else { continue }
            tones[Key(character: character, syllable: String(fields[1]))] = tone
        }
        return tones
    }

    /// Whether `word` is a headword with several different readings.
    ///
    /// Separate from `reading(for:)` returning `nil` on purpose: "several
    /// readings, we must not guess" and "never heard of it" are different
    /// situations, and the resolver reports them differently.
    func isAmbiguous(_ word: String) -> Bool {
        prepare()
        return ambiguousWords.contains(word)
    }

    // MARK: - Loading

    private static func loadReadings() -> [String: String] {
        guard let text = bundledText(named: "cedict-readings") else { return [:] }

        var readings: [String: String] = [:]
        // The file has one line per headword; reserving up front avoids
        // rehashing the dictionary a dozen times while filling it.
        readings.reserveCapacity(130_000)
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard line.hasPrefix("#") == false,
                  let separator = line.firstIndex(of: "\t") else { continue }
            let word = String(line[line.startIndex..<separator])
            readings[word] = String(line[line.index(after: separator)...])
        }
        return readings
    }

    private static func loadAmbiguousWords() -> Set<String> {
        guard let text = bundledText(named: "cedict-ambiguous") else { return [] }
        var words: Set<String> = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true)
        where line.hasPrefix("#") == false {
            words.insert(String(line))
        }
        return words
    }

    private static func bundledText(named name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else {
            logger.error("Lexicon file \(name, privacy: .public).txt is not in the bundle")
            return nil
        }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            logger.error("Lexicon file \(name, privacy: .public).txt unreadable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static let logger = Logger(subsystem: "de.belaunsch.CApp", category: "lexicon")
}
