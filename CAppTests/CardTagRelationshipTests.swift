//
//  CardTagRelationshipTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

@MainActor
struct CardTagRelationshipTests {

    @Test("Eine Karte lässt sich mehreren Tags zuordnen")
    func cardCanHaveSeveralTags() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let food = Tag(name: "Essen")
        let everyday = Tag(name: "Alltag")
        context.insert(food)
        context.insert(everyday)

        let card = Card(type: .word, german: "Wasser", hanzi: "水", tags: [food, everyday])
        context.insert(card)
        try context.save()

        #expect(card.tags.count == 2)
        #expect(Set(card.tags.map(\.name)) == ["Essen", "Alltag"])
        // Die Inverse muss ohne weiteres Zutun stimmen.
        #expect(food.cards.map(\.german) == ["Wasser"])
        #expect(everyday.cards.map(\.german) == ["Wasser"])
    }

    @Test("Ein Tag lässt sich mehreren Karten zuordnen")
    func tagCanBelongToSeveralCards() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let food = Tag(name: "Essen")
        context.insert(food)
        context.insert(Card(type: .word, german: "Apfel", hanzi: "苹果", tags: [food]))
        context.insert(Card(type: .word, german: "Reis", hanzi: "米饭", tags: [food]))
        try context.save()

        #expect(food.cards.count == 2)
        #expect(Set(food.cards.map(\.german)) == ["Apfel", "Reis"])
    }

    @Test("Eine Karte löschen löscht keinen Tag, nur die Zuordnung")
    func deletingACardKeepsItsTags() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let food = Tag(name: "Essen")
        context.insert(food)
        let card = Card(type: .word, german: "Apfel", hanzi: "苹果", tags: [food])
        context.insert(card)
        try context.save()

        context.delete(card)
        try context.save()

        let tags = try context.fetch(FetchDescriptor<Tag>())
        let cards = try context.fetch(FetchDescriptor<Card>())
        #expect(cards.isEmpty)
        #expect(tags.count == 1, "Der Tag muss die Löschung der Karte überleben")
        #expect(tags.first?.name == "Essen")
        #expect(tags.first?.cards.isEmpty == true, "Die Zuordnung muss verschwunden sein")
    }

    @Test("Einen Tag löschen löscht keine Karte, nur die Zuordnung")
    func deletingATagKeepsItsCards() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let food = Tag(name: "Essen")
        context.insert(food)
        let card = Card(type: .word, german: "Apfel", hanzi: "苹果", tags: [food])
        context.insert(card)
        try context.save()

        context.delete(food)
        try context.save()

        let tags = try context.fetch(FetchDescriptor<Tag>())
        let cards = try context.fetch(FetchDescriptor<Card>())
        #expect(tags.isEmpty)
        #expect(cards.count == 1, "Die Karte muss die Löschung des Tags überleben")
        #expect(cards.first?.german == "Apfel")
        #expect(cards.first?.tags.isEmpty == true, "Die Zuordnung muss verschwunden sein")
    }

    @Test("Eine Karte löschen lässt die Tags anderer Karten unberührt")
    func deletingOneCardDoesNotAffectOtherCards() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let food = Tag(name: "Essen")
        context.insert(food)
        let apple = Card(type: .word, german: "Apfel", hanzi: "苹果", tags: [food])
        let rice = Card(type: .word, german: "Reis", hanzi: "米饭", tags: [food])
        context.insert(apple)
        context.insert(rice)
        try context.save()

        context.delete(apple)
        try context.save()

        #expect(food.cards.map(\.german) == ["Reis"])
        #expect(rice.tags.map(\.name) == ["Essen"])
    }

    @Test("Die Löschregel gilt auch nach dem Neuöffnen des Stores")
    func deleteRuleHoldsAfterReopeningTheStore() throws {
        // Die anderen Beziehungstests prüfen im selben Kontext. Ein Regress,
        // bei dem `.nullify` nur den Objektgraphen leert, die Join-Zeile aber
        // auf der Platte stehen lässt, bliebe dort grün — deshalb hier einmal
        // über einen echten Store.
        let store = TemporaryStore()
        defer { store.remove() }

        do {
            let container = try store.openContainer()
            let context = container.mainContext
            let food = Tag(name: "Essen")
            context.insert(food)
            let card = Card(type: .word, german: "Apfel", hanzi: "苹果", tags: [food])
            context.insert(card)
            try context.save()

            context.delete(card)
            try context.save()
        }

        let reopened = try store.openContainer()
        let tags = try reopened.mainContext.fetch(FetchDescriptor<Tag>())
        let cards = try reopened.mainContext.fetch(FetchDescriptor<Card>())

        #expect(cards.isEmpty)
        #expect(tags.count == 1)
        #expect(tags.first?.cards.isEmpty == true, "Die Join-Zeile darf nicht überleben")
    }

    @Test("Eine Zuordnung lässt sich entfernen, ohne etwas zu löschen")
    func removingAnAssignmentDeletesNothing() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let food = Tag(name: "Essen")
        context.insert(food)
        let card = Card(type: .word, german: "Apfel", hanzi: "苹果", tags: [food])
        context.insert(card)
        try context.save()

        card.tags.removeAll()
        try context.save()

        #expect(card.tags.isEmpty)
        #expect(food.cards.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Card>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Tag>()).count == 1)
    }
}
