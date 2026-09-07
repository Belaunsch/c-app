//
//  SampleDataTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

@MainActor
struct SampleDataTests {

    @Test("Der Vorschau-Container liefert 20 Wort- und 10 Satzkarten")
    func previewContainerHasTheExpectedCards() throws {
        let container = try SampleData.makePreviewContainer()
        let cards = try container.mainContext.fetch(FetchDescriptor<Card>())

        #expect(cards.count == 30)
        #expect(cards.filter { $0.type == .word }.count == 20)
        #expect(cards.filter { $0.type == .sentence }.count == 10)
    }

    @Test("Der Vorschau-Container liefert Tags, und Karten sind zugeordnet")
    func previewContainerHasTagsAndAssignments() throws {
        let container = try SampleData.makePreviewContainer()
        let context = container.mainContext

        let tags = try context.fetch(FetchDescriptor<Tag>())
        #expect(tags.count == SampleData.tagNames.count)

        let cards = try context.fetch(FetchDescriptor<Card>())
        #expect(cards.allSatisfy { $0.tags.isEmpty == false }, "Jede Beispielkarte braucht mindestens einen Tag")
        #expect(cards.contains { $0.tags.count > 1 }, "Mehrfachzuordnung soll in den Beispieldaten vorkommen")
        #expect(tags.allSatisfy { $0.cards.isEmpty == false }, "Kein Tag darf ungenutzt herumliegen")
    }

    @Test("Die Beispieldaten decken alle Lernstufen ab")
    func previewContainerCoversEveryLearningStatus() throws {
        let container = try SampleData.makePreviewContainer()
        let cards = try container.mainContext.fetch(FetchDescriptor<Card>())

        let covered = Set(cards.map(\.status))
        #expect(covered == Set(LearningStatus.allCases))
    }

    @Test("Die Lernmetadaten der Beispieldaten sind widerspruchsfrei")
    func previewCardsHaveCoherentLearningMetadata() throws {
        let container = try SampleData.makePreviewContainer()
        let cards = try container.mainContext.fetch(FetchDescriptor<Card>())

        for card in cards {
            #expect(card.correctCount <= card.reviewCount)
            if card.status == .new {
                #expect(card.reviewCount == 0)
                #expect(card.lastReviewedAt == nil)
            } else {
                #expect(card.reviewCount > 0)
                #expect(card.lastReviewedAt != nil)
            }
        }
    }

    @Test("Die Beispielkarten haben gestaffelte Erstellungsdaten")
    func previewCardsHaveStaggeredCreationDates() throws {
        // Ohne Staffelung hätten alle 30 Karten praktisch denselben
        // Zeitstempel. Die Kartenliste sortiert derzeit nach Deutsch, aber
        // `createdAt` ist die Basis für Recency und spätere Sortieroptionen.
        let container = try SampleData.makePreviewContainer()
        let cards = try container.mainContext.fetch(FetchDescriptor<Card>())

        #expect(Set(cards.map(\.createdAt)).count == cards.count)

        let sorted = cards.map(\.createdAt).sorted()
        let gaps = zip(sorted, sorted.dropFirst()).map { $1.timeIntervalSince($0) }
        #expect(gaps.allSatisfy { $0 > 60 }, "Die Abstände müssen deutlich über Messrauschen liegen")
    }

    @Test("Jede Beispielkarte hat Deutsch, Hanzi und Pinyin")
    func previewCardsAreComplete() throws {
        let container = try SampleData.makePreviewContainer()
        let cards = try container.mainContext.fetch(FetchDescriptor<Card>())

        for card in cards {
            #expect(card.german.isEmpty == false)
            #expect(card.hanzi.isEmpty == false)
            #expect(card.pinyin.isEmpty == false)
        }
    }

    @Test("Der Vorschau-Container ist flüchtig und berührt den echten Store nicht")
    func previewContainerIsInMemoryOnly() throws {
        let container = try SampleData.makePreviewContainer()

        // Der Aufruf steht bewusst außerhalb von `#expect`: Die Key-Path-Form
        // von `allSatisfy` verwirrt innerhalb des Makros die
        // `rethrows`-Inferenz.
        let everyStoreIsInMemory = container.configurations
            .allSatisfy { $0.isStoredInMemoryOnly }

        #expect(container.configurations.isEmpty == false)
        #expect(everyStoreIsInMemory)
    }
}
