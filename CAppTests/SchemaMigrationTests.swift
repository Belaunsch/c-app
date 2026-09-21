//
//  SchemaMigrationTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

/// Q7, finally asked of a real change.
///
/// Since phase 1 the project has run without a `VersionedSchema` and without a
/// `SchemaMigrationPlan`, on the assumption that SwiftData's lightweight
/// migration would carry additive changes. Until today that assumption was
/// untestable for the best of reasons: `CApp/Models/` had never changed, so
/// there was nothing to migrate. Phase 11 adds `ReviewLog` and one
/// relationship on `Card`, and that is the first real case.
///
/// ## How the old state is reconstructed
///
/// A store cannot be written with the previous version of `Card`, because the
/// class in the app already carries the new relationship. So the phase-10
/// shape is declared again, separately, inside `Phase10Schema` — same entity
/// names, same attributes, no `reviews`. SwiftData maps by entity name, so a
/// store written through those classes is byte-for-byte a store from the
/// released phase-10 app.
///
/// ## What this proves and what it does not
///
/// It proves that a store containing real cards, categories and learning
/// states **survives the schema change**: the file is opened again with the
/// phase-11 schema, every value is read back, and the new relationship is
/// there and empty.
///
/// It does **not** prove that the private store on the user's iPhone
/// migrates. That one is older, larger, has been through every release and
/// lives on a device — and it is explicitly part of the final device and
/// release acceptance at the end of the roadmap, not of this phase.
///
/// ## Phase 13: a different additive case
///
/// Phase 11 added a **new model** plus a relationship. Phase 13 adds two
/// **properties to an existing model** (`ReviewLog.suggestedStatusRaw` and
/// `suggestionDecisionRaw`), and the phase-11 test says nothing about that: it
/// is additive too, but it is not the same change. So the phase-12 shape is
/// reconstructed the same way and the same question asked again — measured, not
/// assumed, which is what Q7 asks for.
@MainActor
struct SchemaMigrationTests {

    /// The data model exactly as phase 10 shipped it.
    enum Phase10Schema {
        static var schema: Schema { Schema([Card.self, Tag.self]) }

        @Model
        final class Card {
            var id: UUID = UUID()
            var typeRaw: String = CardType.word.rawValue
            var statusRaw: Int = LearningStatus.new.rawValue
            var german: String = ""
            var hanzi: String = ""
            var pinyin: String = ""
            var createdAt: Date = Date()
            var lastReviewedAt: Date?
            var reviewCount: Int = 0
            var correctCount: Int = 0
            var hanziWasEditedManually: Bool = false
            var pinyinWasEditedManually: Bool = false

            @Relationship(deleteRule: .nullify, inverse: \Tag.cards)
            var tags: [Tag] = []

            init(german: String, hanzi: String, pinyin: String = "") {
                self.german = german
                self.hanzi = hanzi
                self.pinyin = pinyin
            }
        }

        @Model
        final class Tag {
            var name: String = ""
            var cards: [Card] = []

            init(name: String) { self.name = name }
        }
    }

    /// The data model exactly as phase 12 shipped it: `ReviewLog` **without** the
    /// two suggestion fields.
    ///
    /// Declared separately for the same reason as `Phase10Schema` — the app's own
    /// `ReviewLog` already carries the new properties, so the old shape has to be
    /// rebuilt to write an old store. SwiftData maps by entity name, so what this
    /// writes is byte-for-byte a store from the released phase-12 app.
    enum Phase12Schema {
        static var schema: Schema { Schema([Card.self, Tag.self, ReviewLog.self]) }

        @Model
        final class Card {
            var id: UUID = UUID()
            var typeRaw: String = CardType.word.rawValue
            var statusRaw: Int = LearningStatus.new.rawValue
            var german: String = ""
            var hanzi: String = ""
            var pinyin: String = ""
            var createdAt: Date = Date()
            var lastReviewedAt: Date?
            var reviewCount: Int = 0
            var correctCount: Int = 0
            var hanziWasEditedManually: Bool = false
            var pinyinWasEditedManually: Bool = false

            @Relationship(deleteRule: .nullify, inverse: \Tag.cards)
            var tags: [Tag] = []

            @Relationship(deleteRule: .cascade, inverse: \ReviewLog.card)
            var reviews: [ReviewLog] = []

            init(german: String, hanzi: String, pinyin: String = "") {
                self.german = german
                self.hanzi = hanzi
                self.pinyin = pinyin
            }
        }

        @Model
        final class Tag {
            var name: String = ""
            var cards: [Card] = []

            init(name: String) { self.name = name }
        }

