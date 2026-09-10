//
//  TagManagementTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

@MainActor
struct TagManagementTests {

    /// Stored so the container outlives every property access on the models
    /// below — see the note on `CardFilterTests.container`.
    let container: ModelContainer
    let food: Tag
    let travel: Tag
    let apple: Card
    let rice: Card

    init() throws {
        container = try makeInMemoryContainer()
        let context = container.mainContext

        food = Tag(name: "Essen")
        travel = Tag(name: "Reisen")
        context.insert(food)
        context.insert(travel)

        apple = Card(type: .word, german: "Apfel", hanzi: "苹果", tags: [food])
        rice = Card(type: .word, german: "Reis", hanzi: "米饭", tags: [food, travel])
        context.insert(apple)
        context.insert(rice)
        try context.save()
    }

    private var context: ModelContext { container.mainContext }
    private var storedTags: [Tag] {
        get throws { try context.fetch(FetchDescriptor<Tag>()) }
    }

    // MARK: - Renaming

    // MARK: - Creating

    @Test("The plus creates a category through the shared rules")
    func creationUsesTheSharedRules() throws {
        let created = try TagManagement.create(named: "  reisen abroad  ", among: try storedTags, in: context)

        // Trimmed and squeezed by `TagNormalization.displayName`, the same
        // step the editor and the rename path run.
        #expect(created.name == "reisen abroad")
        #expect(try storedTags.contains { $0 === created })
    }

