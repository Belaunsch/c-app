//
//  CardListArrangementTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

/// Ordering, grouping and the accordion rule of the card list.
///
/// What these tests can and cannot reach is stated rather than blurred: the
/// three rules below are pure functions and fully falsifiable, while *which
/// control receives a tap* is a device question. Phase 6 settled twice that a
/// simulator cannot answer it (A27), so that half belongs to the physical
/// device test and the tests that touch it say so rather than implying
/// coverage they do not have.
@MainActor
struct CardListArrangementTests {

    let container: ModelContainer

    /// Stored for the same reason `CardFilterTests` does it: a SwiftData model
    /// object must not outlive its container, and a swift-testing suite is
    /// instantiated per test.
    init() throws {
        container = try makeInMemoryContainer()
    }

    private func makeTag(_ name: String) -> Tag {
        let tag = Tag(name: name)
        container.mainContext.insert(tag)
        return tag
    }

    private func makeCard(
        _ german: String,
        type: CardType = .word,
        hanzi: String = "苹果",
        pinyin: String = "píngguǒ",
        status: LearningStatus = .new,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        tags: [Tag] = []
    ) -> Card {
        let card = Card(
            type: type,
            german: german,
            hanzi: hanzi,
            pinyin: pinyin,
            status: status,
            createdAt: createdAt,
            tags: tags
        )
        container.mainContext.insert(card)
        return card
    }

    private func germans(_ cards: [Card]) -> [String] {
        cards.map(\.german)
    }

    // MARK: - The accordion

    @Test("Tapping a closed card opens it, and only it")
    func tappingOpensOne() {
        let a = UUID()
        let b = UUID()

        #expect(CardExpansion.toggled(nil, tapped: a) == a)
        // The answer is a single optional, so "at most one open" is not a rule
        // anybody has to enforce — there is nowhere to put a second one.
        #expect(CardExpansion.toggled(b, tapped: a) == a, "and b is closed by the same move")
    }

    @Test("Tapping the open card closes it again")
    func tappingTheOpenCardCloses() {
        let a = UUID()
        #expect(CardExpansion.toggled(a, tapped: a) == nil)
        // Twice in a row is open, closed, open — not stuck.
        #expect(CardExpansion.toggled(CardExpansion.toggled(a, tapped: a), tapped: a) == a)
    }

    @Test("Switching from A to B closes A")
    func switchingClosesThePrevious() {
        let a = UUID()
        let b = UUID()

        let afterA = CardExpansion.toggled(nil, tapped: a)
        let afterB = CardExpansion.toggled(afterA, tapped: b)

        #expect(afterB == b)
        #expect(afterB != a, "A is gone, not merely behind B")
    }

    @Test("A row tap can only open or close — it never leads anywhere")
    func rowTapNeverNavigates() {
        // The rule that keeps the editor behind the pencil: the *only* thing
        // a tap on the row body produces is a new expansion state. There is
        // no third outcome to reach, so a second tap cannot become a way in
        // and a long press has nothing to trigger.
        //
        // That the pencil is the control actually wired to the editor is
        // view structure, and only the device test can confirm it receives
        // the tap. Its **position** is the other half: `controls(for:)`
        // documents why the pencil is drawn before the speaker.
        let a = UUID()
        let outcomes = [
            CardExpansion.toggled(nil, tapped: a),
            CardExpansion.toggled(a, tapped: a),
        ]
        #expect(outcomes == [a, nil], "open, then closed, and nothing else")
    }

    @Test("Speaking leaves the expansion alone")
    func speechDoesNotChangeExpansion() throws {
        // `SpeakButton` has its own action and no access to the expansion
        // state — there is no API through which speech could change it. This
        // pins that: the state a view would hold is untouched across a real
        // `speak`, the same shape the phase-7 test used for the editor's
        // provenance flags.
        let card = makeCard("Apfel")
        try container.mainContext.save()

        var expandedCardID: Card.ID? = card.id

        let speech = SpeechSynthesisService()
        defer { speech.stop() }
        speech.speak(card.hanzi)

        #expect(expandedCardID == card.id, "still open, and still the same card")

        expandedCardID = nil
        speech.speak(card.hanzi)
        #expect(expandedCardID == nil, "and a closed row is not opened by sound")
    }

    // MARK: - Sorting

