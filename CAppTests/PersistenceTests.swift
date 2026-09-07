//
//  PersistenceTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

@MainActor
struct PersistenceTests {

    @Test("Eine gespeicherte Karte ist nach dem Neuöffnen des Stores noch da")
    func cardSurvivesReopeningTheStore() throws {
        let store = TemporaryStore()
        defer { store.remove() }

        let identifier: UUID
        do {
            let container = try store.openContainer()
            let card = Card(
                type: .word,
                german: "Apfel",
                hanzi: "苹果",
                pinyin: "píngguǒ",
                status: .medium,
                hanziWasEditedManually: true,
                pinyinWasEditedManually: true
            )
            identifier = card.id
            container.mainContext.insert(card)
            try container.mainContext.save()
        }

        #expect(store.exists, "Der Store muss als Datei auf der Platte liegen")

        // Ein zweiter Container auf derselben Datei entspricht dem nächsten
        // App-Start.
        let reopened = try store.openContainer()
        let cards = try reopened.mainContext.fetch(FetchDescriptor<Card>())

        #expect(cards.count == 1)
        #expect(cards.first?.id == identifier)
        #expect(cards.first?.german == "Apfel")
        #expect(cards.first?.hanzi == "苹果")
        #expect(cards.first?.pinyin == "píngguǒ")
        // Die Merker entscheiden ab Phase 3, ob die Automatik überschreiben
        // darf — sie müssen den Neustart überleben.
        #expect(cards.first?.hanziWasEditedManually == true)
        #expect(cards.first?.pinyinWasEditedManually == true)
    }

    @Test("Kartentyp und Lernstatus kommen nach dem Neustart als Enums zurück")
    func enumsSurviveReopeningTheStore() throws {
        let store = TemporaryStore()
        defer { store.remove() }

        do {
            let container = try store.openContainer()
            container.mainContext.insert(
                Card(type: .word, german: "Wasser", hanzi: "水", status: .secure)
            )
            container.mainContext.insert(
                Card(
                    type: .sentence,
                    german: "Die Rechnung, bitte.",
                    hanzi: "请结账。",
                    status: .weak
                )
            )
            try container.mainContext.save()
        }

        let reopened = try store.openContainer()
        let cards = try reopened.mainContext.fetch(FetchDescriptor<Card>())

        let word = try #require(cards.first { $0.german == "Wasser" })
        let sentence = try #require(cards.first { $0.german == "Die Rechnung, bitte." })

        #expect(word.type == .word)
        #expect(word.status == .secure)
        #expect(sentence.type == .sentence)
        #expect(sentence.status == .weak)
    }

    @Test("Die Tag-Zuordnung überlebt den Neustart")
    func tagAssignmentSurvivesReopeningTheStore() throws {
        let store = TemporaryStore()
        defer { store.remove() }

        do {
            let container = try store.openContainer()
            let context = container.mainContext
            let food = Tag(name: "Essen")
            let everyday = Tag(name: "Alltag")
            context.insert(food)
            context.insert(everyday)
            context.insert(
                Card(type: .word, german: "Wasser", hanzi: "水", tags: [food, everyday])
            )
            try context.save()
        }

        let reopened = try store.openContainer()
        let cards = try reopened.mainContext.fetch(FetchDescriptor<Card>())
        let tags = try reopened.mainContext.fetch(FetchDescriptor<Tag>())

        #expect(tags.count == 2)
        let card = try #require(cards.first)
        #expect(Set(card.tags.map(\.name)) == ["Essen", "Alltag"])
        #expect(tags.allSatisfy { $0.cards.count == 1 })
    }

    @Test("Nach dem Kartentyp lässt sich über den RawValue in der Datenbank filtern")
    func fetchDescriptorCanFilterByCardType() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        context.insert(Card(type: .word, german: "Apfel", hanzi: "苹果"))
        context.insert(Card(type: .word, german: "Wasser", hanzi: "水"))
        context.insert(Card(type: .sentence, german: "Guten Morgen!", hanzi: "早上好！"))
        try context.save()

