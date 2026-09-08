//
//  ChineseLexiconTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// The lexicon itself: does it answer, and does it know when it must not.
@MainActor
struct ChineseLexiconTests {

    @Test("The bundled data is actually there")
    func dataIsBundled() {
        // A silent empty lexicon would not fail any other test loudly — every
        // reading would just quietly come from ICU again. So this is checked
        // on its own.
        #expect(ChineseLexicon.shared.reading(for: "苹果") != nil)
        #expect(ChineseLexicon.shared.reading(for: "谢谢") == "xie4 xie5")
    }

    @Test("The search window is known before anything else is asked")
    func searchWindowIsAvailableImmediately() {
        // Regression test for an ordering bug: the resolver reads this window
        // *before* it asks for a reading, and the property used to be a plain
        // stored value that only got its real size once something else had
        // triggered the load. Until then the window was 1, so no word longer
        // than a single character could ever match and the reading silently
        // came from ICU instead.
        //
        // Deliberately on a fresh instance, not on `shared`: the shared one
        // is process-wide, so whichever test touched it first would have
        // loaded it and this assertion would pass no matter what. That is
        // exactly how the bug slipped through in the first place.
        let untouched = ChineseLexicon()
        #expect(untouched.longestHeadwordLength == 19, "measured in the snapshot")

        // Every accessor has to load on its own. Checked one by one on fresh
        // instances, because through `shared` whichever test ran first would
        // have loaded it and all of these would pass regardless.
        #expect(ChineseLexicon().reading(for: "火车站") == "huo3 che1 zhan4")
        #expect(ChineseLexicon().isAmbiguous("东西"))
    }

    @Test("A word with several readings has none, and says so")
    func ambiguousWordHasNoSingleReading() {
        // The two questions are deliberately separate: "I do not know this
        // word" and "I know it has two readings and will not guess" lead to
        // the same fallback but are not the same statement.
        #expect(ChineseLexicon.shared.isAmbiguous("东西"))
        #expect(ChineseLexicon.shared.reading(for: "东西") == nil)

        for word in ["行", "长", "得", "了", "好", "多少"] {
            #expect(ChineseLexicon.shared.isAmbiguous(word), "\(word) has several readings")
        }
    }

    @Test("An unknown word is not the same as an ambiguous one")
    func unknownWordIsNotAmbiguous() {
        #expect(ChineseLexicon.shared.reading(for: "苹果苹果苹果") == nil)
        #expect(ChineseLexicon.shared.isAmbiguous("苹果苹果苹果") == false)
    }

    @Test("Phrases are in the lexicon, not just single words")
    func phrasesAreStored() {
        // This is what resolves ambiguity from context, so it needs to hold.
        #expect(ChineseLexicon.shared.reading(for: "买东西") == "mai3 dong1 xi5")
        #expect(ChineseLexicon.shared.reading(for: "东西南北") == "dong1 xi1 nan2 bei3")
        #expect(ChineseLexicon.shared.reading(for: "早上好") == "zao3 shang5 hao3")
    }

    @Test("Proper nouns keep their capital, common words do not")
    func capitalisationFollowsTheData() {
        // 苹果 has two entries, `Ping2 guo3` for the company and `ping2 guo3`
        // for the fruit. They read the same, so the word is unambiguous, and
        // the generator picks the lower-case one — a learner's card is about
        // the fruit. 北京 exists only as a proper noun and keeps its capital.
        #expect(ChineseLexicon.shared.reading(for: "苹果") == "ping2 guo3")
        #expect(ChineseLexicon.shared.reading(for: "北京") == "Bei3 jing1")
    }

    @Test("Preparing twice is harmless")
    func prepareIsIdempotent() {
        ChineseLexicon.shared.prepare()
        ChineseLexicon.shared.prepare()
        #expect(ChineseLexicon.shared.reading(for: "水") == "shui3")
    }
}
