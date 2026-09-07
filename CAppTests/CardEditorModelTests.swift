//
//  CardEditorModelTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

@MainActor
struct CardEditorModelTests {

    // MARK: - Validation

    @Test("German and Hanzi are both required")
    func bothRequiredFieldsMustBeFilled() {
        let model = CardEditorModel()
        #expect(model.canSave == false)

        model.german = "Apfel"
        #expect(model.canSave == false, "Hanzi is still missing")

        model.hanzi = "苹果"
        #expect(model.canSave)
    }

    @Test("Whitespace alone does not count as content")
    func whitespaceIsNotContent() {
        let model = CardEditorModel()
        model.german = "   "
        model.hanzi = "\n\t"
        #expect(model.canSave == false)
    }

    @Test("Pinyin may stay empty")
    func pinyinIsOptional() {
        let model = CardEditorModel()
        model.german = "Apfel"
        model.hanzi = "苹果"
        #expect(model.pinyin.isEmpty)
        #expect(model.canSave)
    }

    @Test("Saving invalid input writes nothing")
    func invalidInputWritesNothing() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.german = "Apfel"
        // Hanzi deliberately missing.
        #expect(throws: AppError.self) {
            try model.save(into: context)
        }

        #expect(try context.fetch(FetchDescriptor<Card>()).isEmpty)
    }

    // MARK: - Creating

    @Test("A new card is stored with trimmed values")
    func newCardIsStoredTrimmed() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel(type: .sentence)
        model.german = "  Guten Morgen!  "
        model.hanzi = " 早上好！ "
        model.pinyin = "  zǎoshang hǎo  "
        model.status = .medium
        try model.save(into: context)

        let cards = try context.fetch(FetchDescriptor<Card>())
        let card = try #require(cards.first)
        #expect(cards.count == 1)
        #expect(card.type == .sentence)
        #expect(card.german == "Guten Morgen!")
        #expect(card.hanzi == "早上好！")
        #expect(card.pinyin == "zǎoshang hǎo")
        #expect(card.status == .medium)
    }

    @Test("A new card keeps the tags picked in the editor")
    func newCardKeepsSelectedTags() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let food = Tag(name: "Essen")
        let everyday = Tag(name: "Alltag")
        context.insert(food)
        context.insert(everyday)
        try context.save()

        let model = CardEditorModel()
        model.german = "Wasser"
        model.hanzi = "水"
        model.toggle(food)
        model.toggle(everyday)
        try model.save(into: context)

        let card = try #require(try context.fetch(FetchDescriptor<Card>()).first)
        #expect(Set(card.tags.map(\.name)) == ["Essen", "Alltag"])
        #expect(food.cards.count == 1)
    }

    @Test("The editor opens on the card type the list is showing")
    func editorPreselectsTheListedType() {
        #expect(CardEditorModel(type: .sentence).type == .sentence)
        #expect(CardEditorModel(type: .word).type == .word)
    }

    // MARK: - Editing

    @Test("Editing updates every field of the existing card")
    func editingUpdatesTheCard() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let card = Card(type: .word, german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ")
        context.insert(card)
        try context.save()

        let model = CardEditorModel(card: card)
        #expect(model.isEditingExistingCard)
        #expect(model.german == "Apfel")

        model.german = "Birne"
        model.hanzi = "梨"
        model.pinyin = "lí"
        model.status = .good
        model.type = .sentence
        try model.save(into: context)

        #expect(try context.fetch(FetchDescriptor<Card>()).count == 1, "Editing must not create a second card")
        #expect(card.german == "Birne")
        #expect(card.hanzi == "梨")
        #expect(card.pinyin == "lí")
        #expect(card.status == .good)
        #expect(card.type == .sentence)
    }

    @Test("Editing replaces the tag assignment")
    func editingReplacesTags() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let food = Tag(name: "Essen")
        let travel = Tag(name: "Reisen")
        context.insert(food)
        context.insert(travel)
        let card = Card(type: .word, german: "Apfel", hanzi: "苹果", tags: [food])
        context.insert(card)
        try context.save()

        let model = CardEditorModel(card: card)
        model.toggle(food)      // remove
        model.toggle(travel)    // add
        try model.save(into: context)

        #expect(card.tags.map(\.name) == ["Reisen"])
        #expect(food.cards.isEmpty)
        // Removing the assignment must not delete the tag itself.
        #expect(try context.fetch(FetchDescriptor<Tag>()).count == 2)
    }

    // MARK: - Manual-edit flags

    @Test("An unchanged value leaves the flag alone")
    func unchangedValueKeepsFlag() {
        #expect(CardEditorModel.manualEditFlag(previous: "苹果", new: "苹果", wasManual: false) == false)
        #expect(CardEditorModel.manualEditFlag(previous: "苹果", new: "苹果", wasManual: true))
    }

    @Test("A changed value sets the flag")
    func changedValueSetsFlag() {
        #expect(CardEditorModel.manualEditFlag(previous: "苹果", new: "梨", wasManual: false))
    }

    @Test("A cleared value clears the flag, so automation may fill it again")
    func clearedValueClearsFlag() {
        #expect(CardEditorModel.manualEditFlag(previous: "píngguǒ", new: "", wasManual: true) == false)
    }

    @Test("A typed value on a fresh card counts as manual")
    func typedValueOnNewCardCountsAsManual() {
        #expect(CardEditorModel.manualEditFlag(previous: "", new: "苹果", wasManual: false))
        #expect(CardEditorModel.manualEditFlag(previous: "", new: "", wasManual: false) == false)
    }

    @Test("Creating a card marks the fields the user filled in")
    func creatingMarksFilledFields() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.german = "Apfel"
        model.hanzi = "苹果"
        // Pinyin left empty on purpose.
        try model.save(into: context)

        let card = try #require(try context.fetch(FetchDescriptor<Card>()).first)
        #expect(card.hanziWasEditedManually, "The user typed the Hanzi")
        #expect(card.pinyinWasEditedManually == false, "Empty Pinyin stays open for phase 3")
    }

    @Test("Reopening and saving a card unchanged does not mark it as edited")
    func resavingWithoutChangesDoesNotMarkAnything() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let card = Card(type: .word, german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ")
        context.insert(card)
        try context.save()
        #expect(card.hanziWasEditedManually == false)

        // This is the case the roadmap calls out: merely opening the editor and
        // hitting save must not claim the user hand-edited anything.
        let model = CardEditorModel(card: card)
        try model.save(into: context)

        #expect(card.hanziWasEditedManually == false)
        #expect(card.pinyinWasEditedManually == false)
    }

    @Test("Changing only Hanzi marks only Hanzi")
    func changingHanziMarksOnlyHanzi() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let card = Card(type: .word, german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ")
        context.insert(card)
        try context.save()

        let model = CardEditorModel(card: card)
        model.hanzi = "梨"
        try model.save(into: context)

        #expect(card.hanziWasEditedManually)
        #expect(card.pinyinWasEditedManually == false)
    }

    @Test("A whitespace-only change is not a change")
    func whitespaceOnlyChangeIsNoChange() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let card = Card(type: .word, german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ")
        context.insert(card)
        try context.save()

        let model = CardEditorModel(card: card)
        model.hanzi = "  苹果  "
        try model.save(into: context)

        #expect(card.hanzi == "苹果")
        #expect(card.hanziWasEditedManually == false)
    }

    @Test("An already manual field stays manual after an unrelated edit")
    func manualFlagSurvivesUnrelatedEdits() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let card = Card(
            type: .word, german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ",
            pinyinWasEditedManually: true
        )
        context.insert(card)
        try context.save()

        let model = CardEditorModel(card: card)
        model.german = "Grüner Apfel"
        try model.save(into: context)

        #expect(card.pinyinWasEditedManually, "Editing German must not reset the Pinyin flag")
    }

    // MARK: - Adding tags from the editor

    @Test("A new tag name is queued and the input field is cleared")
    func addingNewTagQueuesIt() {
        let model = CardEditorModel()
        model.newTagName = "  Hotel  "
        model.addNewTag(existingTags: [])

        #expect(model.pendingTagNames == ["Hotel"], "Tidied up, casing preserved")
        #expect(model.newTagName.isEmpty, "The input field is cleared after adding")
        #expect(model.selectedTags.isEmpty, "Nothing is selected yet — the tag does not exist")
    }

    @Test("A name that is too long is rejected")
    func overlongTagNameIsRejected() {
        let model = CardEditorModel()
        model.newTagName = String(repeating: "a", count: TagNormalization.maximumLength + 1)
        #expect(model.canAddNewTag == false)
        model.addNewTag(existingTags: [])
        #expect(model.pendingTagNames.isEmpty)
    }

    @Test("A name made only of invisible characters is rejected")
    func invisibleTagNameIsRejected() {
        let model = CardEditorModel()
        model.newTagName = "\u{200B}\u{FEFF} "
        #expect(model.canAddNewTag == false)
        model.addNewTag(existingTags: [])
        #expect(model.pendingTagNames.isEmpty)
    }

    @Test("A name differing only in casing reuses the existing tag")
    func addingCasingVariantReusesExistingTag() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let food = Tag(name: "Essen")
        context.insert(food)
        try context.save()

        let model = CardEditorModel()
        model.newTagName = "  eSSEn "
        model.addNewTag(existingTags: [food])

        let tags = try context.fetch(FetchDescriptor<Tag>())
        #expect(tags.count == 1, "No second tag may appear")
        #expect(tags.first?.name == "Essen", "The original spelling is kept")
        #expect(model.selectedTags.first === food)
    }

    @Test("A new tag reaches the store only when the card is saved")
    func newTagIsNotStoredBeforeSaving() throws {
        // The bug this guards against: a cancelled editor used to leave the
        // tag behind, and the app has no way to delete a tag again.
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.newTagName = "Hotel"
        model.addNewTag(existingTags: [])

        #expect(model.pendingTagNames == ["Hotel"])
        #expect(try context.fetch(FetchDescriptor<Tag>()).isEmpty, "Nothing may be stored yet")

        // Abandoning the editor: no save call at all.
        #expect(try context.fetch(FetchDescriptor<Tag>()).isEmpty)
    }

    @Test("Saving turns the queued name into a real tag on the card")
    func savingCreatesThePendingTag() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.german = "Zimmer"
        model.hanzi = "房间"
        model.newTagName = "Hotel"
        model.addNewTag(existingTags: [])
        try model.save(into: context)

        let tags = try context.fetch(FetchDescriptor<Tag>())
        #expect(tags.count == 1)
        #expect(tags.first?.name == "Hotel")
        let card = try #require(try context.fetch(FetchDescriptor<Card>()).first)
        #expect(card.tags.map(\.name) == ["Hotel"])
    }

    @Test("A queued name can be taken back before saving")
    func pendingTagCanBeRemoved() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.german = "Zimmer"
        model.hanzi = "房间"
        model.newTagName = "Essne"
        model.addNewTag(existingTags: [])
        model.removePendingTag("Essne")
        try model.save(into: context)

        #expect(try context.fetch(FetchDescriptor<Tag>()).isEmpty)
    }

    @Test("Two queued names differing only in casing produce one tag")
    func queuedCasingVariantsCollapseIntoOneTag() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.german = "Wasser"
        model.hanzi = "水"
        model.newTagName = "Essen"
        model.addNewTag(existingTags: [])
        model.newTagName = "ESSEN"
        model.addNewTag(existingTags: [])

        #expect(model.pendingTagNames == ["Essen"])
        try model.save(into: context)
        #expect(try context.fetch(FetchDescriptor<Tag>()).count == 1)
    }

    @Test("Saving an incomplete card throws instead of silently doing nothing")
    func savingIncompleteCardThrows() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.german = "Apfel"
        // Hanzi missing.

        #expect(throws: AppError.self) {
            try model.save(into: context)
        }
    }

    @Test("Adding a blank name does nothing")
    func addingBlankNameDoesNothing() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.newTagName = "   "
        #expect(model.canAddNewTag == false)
        model.addNewTag(existingTags: [])

        #expect(try context.fetch(FetchDescriptor<Tag>()).isEmpty)
        #expect(model.selectedTags.isEmpty)
    }

    @Test("Adding an already selected tag does not duplicate the selection")
    func addingSelectedTagTwiceKeepsOneSelection() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let food = Tag(name: "Essen")
        context.insert(food)
        try context.save()

        let model = CardEditorModel()
        model.toggle(food)
        model.newTagName = "essen"
        model.addNewTag(existingTags: [food])

        #expect(model.selectedTags.count == 1)
    }

    @Test("Toggling a tag selects and deselects it")
    func togglingSelectsAndDeselects() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let food = Tag(name: "Essen")
        context.insert(food)
        try context.save()

        let model = CardEditorModel()
        #expect(model.isSelected(food) == false)
        model.toggle(food)
        #expect(model.isSelected(food))
        model.toggle(food)
        #expect(model.isSelected(food) == false)
    }

    // MARK: - Persistence

    @Test("A card created in the editor survives reopening the store")
    func createdCardSurvivesRestart() throws {
        let store = TemporaryStore()
        defer { store.remove() }

        do {
            let container = try store.openContainer()
            let context = container.mainContext
            let food = Tag(name: "Essen")
            context.insert(food)

            let model = CardEditorModel()
            model.german = "Apfel"
            model.hanzi = "苹果"
            model.pinyin = "píngguǒ"
            model.status = .medium
            model.toggle(food)
            try model.save(into: context)
        }

        let reopened = try store.openContainer()
        let card = try #require(try reopened.mainContext.fetch(FetchDescriptor<Card>()).first)
        #expect(card.german == "Apfel")
        #expect(card.hanzi == "苹果")
        #expect(card.pinyin == "píngguǒ")
        #expect(card.status == .medium)
        #expect(card.tags.map(\.name) == ["Essen"])
        #expect(card.hanziWasEditedManually)
    }

    @Test("An edit survives reopening the store")
    func editSurvivesRestart() throws {
        let store = TemporaryStore()
        defer { store.remove() }

        do {
            let container = try store.openContainer()
            let context = container.mainContext
            let card = Card(type: .word, german: "Apfel", hanzi: "苹果")
            context.insert(card)
            try context.save()

            let model = CardEditorModel(card: card)
            model.status = .secure
            model.pinyin = "píngguǒ"
            try model.save(into: context)
        }

        let reopened = try store.openContainer()
        let card = try #require(try reopened.mainContext.fetch(FetchDescriptor<Card>()).first)
        #expect(card.status == .secure)
        #expect(card.pinyin == "píngguǒ")
        #expect(card.pinyinWasEditedManually)
    }
}