        // Gefiltert wird auf `typeRaw`, nicht auf `type`: SwiftData
        // unterstützt keinen Prädikatvergleich gegen den Enum-Typ selbst.
        let wanted = CardType.word.rawValue
        var descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.typeRaw == wanted })
        descriptor.sortBy = [SortDescriptor(\.german)]
        let words = try context.fetch(descriptor)

        #expect(words.count == 2)
        #expect(words.map(\.german) == ["Apfel", "Wasser"])
        #expect(words.allSatisfy { $0.type == .word })
    }

    @Test("Nach dem Lernstatus lässt sich über den RawValue in der Datenbank filtern")
    func fetchDescriptorCanFilterByLearningStatus() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        context.insert(Card(type: .word, german: "Apfel", hanzi: "苹果", status: .new))
        context.insert(Card(type: .word, german: "Wasser", hanzi: "水", status: .secure))
        context.insert(Card(type: .word, german: "Tee", hanzi: "茶", status: .secure))
        try context.save()

        let wanted = LearningStatus.secure.rawValue
        let descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.statusRaw == wanted })
        let secure = try context.fetch(descriptor)

        #expect(secure.count == 2)
        #expect(secure.allSatisfy { $0.status == .secure })
    }

    @Test("Der Enum-Wert und sein RawValue bleiben immer synchron")
    func enumAndRawValueStayInSync() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let card = Card(type: .word, german: "Apfel", hanzi: "苹果")
        context.insert(card)
        try context.save()

        #expect(card.typeRaw == "word")
        #expect(card.statusRaw == 0)

        card.type = .sentence
        card.status = .good
        try context.save()

        #expect(card.typeRaw == "sentence")
        #expect(card.statusRaw == 3)
        #expect(card.type == .sentence)
        #expect(card.status == .good)
    }

    @Test("Der produktive Container ist lokal und liegt auf der Platte")
    func productionContainerIsLocalAndOnDisk() throws {
        // Nebenwirkung, bewusst in Kauf genommen: Das legt den echten
        // Produktionsstore im Sandbox-Container der Test-Host-App an — leer,
        // ohne Schreibvorgang. Der Gegenwert ist, dass hier das
        // Produktionsschema wirklich geöffnet wird und nicht eine Kopie
        // seiner Konfiguration geprüft wird.
        let container = try CAppApp.makeModelContainer()

        #expect(container.configurations.isEmpty == false)
        for configuration in container.configurations {
            #expect(
                configuration.isStoredInMemoryOnly == false,
                "Der produktive Store darf nicht flüchtig sein — sonst wäre nach jedem Start alles weg"
            )
            #expect(
                configuration.url.isFileURL,
                "Der Store muss eine lokale Datei sein"
            )
        }

        // „Kein CloudKit" lässt sich hier nicht zusichern:
        // `ModelConfiguration.CloudKitDatabase` ist nicht `Equatable` und
        // damit nicht vergleichbar. Die Zusicherung ergibt sich strukturell
        // daraus, dass `makeModelContainer()` überhaupt keine
        // `cloudKitDatabase` übergibt — nachzulesen in `CAppApp.swift`.
    }

    @Test("Im Store liegen genau die dokumentierten Attribute")
    func storeContainsExactlyTheDocumentedAttributes() throws {
        let card = try #require(CAppApp.schema.entities.first { $0.name == "Card" })
        let cardAttributes = Set(card.attributes.map(\.name))

        #expect(cardAttributes == [
            "id", "typeRaw", "statusRaw", "german", "hanzi", "pinyin",
            "createdAt", "lastReviewedAt", "reviewCount", "correctCount",
            "hanziWasEditedManually", "pinyinWasEditedManually",
        ])
        // Die abgeleiteten Werte dürfen nicht im Store landen, und `type`
        // sowie `status` dürfen nicht zusätzlich zu ihren RawValues
        // persistiert werden.
        #expect(
            cardAttributes.isDisjoint(with: ["weight", "errorCount", "accuracy", "isNew", "type", "status"]),
            "Abgeleitete Werte gehören laut docs/architecture.md §3 nicht in den Store"
        )
        #expect(Set(card.relationships.map(\.name)) == ["tags"])

        let tag = try #require(CAppApp.schema.entities.first { $0.name == "Tag" })
        #expect(Set(tag.attributes.map(\.name)) == ["name"])
        #expect(Set(tag.relationships.map(\.name)) == ["cards"])
    }

    @Test("Das produktive Schema enthält genau Card und Tag")
    func productionSchemaContainsCardAndTag() {
        let names = Set(CAppApp.schema.entities.map(\.name))
        #expect(names == ["Card", "Tag"])
    }
}
