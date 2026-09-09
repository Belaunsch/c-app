//
//  ChineseLexiconBaseToneTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// The base tones of reduced syllables, derived from the bundled readings by
/// `tools/generate-cedict-base-tones.py`.
///
/// This is what makes `一个` come out as `yíge`: the `一` rule needs the tone
/// `个` carries underneath its reduction, and that is nowhere in the readings
/// file because `个` alone is an ambiguous headword. The derivation counts the
/// tones each syllable takes across every pure-Han headword and keeps the
/// dominant one.
@MainActor
struct ChineseLexiconBaseToneTests {

    @Test("The bundled base tones are there and are the dominant ones")
    func baseTonesAreLoaded() {
        let lexicon = ChineseLexicon.shared

        // `个` is the case the accuracy pass was about: `ge4` in 86 headwords,
        // `ge5` in 43, `ge3` in exactly one. Requiring a *unique* full tone
        // would answer `nil` here, which is why the threshold is dominance
        // and not uniqueness.
        #expect(lexicon.baseTone(ofSyllable: "ge", character: "个") == 4)
        #expect(lexicon.baseTone(ofSyllable: "zi", character: "子") == 3)
        #expect(lexicon.baseTone(ofSyllable: "shang", character: "上") == 4)
        #expect(lexicon.baseTone(ofSyllable: "guo", character: "过") == 4)
    }

    @Test("A dominant tone resting on a handful of words is not evidence")
    func thinEvidenceIsRefused() {
        // `们` used to answer 2 here, and the review showed where that came
        // from: three headwords, all the place name 图们 — not a full tone of
        // the plural suffix at all. Dominance alone was not enough, so the
        // derivation now also requires five occurrences. That dropped 59
        // syllables whose "dominant" tone was an accident, and no reachable
        // case with it.
        #expect(ChineseLexicon.shared.baseTone(ofSyllable: "men", character: "们") == nil)
    }

    @Test("The syllable is asked for the way the resolver spells it")
    func syllableUsesTheExpandedSpelling() {
        // CC-CEDICT writes `nu:` for `nü`, and `PinyinSyllable` expands that
        // **before** looking the base tone up. The derivation has to store
        // the expanded form or the row is unreachable — it was, for exactly
        // one line, until the review found it.
        #expect(ChineseLexicon.shared.baseTone(ofSyllable: "nü", character: "女") == 3)
        #expect(ChineseLexicon.shared.baseTone(ofSyllable: "nu:", character: "女") == nil)
    }

    @Test("Case does not decide the answer")
    func lookupIgnoresCase() {
        #expect(ChineseLexicon.shared.baseTone(ofSyllable: "GE", character: "个") == 4)
    }

    @Test("The syllable is part of the question, not just the character")
    func syllableIsPartOfTheKey() {
        // A character with two readings has two base tones, and answering for
        // the wrong one would be worse than not answering.
        #expect(ChineseLexicon.shared.baseTone(ofSyllable: "nonsense", character: "个") == nil)
    }

    @Test("An unestablishable base tone answers nil, not a guess")
    func undecidableAnswersNil() {
        // 131 of the 538 reduced syllables get no base tone: no full reading
        // at all, none dominant enough, or too few occurrences to call it
        // dominant. The particles are the clearest group.
        let lexicon = ChineseLexicon.shared
        #expect(lexicon.baseTone(ofSyllable: "me", character: "么") == nil)
        #expect(lexicon.baseTone(ofSyllable: "de", character: "的") == nil)
        #expect(lexicon.baseTone(ofSyllable: "xyz", character: "苹") == nil)

        // And a syllable that clears the evidence bar but not the dominance
        // bar: `处/chu` is a fourth tone in 98 of 190 full-tone occurrences,
        // 52 %. Without this the dominance threshold had no counter-probe at
        // all — lowering it to 0.5 and regenerating left the whole suite
        // green. Found by the audit.
        #expect(lexicon.baseTone(ofSyllable: "chu", character: "处") == nil)
    }
}
