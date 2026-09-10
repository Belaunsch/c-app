//
//  LearnCategorySelectionTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

/// Choosing what to practise, now that the categories are on the setup screen
/// instead of behind a filter sheet.
///
/// Two halves, and they are tested separately on purpose: the **selection**
/// rule is pure and lives in `LearnCategorySelection`, while what the
/// selection *means* for the pool belongs to `LearnSessionModel` and is
/// unchanged by this step. The tests below cross-check the second half
/// anyway — moving a control is exactly the kind of change that quietly
/// alters what it controls.
@MainActor
struct LearnCategorySelectionTests {

    let container: ModelContainer

    init() throws {
        container = try makeInMemoryContainer()
    }

    private var context: ModelContext { container.mainContext }

    private func makeTag(_ name: String) -> Tag {
        let tag = Tag(name: name)
        context.insert(tag)
        return tag
    }

    private func makeCard(_ german: String, type: CardType = .word, tags: [Tag] = []) -> Card {
        let card = Card(type: type, german: german, hanzi: "苹果", pinyin: "píngguǒ", tags: tags)
        context.insert(card)
        return card
    }

    private func key(_ name: String) -> String {
        TagNormalization.key(for: name)
    }

    // MARK: - The selection rule

    @Test("An empty selection is what Alle means — one state, not two")
    func emptyMeansEverything() {
        #expect(LearnCategorySelection.isEverything(LearnCategorySelection.everything))
        #expect(LearnCategorySelection.isEverything([]))
        #expect(LearnCategorySelection.isEverything(["essen"]) == false)

        // The trap this rules out: a separate `isAllSelected` flag beside the
        // set, which can disagree with it. Alle is *derived*, so "everything
        // selected and also nothing selected" has no representation.
        #expect(LearnCategorySelection.everything.isEmpty)
    }

    @Test("Toggling adds, toggling again removes")
    func togglingIsSymmetric() {
        let once = LearnCategorySelection.toggled([], key: "essen")
        #expect(once == ["essen"])
        #expect(LearnCategorySelection.isEverything(once) == false, "Alle stops being selected")

        let twice = LearnCategorySelection.toggled(once, key: "essen")
        #expect(twice.isEmpty)
        #expect(LearnCategorySelection.isEverything(twice), "and deselecting the last lands back on Alle")
    }

    @Test("Several categories can be selected at once")
    func multipleSelection() {
        var selection = LearnCategorySelection.everything
        selection = LearnCategorySelection.toggled(selection, key: "essen")
        selection = LearnCategorySelection.toggled(selection, key: "reisen")
        selection = LearnCategorySelection.toggled(selection, key: "alltag")

        #expect(selection == ["essen", "reisen", "alltag"])

        selection = LearnCategorySelection.toggled(selection, key: "reisen")
        #expect(selection == ["essen", "alltag"], "and removing one keeps the rest")
    }