    @Test("Creating a name another category already holds is refused, not merged")
    func creationRefusesADuplicate() throws {
        // Different spelling, same normalised key — A13 says there is only
        // ever one category per key.
        #expect(throws: AppError.self) {
            try TagManagement.create(named: "  ESSEN ", among: try storedTags, in: context)
        }
        #expect(try storedTags.count == 2, "and nothing was inserted")
    }

    @Test("The refusal to create names the conflicting category")
    func creationRefusalNamesTheClash() throws {
        do {
            try TagManagement.create(named: "essen", among: try storedTags, in: context)
            Issue.record("expected the duplicate to be refused")
        } catch let error as AppError {
            guard case .tagNameRejected(.duplicate(let existing)) = error else {
                Issue.record("wrong error: \(error)")
                return
            }
            #expect(existing == "Essen", "the stored spelling, so the message is recognisable")
        }
    }

    @Test("An empty or overlong name is refused on creation too")
    func creationRefusesInvalidNames() throws {
        #expect(throws: AppError.self) {
            try TagManagement.create(named: "   ", among: try storedTags, in: context)
        }
        let overlong = String(repeating: "a", count: TagNormalization.maximumLength + 1)
        #expect(throws: AppError.self) {
            try TagManagement.create(named: overlong, among: try storedTags, in: context)
        }
        // Exactly the limit is still fine — the same boundary the rename
        // path has.
        let atLimit = String(repeating: "b", count: TagNormalization.maximumLength)
        let created = try TagManagement.create(named: atLimit, among: try storedTags, in: context)
        #expect(created.name.count == TagNormalization.maximumLength)
        #expect(try storedTags.count == 3)
    }

    @Test("A created category survives reopening the store")
    func creationIsPersisted() throws {
        // A real store on disk, the same shape the other persistence tests
        // use: the management screen is the one place a category is created
        // without a card behind it, so nothing else would keep it alive.
        let store = TemporaryStore()
        defer { store.remove() }

        do {
            let container = try store.openContainer()
            try TagManagement.create(named: "Büro", among: [], in: container.mainContext)
        }

        let reopened = try store.openContainer()
        let tags = try reopened.mainContext.fetch(FetchDescriptor<Tag>())
        #expect(tags.map(\.name) == ["Büro"])
    }

    @Test("Creation and renaming answer to the same rule")
    func creationAndRenameAgree() throws {
        // The point of `creationProblem` sharing `RenameProblem`: a name this
        // screen accepts is exactly a name a rename would accept, so the two
        // entries cannot drift into different notions of a valid category.
        for name in ["Neu", "  Neu  ", "essen", "", String(repeating: "x", count: 41)] {
            let creation = TagNormalization.creationProblem(name: name, among: [food, travel])
            let rename = TagNormalization.renameProblem(renaming: apple.tags[0], to: name, among: [food, travel])
            // Renaming "Essen" to "essen" is its own name and allowed, which
            // is the single documented difference.
            if name == "essen" {
                #expect(creation == .duplicate(existing: "Essen"))
                #expect(rename == nil, "a tag may re-spell its own name")
            } else {
                #expect(creation == rename, "disagreement on \(name.debugDescription)")
            }
        }
    }

    @Test("Renaming keeps every card assignment")
    func renamingKeepsAssignments() throws {
        try TagManagement.rename(food, to: "Essen gehen", among: [food, travel], in: context)

        #expect(food.name == "Essen gehen")
        // The point of renaming in place: the relationship is untouched.
        #expect(Set(food.cards.map(\.german)) == ["Apfel", "Reis"])
        #expect(apple.tags.map(\.name) == ["Essen gehen"])
        #expect(Set(rice.tags.map(\.name)) == ["Essen gehen", "Reisen"])
        #expect(try storedTags.count == 2, "No second tag may appear")
    }

    @Test("Renaming trims and tidies the new name")
    func renamingTidiesTheName() throws {
        try TagManagement.rename(food, to: "  Essen   gehen  ", among: [food, travel], in: context)
        #expect(food.name == "Essen gehen")
    }

    @Test("A tag may be re-spelled to a different casing of its own name")
    func renamingToOwnCasingIsAllowed() throws {
        // "Essen" -> "essen" is the same tag, not a duplicate.
        try TagManagement.rename(food, to: "essen", among: [food, travel], in: context)
        #expect(food.name == "essen")
        #expect(food.cards.count == 2)
    }

    @Test("Renaming onto an existing name is refused instead of merging")
    func renamingOntoExistingNameIsRefused() throws {
        #expect(throws: AppError.self) {
            try TagManagement.rename(travel, to: "essen", among: [food, travel], in: context)
        }

        // Nothing may have changed.
        #expect(travel.name == "Reisen")
        #expect(food.name == "Essen")
        #expect(try storedTags.count == 2)
        #expect(food.cards.count == 2, "No cards may have been moved over")
    }

    @Test("The refusal names the conflicting category")
    func refusalNamesTheConflict() {
        let problem = TagNormalization.renameProblem(
            renaming: travel,
            to: "  ESSEN ",
            among: [food, travel]
        )
        #expect(problem == .duplicate(existing: "Essen"))

        let error = AppError.tagNameRejected(.duplicate(existing: "Essen"))
        #expect(error.message.contains("Essen"))
        #expect(error.message.contains("nicht zusammengeführt"))
    }

    @Test("An empty or invisible new name is refused")
    func emptyNameIsRefused() throws {
        for candidate in ["", "   ", "\u{200B}\u{FEFF}"] {
            #expect(
                TagNormalization.renameProblem(renaming: food, to: candidate, among: [food, travel]) == .invalid
            )
            #expect(throws: AppError.self) {
                try TagManagement.rename(food, to: candidate, among: [food, travel], in: context)
            }
        }
        #expect(food.name == "Essen")
    }

    @Test("An overlong new name is refused")
    func overlongNameIsRefused() throws {
        let tooLong = String(repeating: "a", count: TagNormalization.maximumLength + 1)
        #expect(
            TagNormalization.renameProblem(renaming: food, to: tooLong, among: [food, travel]) == .tooLong
        )
        #expect(throws: AppError.self) {
            try TagManagement.rename(food, to: tooLong, among: [food, travel], in: context)
        }
        #expect(food.name == "Essen")
    }

    @Test("A name of exactly the maximum length is accepted")
    func maximumLengthIsAccepted() throws {
        let exact = String(repeating: "a", count: TagNormalization.maximumLength)
        try TagManagement.rename(food, to: exact, among: [food, travel], in: context)
        #expect(food.name == exact)
    }

    // MARK: - Deleting

    @Test("Deleting a category keeps the cards and only drops the assignment")
    func deletingKeepsCards() throws {
        try TagManagement.delete(food, in: context)

        let cards = try context.fetch(FetchDescriptor<Card>())
        #expect(cards.count == 2, "No card may be deleted along with the category")
        #expect(apple.tags.isEmpty, "Apfel only had this one category")
        #expect(rice.tags.map(\.name) == ["Reisen"], "Reis keeps its other category")
        #expect(try storedTags.map(\.name) == ["Reisen"])
    }

    @Test("Deleting one category leaves the others alone")
    func deletingOneCategoryLeavesOthers() throws {
        try TagManagement.delete(travel, in: context)

        #expect(try storedTags.map(\.name) == ["Essen"])
        #expect(Set(food.cards.map(\.german)) == ["Apfel", "Reis"])
        #expect(apple.tags.map(\.name) == ["Essen"])
    }

    // MARK: - Persistence

    @Test("A rename survives reopening the store")
    func renameSurvivesRestart() throws {
        let store = TemporaryStore()
        defer { store.remove() }

        do {
            let container = try store.openContainer()
            let context = container.mainContext
            let tag = Tag(name: "Restaurant")
            context.insert(tag)
            context.insert(Card(type: .word, german: "Rechnung", hanzi: "账单", tags: [tag]))
            try context.save()

            try TagManagement.rename(tag, to: "Essen gehen", among: [tag], in: context)
        }

        let reopened = try store.openContainer()
        let tags = try reopened.mainContext.fetch(FetchDescriptor<Tag>())
        let cards = try reopened.mainContext.fetch(FetchDescriptor<Card>())

        #expect(tags.map(\.name) == ["Essen gehen"])
        #expect(cards.first?.tags.map(\.name) == ["Essen gehen"], "The assignment must have survived too")
    }

    @Test("A deletion survives reopening the store, and the card does too")
    func deletionSurvivesRestart() throws {
        let store = TemporaryStore()
        defer { store.remove() }

        do {
            let container = try store.openContainer()
            let context = container.mainContext
            let tag = Tag(name: "Restaurant")
            context.insert(tag)
            context.insert(Card(type: .word, german: "Rechnung", hanzi: "账单", tags: [tag]))
            try context.save()

            try TagManagement.delete(tag, in: context)
        }

        let reopened = try store.openContainer()
        let tags = try reopened.mainContext.fetch(FetchDescriptor<Tag>())
        let cards = try reopened.mainContext.fetch(FetchDescriptor<Card>())

        #expect(tags.isEmpty)
        #expect(cards.count == 1, "The card must outlive its category")
        #expect(cards.first?.tags.isEmpty == true)
    }

    // MARK: - Effect on editor and filter

    @Test("A deleted category disappears from the tag list the editor and filter read")
    func deletedCategoryDisappearsFromSelectionSources() throws {
        // Editor and filter bar both work off a `@Query` over all tags, so
        // "gone from the store" is what "gone from the UI" means. Filtering by
        // its key must find nothing afterwards.
        let key = TagNormalization.key(for: food.name)
        #expect(CardFilter.apply(to: [apple, rice], type: .word, tagKeys: [key]).count == 2)

        try TagManagement.delete(food, in: context)

        #expect(try storedTags.contains { $0.name == "Essen" } == false)
        #expect(CardFilter.apply(to: [apple, rice], type: .word, tagKeys: [key]).isEmpty)
    }

    @Test("A renamed category is found under its new key, not the old one")
    func renamedCategoryMovesToItsNewKey() throws {
        let oldKey = TagNormalization.key(for: "Essen")
        try TagManagement.rename(food, to: "Essen gehen", among: [food, travel], in: context)
        let newKey = TagNormalization.key(for: "Essen gehen")

        #expect(CardFilter.apply(to: [apple, rice], type: .word, tagKeys: [oldKey]).isEmpty)
        #expect(CardFilter.apply(to: [apple, rice], type: .word, tagKeys: [newKey]).count == 2)
    }
}
