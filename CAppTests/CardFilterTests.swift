//
//  CardFilterTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

@MainActor
struct CardFilterTests {

    /// The container is a stored property on purpose.
    ///
    /// A swift-testing suite is instantiated per test, so this keeps the
    /// container alive for the whole test. That matters: SwiftData model
    /// objects must not outlive their container — every property access on a
    /// card whose container has been released trips an assertion inside the
    /// generated accessor and takes the test process down with it.
    let container: ModelContainer
    let cards: [Card]

    /// A small fixture covering both card types, several statuses and tags.
    init() throws {
        container = try makeInMemoryContainer()
        let context = container.mainContext

        let food = Tag(name: "Essen")
        let travel = Tag(name: "Reisen")
        let everyday = Tag(name: "Alltag")
        for tag in [food, travel, everyday] { context.insert(tag) }

        cards = [
            Card(type: .word, german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ",
                 status: .secure, tags: [food]),
            Card(type: .word, german: "Wasser", hanzi: "水", pinyin: "shuǐ",
                 status: .weak, tags: [food, everyday]),
            Card(type: .word, german: "Flughafen", hanzi: "机场", pinyin: "jīchǎng",
                 status: .weak, tags: [travel]),
            Card(type: .sentence, german: "Guten Morgen!", hanzi: "早上好！",
                 pinyin: "zǎoshang hǎo", status: .good, tags: [everyday]),
            Card(type: .sentence, german: "Wo ist der Bahnhof?", hanzi: "火车站在哪里？",
                 pinyin: "huǒchēzhàn zài nǎlǐ", status: .medium, tags: [travel]),
        ]
        for card in cards { context.insert(card) }
        try context.save()
    }

    private func germanTexts(_ cards: [Card]) -> Set<String> {
        Set(cards.map(\.german))
    }

    // MARK: - Card type

    @Test("Only cards of the requested type are returned")
    func filterKeepsWordsAndSentencesApart() throws {

        let words = CardFilter.apply(to: cards, type: .word)
        let sentences = CardFilter.apply(to: cards, type: .sentence)

        #expect(germanTexts(words) == ["Apfel", "Wasser", "Flughafen"])
        #expect(germanTexts(sentences) == ["Guten Morgen!", "Wo ist der Bahnhof?"])
        #expect(words.allSatisfy { $0.type == .word })
        #expect(sentences.allSatisfy { $0.type == .sentence })
    }

    // MARK: - Search

    @Test("Search matches the German text")
    func searchMatchesGerman() throws {
        let result = CardFilter.apply(to: cards, type: .word, searchText: "Apfel")
        #expect(germanTexts(result) == ["Apfel"])
    }

    @Test("Search matches Hanzi")
    func searchMatchesHanzi() throws {
        let result = CardFilter.apply(to: cards, type: .word, searchText: "机场")
        #expect(germanTexts(result) == ["Flughafen"])
    }

    @Test("Search matches Pinyin")
    func searchMatchesPinyin() throws {
        let result = CardFilter.apply(to: cards, type: .word, searchText: "shuǐ")
        #expect(germanTexts(result) == ["Wasser"])
    }

    @Test("Search finds Pinyin typed without tone marks")
    func searchIgnoresToneMarks() throws {
        // The whole point of a diacritic-insensitive search: nobody wants to
        // hunt for "ǒ" on the keyboard to find a card.
        let result = CardFilter.apply(to: cards, type: .word, searchText: "pingguo")
        #expect(germanTexts(result) == ["Apfel"])
    }

    @Test("Search ignores casing")
    func searchIgnoresCasing() throws {
        let result = CardFilter.apply(to: cards, type: .word, searchText: "aPFEL")
        #expect(germanTexts(result) == ["Apfel"])
    }

    @Test("A blank search term filters nothing away")
    func blankSearchKeepsEverything() throws {
        let result = CardFilter.apply(to: cards, type: .word, searchText: "   ")
        #expect(result.count == 3)
    }

    @Test("A search without matches returns nothing")
    func searchWithoutMatchesReturnsNothing() throws {
        let result = CardFilter.apply(to: cards, type: .word, searchText: "Fahrrad")
        #expect(result.isEmpty)
    }

    // MARK: - Status

    @Test("The status filter returns only that status")
    func statusFilterNarrowsToOneStatus() throws {
        let result = CardFilter.apply(to: cards, type: .word, status: .weak)
        #expect(germanTexts(result) == ["Wasser", "Flughafen"])
    }

    @Test("No status filter keeps every status")
    func missingStatusFilterKeepsEverything() throws {
        let result = CardFilter.apply(to: cards, type: .word, status: nil)
        #expect(result.count == 3)
    }

    // MARK: - Tags

    @Test("A single tag filter returns the cards carrying it")
    func singleTagFilter() throws {
        let result = CardFilter.apply(to: cards, type: .word, tagKeys: ["essen"])
        #expect(germanTexts(result) == ["Apfel", "Wasser"])
    }

    @Test("Several tags are combined with OR, not AND")
    func severalTagsNeedOnlyOneOfThem() throws {
        // A32, replacing A12: ticking a second category **widens**. "Apfel"
        // carries only Essen and "Wasser" carries both, so AND would return
        // just "Wasser" — which was the old behaviour and the reason for the
        // change.
        let result = CardFilter.apply(to: cards, type: .word, tagKeys: ["essen", "alltag"])
        #expect(germanTexts(result) == ["Apfel", "Wasser"])
    }