    @Test("Tapping Alle clears whatever was selected")
    func alleClearsTheSelection() {
        // What the Alle chip's action does, in one step rather than by
        // deselecting each category: whatever was chosen, the answer becomes
        // "everything", and it is the same value an untouched screen starts
        // with — so there is no second way to be unrestricted.
        var selection: Set<String> = ["essen", "reisen", "alltag"]
        #expect(LearnCategorySelection.isEverything(selection) == false)

        selection = LearnCategorySelection.everything

        #expect(selection.isEmpty)
        #expect(LearnCategorySelection.isEverything(selection))
        #expect(selection == LearnCategorySelection.toggled(["essen"], key: "essen"),
                "and it is the same state deselecting the last category reaches")
    }

    // MARK: - What the selection does to the pool

    @Test("Several selected categories practise the union, not the intersection")
    func severalCategoriesAreOr() throws {
        let food = makeTag("Essen")
        let travel = makeTag("Reisen")
        let everyday = makeTag("Alltag")

        _ = makeCard("Apfel", tags: [food])
        _ = makeCard("Bahnhof", tags: [travel])
        _ = makeCard("Wasser", tags: [food, everyday])
        _ = makeCard("Uhr", tags: [everyday])
        try context.save()

        var selection = LearnCategorySelection.everything
        selection = LearnCategorySelection.toggled(selection, key: key("Essen"))
        selection = LearnCategorySelection.toggled(selection, key: key("Reisen"))

        let all = try context.fetch(FetchDescriptor<Card>())
        let pool = LearnSessionModel.poolCards(
            from: all,
            configuration: SessionConfiguration(cardType: .word, tagKeys: selection)
        )

        // Apfel carries Essen, Bahnhof carries Reisen, Wasser carries Essen
        // among others. Under AND only a card carrying both would qualify,
        // and none does — the pool would be empty.
        #expect(Set(pool.map(\.german)) == ["Apfel", "Bahnhof", "Wasser"])
        #expect(pool.contains { $0.german == "Uhr" } == false, "Alltag was not selected")
    }

    @Test("A card in two selected categories is in the pool once, not twice")
    func aCardInTwoSelectedCategoriesAppearsOnce() throws {
        // What the setup screen promises in words — "Geübt werden alle
        // Karten aus den ausgewählten Kategorien" — and the half of it that
        // a union can get wrong. The pool is filtered, not assembled per
        // category, so the card cannot be added twice; this is what would
        // notice if that ever changed and the weighting started seeing one
        // card as two.
        let food = makeTag("Essen")
        let travel = makeTag("Reisen")
        _ = makeCard("Reiseproviant", tags: [food, travel])
        _ = makeCard("Apfel", tags: [food])
        try context.save()

        let selection: Set<String> = [key("Essen"), key("Reisen")]
        let all = try context.fetch(FetchDescriptor<Card>())
        let pool = LearnSessionModel.poolCards(
            from: all,
            configuration: SessionConfiguration(cardType: .word, tagKeys: selection)
        )

        #expect(pool.count == 2)
        #expect(pool.filter { $0.german == "Reiseproviant" }.count == 1)
        #expect(Set(pool.map(\.german)) == ["Reiseproviant", "Apfel"])
    }

    @Test("No selected category means the whole pool of that type")
    func noSelectionMeansNoRestriction() throws {
        let food = makeTag("Essen")
        _ = makeCard("Apfel", tags: [food])
        _ = makeCard("Uhr", tags: [])
        _ = makeCard("Wo ist der Bahnhof?", type: .sentence, tags: [food])
        try context.save()

        let all = try context.fetch(FetchDescriptor<Card>())
        let selection = LearnCategorySelection.everything
        #expect(LearnCategorySelection.isEverything(selection))

        let pool = LearnSessionModel.poolCards(
            from: all,
            configuration: SessionConfiguration(cardType: .word, tagKeys: selection)
        )

        // Both words, including the one with no category at all — "Alle"
        // must not quietly mean "all categorised".
        #expect(Set(pool.map(\.german)) == ["Apfel", "Uhr"])
    }

    @Test("Alle still keeps words and sentences apart")
    func everythingDoesNotMixTypes() throws {
        let food = makeTag("Essen")
        _ = makeCard("Apfel", tags: [food])
        _ = makeCard("Wo ist der Bahnhof?", type: .sentence, tags: [food])
        try context.save()

        let all = try context.fetch(FetchDescriptor<Card>())

        for type in CardType.allCases {
            let pool = LearnSessionModel.poolCards(
                from: all,
                configuration: SessionConfiguration(cardType: type, tagKeys: .init())
            )
            #expect(pool.allSatisfy { $0.type == type }, "\(type.title)")
            #expect(pool.count == 1)
        }
    }

    @Test("Selecting every category is not the same code path as selecting none")
    func selectingAllCategoriesExplicitly() throws {
        // Worth pinning because the two look identical on screen once every
        // chip is lit: ticking all of them goes through the OR rule, while
        // Alle skips it. A card without any category is what tells them
        // apart, and the difference is intended — "alle Kategorien" and
        // "keine Einschränkung" are different questions.
        let food = makeTag("Essen")
        let travel = makeTag("Reisen")
        _ = makeCard("Apfel", tags: [food])
        _ = makeCard("Bahnhof", tags: [travel])
        _ = makeCard("Uhr", tags: [])
        try context.save()

        let all = try context.fetch(FetchDescriptor<Card>())
        let everyCategory: Set<String> = [key("Essen"), key("Reisen")]

        let explicit = LearnSessionModel.poolCards(
            from: all,
            configuration: SessionConfiguration(cardType: .word, tagKeys: everyCategory)
        )
        let unrestricted = LearnSessionModel.poolCards(
            from: all,
            configuration: SessionConfiguration(cardType: .word, tagKeys: LearnCategorySelection.everything)
        )

        #expect(Set(explicit.map(\.german)) == ["Apfel", "Bahnhof"])
        #expect(Set(unrestricted.map(\.german)) == ["Apfel", "Bahnhof", "Uhr"])
    }

    @Test("A category deleted while selected stops restricting the pool")
    func deletedCategoryDropsOutOfTheSelection() throws {
        // The setup screen keeps normalised keys, not references, so a
        // category deleted in the management screen would otherwise leave a
        // key behind that matches nothing and empties the session.
        let food = makeTag("Essen")
        _ = makeCard("Apfel", tags: [food])
        try context.save()

        let stale: Set<String> = [key("Essen"), key("Gelöscht")]
        let tags = try context.fetch(FetchDescriptor<Tag>())

        #expect(LearnSessionModel.activeTagKeys(stale, among: tags) == [key("Essen")])
        #expect(LearnSessionModel.activeTagKeys([key("Gelöscht")], among: tags).isEmpty,
                "and a selection of nothing but deleted categories becomes no restriction")
    }
}
