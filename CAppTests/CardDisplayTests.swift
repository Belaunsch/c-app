//
//  CardDisplayTests.swift
//  CAppTests
//

import Testing
@testable import CApp

/// These strings end up on screen ("Noch keine Wörter", the status filter, the
/// editor picker). A wrong value would fail silently, so it gets pinned the
/// same way the tab titles are.
struct CardDisplayTests {

    @Test("Card types are named in German, plural and singular")
    func cardTypeTitlesAreGerman() {
        #expect(CardType.word.title == "Wörter")
        #expect(CardType.sentence.title == "Sätze")
        #expect(CardType.word.singularTitle == "Wort")
        #expect(CardType.sentence.singularTitle == "Satz")
    }

    @Test("Every learning status has a German name")
    func learningStatusTitlesAreGerman() {
        #expect(LearningStatus.new.title == "Neu")
        #expect(LearningStatus.weak.title == "Schwach")
        #expect(LearningStatus.medium.title == "Mittel")
        #expect(LearningStatus.good.title == "Gut")
        #expect(LearningStatus.secure.title == "Sicher")
    }

    @Test("Every status name is distinct, so the filter menu is unambiguous")
    func statusTitlesAreDistinct() {
        let titles = LearningStatus.allCases.map(\.title)
        #expect(Set(titles).count == LearningStatus.allCases.count)
    }
}