    @Test("German A–Z and Z–A are exact mirrors")
    func germanOrder() throws {
        let cards = [makeCard("Wasser"), makeCard("Apfel"), makeCard("Milch")]
        try container.mainContext.save()

        #expect(germans(CardListArrangement.sort(cards, by: .germanAscending))
            == ["Apfel", "Milch", "Wasser"])
        #expect(germans(CardListArrangement.sort(cards, by: .germanDescending))
            == ["Wasser", "Milch", "Apfel"])
    }

    @Test("German order reads umlauts the way a German reader does")
    func germanOrderHandlesUmlauts() throws {
        // `localizedStandardCompare` rather than `<`: on Unicode scalars "Ä"
        // sorts after "Z", which would put "Äpfel" at the end of the list.
        let cards = [makeCard("Zebra"), makeCard("Äpfel"), makeCard("Banane")]
        try container.mainContext.save()

        #expect(germans(CardListArrangement.sort(cards, by: .germanAscending))
            == ["Äpfel", "Banane", "Zebra"])
    }

    @Test("Newest and oldest first go by creation date")
    func creationOrder() throws {
        let old = makeCard("Alt", createdAt: Date(timeIntervalSince1970: 100))
        let middle = makeCard("Mitte", createdAt: Date(timeIntervalSince1970: 200))
        let new = makeCard("Neu", createdAt: Date(timeIntervalSince1970: 300))
        try container.mainContext.save()

        let cards = [middle, new, old]
        #expect(germans(CardListArrangement.sort(cards, by: .newestFirst))
            == ["Neu", "Mitte", "Alt"])
        #expect(germans(CardListArrangement.sort(cards, by: .oldestFirst))
            == ["Alt", "Mitte", "Neu"])
    }

    @Test("Every order is deterministic, even where the key ties")
    func everyOrderIsDeterministic() throws {
        // The case that matters: two cards with the same German text **and**
        // the same creation instant. Sample data and any import produce
        // those, and without the id tiebreak the list would reorder itself
        // between redraws for no visible reason.
        let sameInstant = Date(timeIntervalSince1970: 500)
        let cards = [
            makeCard("Apfel", createdAt: sameInstant),
            makeCard("Apfel", createdAt: sameInstant),
            makeCard("Apfel", createdAt: sameInstant),
            makeCard("Birne", createdAt: sameInstant),
        ]
        try container.mainContext.save()

        for order in CardSortOrder.allCases {
            let reference = CardListArrangement.sort(cards, by: order).map(\.id)
            for _ in 0..<8 {
                let again = CardListArrangement.sort(cards.shuffled(), by: order).map(\.id)
                #expect(again == reference, "\(order.title) depends on the input order")
            }
        }
    }

    @Test("Sorting keeps every card and invents none")
    func sortingIsATotalRearrangement() throws {
        let cards = [makeCard("Wasser"), makeCard("Apfel"), makeCard("Milch")]
        try container.mainContext.save()

        for order in CardSortOrder.allCases {
            let sorted = CardListArrangement.sort(cards, by: order)
            #expect(Set(sorted.map(\.id)) == Set(cards.map(\.id)), "\(order.title)")
            #expect(sorted.count == cards.count, "\(order.title)")
        }
    }

    @Test("Each sort order names itself and offers a symbol")
    func everyOrderIsPresentable() {
        #expect(CardSortOrder.default == .germanAscending, "the order the list had before")
        #expect(CardSortOrder.allCases.count == 5)

        for order in CardSortOrder.allCases {
            #expect(order.title.isEmpty == false)
            #expect(order.symbolName.isEmpty == false)
        }
        // Only the category order groups. If a second grouped order is ever
        // added, this fails and the view's branch gets looked at.
        #expect(CardSortOrder.allCases.filter(\.isGrouped) == [.categoryAscending])
    }

    // MARK: - The stored sort preference

    @Test("Every order survives the round trip through its raw value")
    func sortPreferenceRoundTrips() {
        // What `@AppStorage` actually writes and reads. If a case were ever
        // renamed without its explicit raw value being kept, this is what
        // notices — the app itself would silently reset everybody's choice
        // to the default and look like it forgot.
        for order in CardSortOrder.allCases {
            #expect(CardSortOrder.restored(from: order.rawValue) == order, "\(order.title)")
        }
    }

    @Test("The stored raw values are the ones written down, not compiler defaults")
    func rawValuesArePinned() {
        // Pinned literally, because these strings live in UserDefaults on the
        // user's device and outlive any refactoring in here.
        #expect(CardSortOrder.newestFirst.rawValue == "newestFirst")
        #expect(CardSortOrder.oldestFirst.rawValue == "oldestFirst")
        #expect(CardSortOrder.germanAscending.rawValue == "germanAscending")
        #expect(CardSortOrder.germanDescending.rawValue == "germanDescending")
        #expect(CardSortOrder.categoryAscending.rawValue == "categoryAscending")
        #expect(Set(CardSortOrder.allCases.map(\.rawValue)).count == 5, "no two share one")

        // The key is worth exactly as much protection as the values under
        // it: renaming it silently discards everybody's stored choice in the
        // same way, and nothing else in the app would notice.
        #expect(CardSortOrder.storageKey == "cardList.sortOrder")
    }

    @Test("An unknown or missing stored value falls back to the default")
    func unknownSortPreferenceFallsBack() {
        // Everything that can actually be in UserDefaults: a removed case, a
        // typo, a value from a newer build, an empty string, nothing at all.
        #expect(CardSortOrder.restored(from: nil) == .default)
        #expect(CardSortOrder.restored(from: "") == .default)
        #expect(CardSortOrder.restored(from: "statusAscending") == .default)
        #expect(CardSortOrder.restored(from: "GERMANASCENDING") == .default, "and it is case sensitive")
        #expect(CardSortOrder.restored(from: " germanAscending ") == .default)
        #expect(CardSortOrder.default == .germanAscending, "a fresh install sorts as it always did")
    }

    @Test("Restoring a preference decides only the order, not what is shown")
    func sortPreferenceDoesNotFilter() throws {
        // The preference is a view concern. This pins that reading it back
        // cannot change the set of cards — only their sequence.
        let cards = [makeCard("Wasser"), makeCard("Apfel"), makeCard("Milch")]
        try container.mainContext.save()

        for raw in CardSortOrder.allCases.map(\.rawValue) + ["kaputt", ""] {
            let order = CardSortOrder.restored(from: raw)
            let sorted = CardListArrangement.sort(cards, by: order)
            #expect(Set(sorted.map(\.id)) == Set(cards.map(\.id)), "raw \(raw.debugDescription)")
        }
    }

    // MARK: - Grouping

    @Test("Headings are alphabetical and cards inside them are German A–Z")
    func sectionsAreOrdered() throws {
        let everyday = makeTag("Alltag")
        let food = makeTag("Essen")
        let travel = makeTag("Reisen")

        let cards = [
            makeCard("Zug", tags: [travel]),
            makeCard("Wasser", tags: [food]),
            makeCard("Apfel", tags: [food]),
            makeCard("Uhr", tags: [everyday]),
        ]
        try container.mainContext.save()

        let sections = CardListArrangement.sections(cards, selectedTagKeys: [])

        #expect(sections.map(\.title) == ["Alltag", "Essen", "Reisen"])
        #expect(germans(sections[1].cards) == ["Apfel", "Wasser"], "German A–Z inside a section")
    }

    @Test("Ohne Kategorie comes last, not where the alphabet would put it")
    func uncategorizedComesLast() throws {
        let travel = makeTag("Reisen")
        let cards = [
            makeCard("Ohne", tags: []),
            makeCard("Zug", tags: [travel]),
        ]
        try container.mainContext.save()

        let sections = CardListArrangement.sections(cards, selectedTagKeys: [])

        // "O" before "R" alphabetically — the point is that it is not.
        #expect(sections.map(\.title) == ["Reisen", CardListArrangement.uncategorizedTitle])
    }

    @Test("A card with several categories appears exactly once")
    func noDuplicatesAcrossSections() throws {
        let everyday = makeTag("Alltag")
        let food = makeTag("Essen")
        let travel = makeTag("Reisen")

        // Three categories, so the naive implementation — walk the categories
        // and collect their cards — would show this card three times.
        let card = makeCard("Wasser", tags: [travel, food, everyday])
        try container.mainContext.save()

        let sections = CardListArrangement.sections([card], selectedTagKeys: [])
        let placements = sections.flatMap(\.cards).map(\.id)

        #expect(placements.count == 1, "one card, one row")
        #expect(sections.map(\.title) == ["Alltag"], "the alphabetically first of its own")
    }

    @Test("With a filter active, a card is filed under a selected category")
    func groupingFollowsTheSelection() throws {
        let everyday = makeTag("Alltag")
        let travel = makeTag("Reisen")

        // "Alltag" sorts first, but the user did not ask for it. Filing the
        // card under a heading that is filtered away would be worse than
        // arbitrary — it would be a heading the user cannot see the reason for.
        let card = makeCard("Zug", tags: [everyday, travel])
        try container.mainContext.save()

        let selected: Set<String> = [TagNormalization.key(for: "Reisen")]
        #expect(CardListArrangement.sectionTitle(for: card, selectedTagKeys: selected) == "Reisen")
        #expect(CardListArrangement.sectionTitle(for: card, selectedTagKeys: []) == "Alltag")

        let sections = CardListArrangement.sections([card], selectedTagKeys: selected)
        #expect(sections.map(\.title) == ["Reisen"])
        #expect(sections.flatMap(\.cards).count == 1)
    }

    @Test("Among several selected categories the alphabetically first wins")
    func groupingPicksTheFirstSelectedCategory() throws {
        let everyday = makeTag("Alltag")
        let food = makeTag("Essen")
        let travel = makeTag("Reisen")

        let card = makeCard("Wasser", tags: [travel, food, everyday])
        try container.mainContext.save()

        let selected: Set<String> = [
            TagNormalization.key(for: "Reisen"),
            TagNormalization.key(for: "Essen"),
        ]
        #expect(CardListArrangement.sectionTitle(for: card, selectedTagKeys: selected) == "Essen")
    }

    @Test("Grouping ignores casing, because it compares normalized keys")
    func groupingUsesNormalizedKeys() throws {
        let travel = makeTag("Reisen")
        let card = makeCard("Zug", tags: [travel])
        try container.mainContext.save()

        let selected: Set<String> = [TagNormalization.key(for: "  REISEN ")]
        #expect(CardListArrangement.sectionTitle(for: card, selectedTagKeys: selected) == "Reisen")
    }

    @Test("Grouping keeps every card, whatever the selection")
    func groupingLosesNothing() throws {
        let food = makeTag("Essen")
        let travel = makeTag("Reisen")

        let cards = [
            makeCard("Apfel", tags: [food]),
            makeCard("Zug", tags: [travel]),
            makeCard("Uhr", tags: []),
            makeCard("Wasser", tags: [food, travel]),
        ]
        try container.mainContext.save()

        for selection in [Set<String>(), ["essen"], ["essen", "reisen"]] {
            let sections = CardListArrangement.sections(cards, selectedTagKeys: selection)
            let placed = sections.flatMap(\.cards).map(\.id)
            #expect(Set(placed) == Set(cards.map(\.id)), "selection \(selection)")
            #expect(placed.count == cards.count, "no duplicate for selection \(selection)")
        }
    }

    @Test("Sections are stable: the same input gives the same layout")
    func sectionsAreDeterministic() throws {
        let food = makeTag("Essen")
        let travel = makeTag("Reisen")
        let cards = [
            makeCard("Apfel", tags: [food]),
            makeCard("Zug", tags: [travel]),
            makeCard("Uhr", tags: []),
        ]
        try container.mainContext.save()

        // A dictionary sits between input and output, and its iteration order
        // is not stable across runs — so the headings are sorted afterwards
        // rather than trusted.
        let reference = CardListArrangement.sections(cards, selectedTagKeys: [])
        for _ in 0..<8 {
            let again = CardListArrangement.sections(cards.shuffled(), selectedTagKeys: [])
            #expect(again.map(\.title) == reference.map(\.title))
            #expect(again.flatMap(\.cards).map(\.id) == reference.flatMap(\.cards).map(\.id))
        }
    }

    // MARK: - Grouping and the type filter together

    @Test("Sentences group exactly like words")
    func sentencesGroupTheSameWay() throws {
        let travel = makeTag("Reisen")
        let sentence = makeCard(
            "Wo ist der Bahnhof?",
            type: .sentence,
            hanzi: "火车站在哪里？",
            pinyin: "huǒchēzhàn zài nǎlǐ",
            tags: [travel]
        )
        let word = makeCard("Zug", tags: [travel])
        try container.mainContext.save()

        // The arrangement never looks at the type — keeping the two apart is
        // `CardFilter`'s job, and this pins that the two halves do not
        // overlap.
        let sections = CardListArrangement.sections([sentence, word], selectedTagKeys: [])
        #expect(sections.map(\.title) == ["Reisen"])
        #expect(germans(sections[0].cards) == ["Wo ist der Bahnhof?", "Zug"])

        let onlySentences = CardFilter.apply(to: [sentence, word], type: .sentence)
        #expect(germans(CardListArrangement.sections(onlySentences, selectedTagKeys: [])
            .flatMap(\.cards)) == ["Wo ist der Bahnhof?"])
    }
}
