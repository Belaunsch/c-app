//
//  CardModelTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

@MainActor
struct CardModelTests {

    @Test("Eine Wortkarte lässt sich anlegen und wieder laden")
    func insertAndFetchWordCard() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        context.insert(Card(type: .word, german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ"))
        try context.save()

        let cards = try context.fetch(FetchDescriptor<Card>())
        #expect(cards.count == 1)
        #expect(cards.first?.german == "Apfel")
        #expect(cards.first?.hanzi == "苹果")
        #expect(cards.first?.pinyin == "píngguǒ")
        #expect(cards.first?.type == .word)
    }

    @Test("Eine Satzkarte lässt sich anlegen")
    func insertSentenceCard() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        context.insert(
            Card(
                type: .sentence,
                german: "Ich möchte etwas essen.",
                hanzi: "我想吃点东西。",
                pinyin: "wǒ xiǎng chī diǎn dōngxi"
            )
        )
        try context.save()

        let cards = try context.fetch(FetchDescriptor<Card>())
        #expect(cards.first?.type == .sentence)
        #expect(cards.first?.german == "Ich möchte etwas essen.")
    }

    @Test("Ein Tag lässt sich anlegen")
    func insertTag() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        context.insert(Tag(name: "Essen"))
        try context.save()

        let tags = try context.fetch(FetchDescriptor<Tag>())
        #expect(tags.count == 1)
        #expect(tags.first?.name == "Essen")
        #expect(tags.first?.cards.isEmpty == true)
    }

    @Test("Eine neue Karte hat die vorgesehenen Defaults")
    func newCardHasExpectedDefaults() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let card = Card(type: .word, german: "Wasser", hanzi: "水")
        context.insert(card)
        try context.save()

        #expect(card.status == .new)
        #expect(card.pinyin.isEmpty)
        #expect(card.lastReviewedAt == nil)
        #expect(card.reviewCount == 0)
        #expect(card.correctCount == 0)
        #expect(card.hanziWasEditedManually == false)
        #expect(card.pinyinWasEditedManually == false)
        #expect(card.tags.isEmpty)
    }

    @Test("Die UUID einer Karte ist stabil und wird nicht neu erzeugt")
    func cardIdentifierIsStableAcrossReopening() throws {
        // Der interessante Teil ist nicht, dass zwei `UUID()` verschieden sind
        // — das prüft Foundation. Interessant ist, dass die UUID gespeichert
        // und nicht bei jedem Laden neu erzeugt wird. Genau darauf soll sich
        // ein späterer Import/Export stützen können.
        let store = TemporaryStore()
        defer { store.remove() }

        let expected: [UUID]
        do {
            let container = try store.openContainer()
            let first = Card(type: .word, german: "Tee", hanzi: "茶")
            let second = Card(type: .word, german: "Bier", hanzi: "啤酒")
            expected = [first.id, second.id]
            container.mainContext.insert(first)
            container.mainContext.insert(second)
            try container.mainContext.save()
        }

        #expect(Set(expected).count == 2, "Zwei Karten dürfen nicht dieselbe UUID haben")

        let reopened = try store.openContainer()
        var descriptor = FetchDescriptor<Card>()
        descriptor.sortBy = [SortDescriptor(\.german)]
        let cards = try reopened.mainContext.fetch(descriptor)

        #expect(cards.map(\.german) == ["Bier", "Tee"])
        #expect(Set(cards.map(\.id)) == Set(expected), "Die UUIDs müssen dieselben sein wie vor dem Neustart")
    }

    @Test("LearningStatus ist in der fachlich gemeinten Reihenfolge vergleichbar")
    func learningStatusIsOrdered() {
        #expect(LearningStatus.new < .weak)
        #expect(LearningStatus.weak < .medium)
        #expect(LearningStatus.medium < .good)
        #expect(LearningStatus.good < .secure)
        #expect(LearningStatus.allCases == [.new, .weak, .medium, .good, .secure])
        #expect(LearningStatus.allCases.map(\.rawValue) == [0, 1, 2, 3, 4])
    }

    @Test("CardType kennt genau Wort und Satz")
    func cardTypeHasExactlyTwoCases() {
        #expect(CardType.allCases == [.word, .sentence])
    }
}