        @Model
        final class ReviewLog {
            var id: UUID = UUID()
            var reviewedAt: Date = Date()
            var directionRaw: String = SessionDirection.germanToChinese.rawValue
            var previousStatusRaw: Int = LearningStatus.new.rawValue
            var assessmentRaw: String?
            var usedSpeech: Bool = false
            var speechMatched: Bool?
            var wasManualReveal: Bool = false
            var wasRetry: Bool = false
            var card: Card?

            init() {}
        }
    }

    @Test("A phase-10 store opens under the phase-11 schema with nothing lost")
    func lightweightMigrationCarriesTheStore() throws {
        let store = TemporaryStore()
        defer { store.remove() }

        // 1. Write a realistic collection with the old schema.
        let writtenAt = Date(timeIntervalSince1970: 1_700_000_000)
        do {
            let container = try store.openContainer(for: Phase10Schema.schema)
            let context = container.mainContext

            let food = Phase10Schema.Tag(name: "Essen")
            let travel = Phase10Schema.Tag(name: "Reisen")
            context.insert(food)
            context.insert(travel)

            let apple = Phase10Schema.Card(german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ")
            apple.statusRaw = LearningStatus.good.rawValue
            apple.reviewCount = 7
            apple.correctCount = 5
            apple.lastReviewedAt = writtenAt
            apple.pinyinWasEditedManually = true
            apple.tags = [food]

            let sentence = Phase10Schema.Card(
                german: "Ich möchte etwas essen.",
                hanzi: "我想吃点东西",
                pinyin: "wǒ xiǎng chī diǎn dōngxi"
            )
            sentence.typeRaw = CardType.sentence.rawValue
            sentence.statusRaw = LearningStatus.weak.rawValue
            sentence.tags = [food, travel]

            let untouched = Phase10Schema.Card(german: "Wasser", hanzi: "水", pinyin: "shuǐ")

            context.insert(apple)
            context.insert(sentence)
            context.insert(untouched)
            try context.save()
        }

        // 2. Open the very same file with the phase-11 schema. No
        //    `SchemaMigrationPlan`, no `VersionedSchema` — if this throws, the
        //    assumption from phase 1 was wrong and the phase needs one.
        let container = try store.openContainer()
        let context = container.mainContext
        let cards = try context.fetch(FetchDescriptor<CApp.Card>(sortBy: [SortDescriptor(\.german)]))
        let tags = try context.fetch(FetchDescriptor<CApp.Tag>(sortBy: [SortDescriptor(\.name)]))

        // 3. Everything is still there, with the values it was given.
        #expect(cards.count == 3)
        #expect(tags.map(\.name) == ["Essen", "Reisen"])

        let apple = try #require(cards.first { $0.german == "Apfel" })
        #expect(apple.hanzi == "苹果")
        #expect(apple.pinyin == "píngguǒ")
        #expect(apple.type == .word)
        #expect(apple.status == .good, "der Lernstand überlebt die Migration")
        #expect(apple.reviewCount == 7)
        #expect(apple.correctCount == 5)
        #expect(apple.lastReviewedAt == writtenAt)
        #expect(apple.pinyinWasEditedManually)
        #expect(apple.tags.map(\.name) == ["Essen"], "die Zuordnung ebenfalls")

        let sentence = try #require(cards.first { $0.type == .sentence })
        #expect(sentence.status == .weak)
        #expect(Set(sentence.tags.map(\.name)) == ["Essen", "Reisen"])

        // 4. The new relationship exists and is empty — a card from before the
        //    change has no history, which is the only honest starting value.
        #expect(cards.allSatisfy { $0.reviews.isEmpty })

        // 5. And it is usable immediately: the migrated card takes an entry.
        let log = ReviewLog(
            reviewedAt: writtenAt, direction: .germanToChinese,
            previousStatus: apple.status, usedSpeech: true, speechMatched: true,
            assessment: .good, card: apple
        )
        context.insert(log)
        try context.save()
        #expect(apple.reviews.count == 1)
        #expect(apple.reviews.first?.assessment == .good)
    }

    @Test("The migrated store still reads correctly after another restart")
    func migratedStoreSurvivesAReopen() throws {
        // Two opens after the migration, because a lightweight migration that
        // only appears to work would show up here: the second open reads what
        // the first one actually wrote to disk.
        let store = TemporaryStore()
        defer { store.remove() }

        do {
            let container = try store.openContainer(for: Phase10Schema.schema)
            let card = Phase10Schema.Card(german: "Apfel", hanzi: "苹果")
            card.statusRaw = LearningStatus.medium.rawValue
            container.mainContext.insert(card)
            try container.mainContext.save()
        }
        do {
            let container = try store.openContainer()
            let card = try #require(try container.mainContext.fetch(FetchDescriptor<CApp.Card>()).first)
            card.reviews.append(ReviewLog(direction: .audioToGerman, previousStatus: .medium))
            try container.mainContext.save()
        }

        let container = try store.openContainer()
        let card = try #require(try container.mainContext.fetch(FetchDescriptor<CApp.Card>()).first)
        #expect(card.german == "Apfel")
        #expect(card.status == .medium)
        #expect(card.reviews.count == 1)
        #expect(card.reviews.first?.direction == .audioToGerman)
    }

    /// The data model as phase 13 first shipped it: `ReviewLog` **with** the two
    /// suggestion fields, `Card` **without** the evidence boundary.
    ///
    /// A third reconstruction for a third additive case — a new property on `Card`
    /// this time. Q7 is answered per case rather than generalised, because that is
    /// what „gemessen statt angenommen" means.
    enum Phase13Schema {
        static var schema: Schema { Schema([Card.self, Tag.self, ReviewLog.self]) }

        @Model
        final class Card {
            var id: UUID = UUID()
            var typeRaw: String = CardType.word.rawValue
            var statusRaw: Int = LearningStatus.new.rawValue
            var german: String = ""
            var hanzi: String = ""
            var pinyin: String = ""
            var createdAt: Date = Date()
            var lastReviewedAt: Date?
            var reviewCount: Int = 0
            var correctCount: Int = 0
            var hanziWasEditedManually: Bool = false
            var pinyinWasEditedManually: Bool = false

            @Relationship(deleteRule: .nullify, inverse: \Tag.cards)
            var tags: [Tag] = []

            @Relationship(deleteRule: .cascade, inverse: \ReviewLog.card)
            var reviews: [ReviewLog] = []

            init(german: String, hanzi: String) {
                self.german = german
                self.hanzi = hanzi
            }
        }

        @Model
        final class Tag {
            var name: String = ""
            var cards: [Card] = []
            init(name: String) { self.name = name }
        }

        @Model
        final class ReviewLog {
            var id: UUID = UUID()
            var reviewedAt: Date = Date()
            var directionRaw: String = SessionDirection.germanToChinese.rawValue
            var previousStatusRaw: Int = LearningStatus.new.rawValue
            var assessmentRaw: String?
            var usedSpeech: Bool = false
            var speechMatched: Bool?
            var wasManualReveal: Bool = false
            var wasRetry: Bool = false
            var suggestedStatusRaw: Int?
            var suggestionDecisionRaw: String?
            var card: Card?
            init() {}
        }
    }

    @Test("A phase-13 store opens with the evidence boundary added, and reads as never corrected")
    func evidenceBoundaryMigratesLightly() throws {
        let store = TemporaryStore()
        defer { store.remove() }
        let writtenAt = Date(timeIntervalSince1970: 1_700_000_000)

        // 1. A store from the first phase-13 build: a card with history, including
        //    an entry that already carries a declined suggestion.
        do {
            let container = try store.openContainer(for: Phase13Schema.schema)
            let context = container.mainContext

            let card = Phase13Schema.Card(german: "Apfel", hanzi: "苹果")
            card.statusRaw = LearningStatus.good.rawValue
            card.reviewCount = 6
            card.lastReviewedAt = writtenAt
            context.insert(card)

            let declined = Phase13Schema.ReviewLog()
            declined.reviewedAt = writtenAt
            declined.previousStatusRaw = LearningStatus.good.rawValue
            declined.usedSpeech = true
            declined.speechMatched = true
            declined.suggestedStatusRaw = LearningStatus.secure.rawValue
            declined.suggestionDecisionRaw = SuggestionDecision.declined.rawValue
            declined.card = card
            context.insert(declined)

            try context.save()
        }

        // 2. Open the same file with the current schema.
        let container = try store.openContainer()
        let context = container.mainContext
        let card = try #require(try context.fetch(FetchDescriptor<CApp.Card>()).first)

        #expect(card.german == "Apfel")
        #expect(card.status == .good)
        #expect(card.reviewCount == 6)
        #expect(card.lastReviewedAt == writtenAt)
        #expect(card.reviews.count == 1)

        let declined = try #require(card.reviews.first)
        #expect(declined.suggestedStatus == .secure, "the phase-13 fields survive")
        #expect(declined.suggestionDecision == .declined)

        // 3. The new property reads as „never corrected", which is the only honest
        //    value for a card written before it existed — so all of its history
        //    stays eligible.
        #expect(card.classificationEvidenceResetAt == nil)
        #expect(LearnSessionModel.countsAsEvidence(declined, for: card))

        // 4. And it is usable at once.
        try LearningStatusCorrection.apply(
            .medium, to: card, in: context, now: { writtenAt.addingTimeInterval(60) }
        )
        #expect(card.status == .medium)
        #expect(LearnSessionModel.countsAsEvidence(declined, for: card) == false)

        // 5. Reopened, because a migration that only appears to work shows up here.
        let reopened = try store.openContainer()
        let again = try #require(try reopened.mainContext.fetch(FetchDescriptor<CApp.Card>()).first)
        #expect(again.status == .medium)
        #expect(again.classificationEvidenceResetAt == writtenAt.addingTimeInterval(60))
        #expect(again.reviews.count == 1, "and the history is still there")
    }

    @Test("A phase-12 store opens under the phase-13 schema with nothing lost")
    func phase13PropertiesMigrateLightly() throws {
        let store = TemporaryStore()
        defer { store.remove() }
        let writtenAt = Date(timeIntervalSince1970: 1_700_000_000)

        // 1. A realistic phase-12 store: a card with real history, including an
        //    entry that carries one of the four old self-assessments and one that
        //    was written by the automatic path.
        do {
            let container = try store.openContainer(for: Phase12Schema.schema)
            let context = container.mainContext

            let card = Phase12Schema.Card(german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ")
            card.statusRaw = LearningStatus.medium.rawValue
            card.reviewCount = 4
            card.correctCount = 3
            card.lastReviewedAt = writtenAt
            context.insert(card)

            let rated = Phase12Schema.ReviewLog()
            rated.reviewedAt = writtenAt
            rated.previousStatusRaw = LearningStatus.weak.rawValue
            rated.assessmentRaw = SelfAssessment.good.rawValue
            rated.usedSpeech = true
            rated.speechMatched = true
            rated.card = card
            context.insert(rated)

            let automatic = Phase12Schema.ReviewLog()
            automatic.reviewedAt = writtenAt.addingTimeInterval(60)
            automatic.directionRaw = SessionDirection.audioToGerman.rawValue
            automatic.previousStatusRaw = LearningStatus.medium.rawValue
            automatic.wasManualReveal = true
            automatic.card = card
            context.insert(automatic)

            try context.save()
        }

        // 2. Open the very same file with the phase-13 schema. No
        //    `SchemaMigrationPlan`, no `VersionedSchema`.
        let container = try store.openContainer()
        let context = container.mainContext
        let card = try #require(try context.fetch(FetchDescriptor<CApp.Card>()).first)

        // 3. Nothing lost.
        #expect(card.german == "Apfel")
        #expect(card.status == .medium)
        #expect(card.reviewCount == 4)
        #expect(card.correctCount == 3)
        #expect(card.lastReviewedAt == writtenAt)
        #expect(card.reviews.count == 2)

        let rated = try #require(card.reviews.first { $0.reviewedAt == writtenAt })
        #expect(rated.assessment == .good, "the historical self-assessment is still readable")
        #expect(rated.previousStatus == .weak)
        #expect(rated.speechMatched == true)

        let automatic = try #require(card.reviews.first { $0.reviewedAt != writtenAt })
        #expect(automatic.direction == .audioToGerman)
        #expect(automatic.wasManualReveal)
        #expect(automatic.assessment == nil)

        // 4. The two new properties read as `nil` on every old entry — the only
        //    honest starting value: nothing was ever suggested back then.
        #expect(card.reviews.allSatisfy { $0.suggestedStatus == nil })
        #expect(card.reviews.allSatisfy { $0.suggestionDecision == nil })
        #expect(card.reviews.allSatisfy { $0.hasConsistentSuggestion })

        // 5. And they are usable immediately: a new entry records an offer.
        context.insert(ReviewLog(
            reviewedAt: writtenAt.addingTimeInterval(120),
            direction: .germanToChinese, previousStatus: .medium,
            usedSpeech: true, speechMatched: true,
            suggestedStatus: .good, suggestionDecision: .declined, card: card
        ))
        try context.save()

        // 6. Reopened once more, because a migration that only appears to work
        //    would show up here.
        let reopened = try store.openContainer()
        let again = try #require(try reopened.mainContext.fetch(FetchDescriptor<CApp.Card>()).first)
        #expect(again.reviews.count == 3)
        let declined = try #require(again.reviews.first { $0.suggestionDecision != nil })
        #expect(declined.suggestedStatus == .good, "written and read back through the raw value")
        #expect(declined.suggestionDecision == .declined)
        #expect(declined.assessment == nil, "and it is not a self-assessment")
    }

    @Test("Deleting a card takes its history with it")
    func deletingACardCascades() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let card = CApp.Card(type: .word, german: "Apfel", hanzi: "苹果")
        context.insert(card)
        context.insert(ReviewLog(direction: .germanToChinese, previousStatus: .new, card: card))
        context.insert(ReviewLog(direction: .germanToChinese, previousStatus: .weak, card: card))
        try context.save()
        #expect(try context.fetch(FetchDescriptor<ReviewLog>()).count == 2)

        context.delete(card)
        try context.save()

        // `.cascade`, unlike the `.nullify` on tags: a review describes an
        // attempt at **this** card and means nothing without it.
        #expect(try context.fetch(FetchDescriptor<ReviewLog>()).isEmpty)
    }
}