    @Test("Two categories no card shares still return the union")
    func disjointTagsReturnTheUnion() throws {
        // Under AND this was empty, because no word is both food and travel.
        // That emptiness is exactly what made the old semantics unusable with
        // a handful of cards per category.
        let result = CardFilter.apply(to: cards, type: .word, tagKeys: ["essen", "reisen"])
        #expect(germanTexts(result) == ["Apfel", "Wasser", "Flughafen"])
    }

    @Test("A category nothing carries returns nothing")
    func unknownTagReturnsNothing() throws {
        // The OR group still narrows against the *absence* of a match — it
        // is not a filter that gives up when it finds nothing.
        #expect(CardFilter.apply(to: cards, type: .word, tagKeys: ["gibtsnicht"]).isEmpty)
    }

    @Test("Tag filtering ignores casing, because it compares normalized keys")
    func tagFilterIgnoresCasing() throws {
        let result = CardFilter.apply(
            to: cards,
            type: .word,
            tagKeys: [TagNormalization.key(for: "  ESSEN ")]
        )
        #expect(germanTexts(result) == ["Apfel", "Wasser"])
    }

    @Test("No tag filter keeps untagged cards too")
    func missingTagFilterKeepsUntaggedCards() throws {
        // Uses the suite's container on purpose. A local one of the same name
        // would shadow the stored property and quietly bypass the rule that
        // keeps it alive — see the comment on `container`.
        let context = container.mainContext
        let untagged = Card(type: .word, german: "Tee", hanzi: "茶")
        context.insert(untagged)
        try context.save()

        let result = CardFilter.apply(to: cards + [untagged], type: .word)
        #expect(result.contains { $0.german == "Tee" })
        #expect(result.count == 4)
    }

    @Test("A term with two matches returns both")
    func searchReturnsEveryMatch() throws {
        // Every other search test expects exactly one hit, which would not
        // catch a filter that stops after the first match.
        let result = CardFilter.apply(to: cards, type: .word, searchText: "a")
        #expect(germanTexts(result) == ["Apfel", "Wasser", "Flughafen"])
    }

    @Test("Search works on sentences as well")
    func searchWorksOnSentences() throws {
        let result = CardFilter.apply(to: cards, type: .sentence, searchText: "bahnhof")
        #expect(germanTexts(result) == ["Wo ist der Bahnhof?"])
    }

    @Test("An empty input list stays empty")
    func emptyInputStaysEmpty() throws {
        #expect(CardFilter.apply(to: [], type: .word).isEmpty)
        #expect(CardFilter.apply(to: [], type: .word, searchText: "x", tagKeys: ["y"], status: .good).isEmpty)
    }

    // MARK: - Combinations

    @Test("Type, search, tag and status narrow the result together")
    func allCriteriaCombine() throws {

        let result = CardFilter.apply(
            to: cards,
            type: .word,
            searchText: "wa",
            tagKeys: ["essen"],
            status: .weak
        )

        #expect(germanTexts(result) == ["Wasser"])
    }

    @Test("The OR category group still sits inside an AND chain")
    func categoryGroupCombinesWithTheOtherDimensionsByAnd() throws {
        // The half of A32 that is easy to get wrong: categories widen among
        // themselves, and the result is then narrowed by everything else.
        // Essen or Reisen alone gives Apfel, Wasser and Flughafen.
        let widened = CardFilter.apply(to: cards, type: .word, tagKeys: ["essen", "reisen"])
        #expect(germanTexts(widened) == ["Apfel", "Wasser", "Flughafen"])

        // Status narrows it: only Wasser and Flughafen are weak.
        let byStatus = CardFilter.apply(
            to: cards, type: .word, tagKeys: ["essen", "reisen"], status: .weak
        )
        #expect(germanTexts(byStatus) == ["Wasser", "Flughafen"])

        // Search narrows it further, down to one.
        let bySearch = CardFilter.apply(
            to: cards, type: .word, searchText: "flug", tagKeys: ["essen", "reisen"], status: .weak
        )
        #expect(germanTexts(bySearch) == ["Flughafen"])

        // And the type still separates: the travel sentence is not pulled in
        // by the widened category group.
        let sentences = CardFilter.apply(to: cards, type: .sentence, tagKeys: ["essen", "reisen"])
        #expect(germanTexts(sentences) == ["Wo ist der Bahnhof?"])
    }

    @Test("A single mismatching criterion empties the result")
    func oneMismatchingCriterionEmptiesTheResult() throws {

        // "Wasser" matches search and tag, but its status is weak, not secure.
        let result = CardFilter.apply(
            to: cards,
            type: .word,
            searchText: "wa",
            tagKeys: ["essen"],
            status: .secure
        )

        #expect(result.isEmpty)
    }

    @Test("Filters never leak across card types")
    func filtersNeverLeakAcrossTypes() throws {

        // "Alltag" exists on a word and on a sentence.
        let words = CardFilter.apply(to: cards, type: .word, tagKeys: ["alltag"])
        let sentences = CardFilter.apply(to: cards, type: .sentence, tagKeys: ["alltag"])

        #expect(germanTexts(words) == ["Wasser"])
        #expect(germanTexts(sentences) == ["Guten Morgen!"])
    }
}
