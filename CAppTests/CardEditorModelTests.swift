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

    // MARK: - Provenance: automatic versus typed (Q9)

    @Test("A generated value does not count as hand-edited, not even on a new card")
    func generatedValueIsNotManual() throws {
        // This is the Q9 fix. Phase 2 compared against the stored value, which
        // is empty on a new card — a generated value would have been marked
        // manual and the automation would never have fired again.
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.german = "Apfel"
        model.applyGeneratedHanzi("苹果")
        model.applyGeneratedPinyin("píngguǒ")

        #expect(model.hanziIsManual == false)
        #expect(model.pinyinIsManual == false)

        try model.save(into: context)
        let card = try #require(try context.fetch(FetchDescriptor<Card>()).first)
        #expect(card.hanziWasEditedManually == false)
        #expect(card.pinyinWasEditedManually == false)
    }

    @Test("A typed value counts as hand-edited")
    func typedValueIsManual() {
        let model = CardEditorModel()
        model.applyGeneratedHanzi("苹果")

        model.hanzi = "水"
        model.hanziEditingEnded()
        #expect(model.hanziIsManual)
    }

    @Test("Re-typing the exact same value is not an edit")
    func retypingTheSameValueIsNoEdit() {
        let model = CardEditorModel()
        model.applyGeneratedHanzi("苹果")

        model.hanzi = "  苹果  "
        model.hanziEditingEnded()
        #expect(model.hanziIsManual == false)
    }

    @Test("Clearing a field releases it back to automation")
    func clearingAFieldReleasesIt() {
        let model = CardEditorModel()
        model.applyGeneratedPinyin("píngguǒ")
        model.pinyin = "hand-corrected"
        model.pinyinEditingEnded()
        #expect(model.pinyinIsManual)

        model.pinyin = ""
        model.pinyinEditingEnded()
        #expect(model.pinyinIsManual == false, "An empty field has nothing to protect")
    }

    // MARK: - The Hanzi → Pinyin chain

    @Test("Finishing a Hanzi edit derives the Pinyin")
    func hanziEditDerivesPinyin() {
        let model = CardEditorModel()
        model.hanzi = "苹果"
        model.hanziEditingEnded()
        #expect(model.pinyin == "píngguǒ")
    }

    @Test("Correcting the Hanzi re-derives the Pinyin from the new value")
    func correctingHanziRederivesPinyin() {
        // The explicit product decision: Hanzi is the source of truth for
        // automatically generated Pinyin.
        let model = CardEditorModel()
        model.applyGeneratedHanzi("苹果")
        model.applyGeneratedPinyin("píngguǒ")

        model.hanzi = "水"
        model.hanziEditingEnded()

        #expect(model.hanzi == "水")
        #expect(model.pinyin == "shuǐ")
        #expect(model.hanziIsManual, "The user typed this Hanzi")
        #expect(model.pinyinIsManual == false, "The Pinyin came from automation")
    }

    @Test("A hand-corrected Pinyin survives a Hanzi change")
    func manualPinyinSurvivesHanziChange() {
        let model = CardEditorModel()
        model.applyGeneratedHanzi("苹果")
        model.applyGeneratedPinyin("píngguǒ")

        model.pinyin = "ping guo"
        model.pinyinEditingEnded()
        #expect(model.pinyinIsManual)

        model.hanzi = "水"
        model.hanziEditingEnded()

        #expect(model.hanzi == "水")
        #expect(model.pinyin == "ping guo", "The hand-corrected value must not be overwritten silently")
    }

    @Test("The regenerate button replaces even a hand-corrected Pinyin")
    func regenerateButtonOverwritesManualPinyin() {
        let model = CardEditorModel()
        model.hanzi = "水"
        model.pinyin = "völlig falsch"
        model.pinyinEditingEnded()
        #expect(model.pinyinIsManual)

        model.regeneratePinyin()

        #expect(model.pinyin == "shuǐ")
        #expect(model.pinyinIsManual == false, "After a deliberate regeneration the value is automatic again")
    }

    @Test("Finishing the Hanzi field fills a Pinyin that is still missing")
    func finishingHanziFillsAMissingPinyin() throws {
        // Return in the Hanzi field should produce the Pinyin even when the
        // Hanzi itself was not touched — an empty field has nothing to lose.
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let card = Card(type: .word, german: "danke", hanzi: "谢谢", pinyin: "")
        context.insert(card)
        try context.save()

        let model = CardEditorModel(card: card)
        model.hanziEditingEnded()

        #expect(model.pinyin == "xièxiè")
        #expect(model.pinyinIsManual == false)
    }

    @Test("Hanzi that is not Chinese clears the automatic Pinyin")
    func invalidHanziClearsAutomaticPinyin() {
        // Reversed after the phase-4 device test. Keeping the old Pinyin
        // looked harmless until you see what it produces: the card would show
        // the reading of a word it no longer contains.
        let model = CardEditorModel()
        model.applyGeneratedHanzi("面包")
        model.applyGeneratedPinyin("miànbāo")

        model.hanzi = "asdf"
        model.hanziEditingEnded()

        #expect(model.hanzi == "asdf")
        #expect(model.pinyin.isEmpty, "miànbāo belongs to 面包, not to asdf")
        #expect(model.hanziHint != nil, "and the editor says why")
    }

    @Test("Hanzi that is not Chinese never deletes a hand-corrected Pinyin")
    func invalidHanziKeepsManualPinyin() {
        let model = CardEditorModel()
        model.applyGeneratedHanzi("面包")
        model.pinyin = "mian bao"
        model.pinyinEditingEnded()

        model.hanzi = "asdf"
        model.hanziEditingEnded()
        #expect(model.pinyin == "mian bao")

        // Not even the refresh control deletes it: the user typed it, and
        // there is nothing to put in its place.
        model.regeneratePinyin()
        #expect(model.pinyin == "mian bao")
        #expect(model.pinyinIsManual)
    }

    @Test("An unchanged Hanzi does not re-derive the Pinyin")
    func unchangedHanziKeepsStoredPinyin() throws {
        // Task 3.8 asks for re-derivation when the user *changes* the Hanzi.
        // Regenerating on every focus loss would replace a curated Pinyin
        // with the ICU rendering just from tabbing through the form.
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let card = Card(type: .word, german: "danke", hanzi: "谢谢", pinyin: "xièxie")
        context.insert(card)
        try context.save()

        let model = CardEditorModel(card: card)
        model.hanziEditingEnded()

        #expect(model.pinyin == "xièxie", "The curated value must survive")
    }

    @Test("Clearing the Hanzi clears the automatic Pinyin with it")
    func clearingHanziClearsAutomaticPinyin() {
        let model = CardEditorModel()
        model.hanzi = "苹果"
        model.hanziEditingEnded()
        #expect(model.pinyin == "píngguǒ")

        model.hanzi = ""
        model.hanziEditingEnded()
        #expect(model.pinyin.isEmpty)
    }

    @Test("The chain works for sentences too")
    func chainWorksForSentences() {
        // Goes through the real post-translation path, not through
        // `applyGeneratedHanzi` plus a focus loss: only that path chains
        // Hanzi → Pinyin, because a focus loss without a change no longer
        // re-derives anything.
        let model = CardEditorModel(type: .sentence)
        model.translationSupport = TranslationService.Support(availability: .installed)
        model.german = "Ich möchte etwas essen."

        model.completeTranslation(with: "我想吃点东西。")

        #expect(model.hanzi == "我想吃点东西。")
        // "dōngxī" is the known ICU rendering — conventional Pinyin writes
        // "dōngxi" with a neutral tone. See PinyinServiceTests.
        #expect(model.pinyin == "wǒ xiǎng chī diǎn dōngxī")
        #expect(model.hanziIsManual == false)
        #expect(model.pinyinIsManual == false)
    }

    @Test("A word card runs the same chain")
    func chainWorksForWords() {
        let model = CardEditorModel(type: .word)
        model.translationSupport = TranslationService.Support(availability: .installed)
        model.german = "Apfel"

        model.completeTranslation(with: "苹果")

        #expect(model.type == .word)
        #expect(model.hanzi == "苹果")
        #expect(model.pinyin == "píngguǒ")
    }

    // MARK: - What happens after a translation

    private func installedSupport() -> TranslationService.Support {
        TranslationService.Support(availability: .installed)
    }

    @Test("A finished translation fills Hanzi and Pinyin, both as automatic")
    func finishedTranslationFillsTheChain() {
        let model = CardEditorModel()
        model.translationSupport = installedSupport()
        model.german = "Apfel"

        model.completeTranslation(with: "苹果")

        #expect(model.hanzi == "苹果")
        #expect(model.pinyin == "píngguǒ")
        #expect(model.hanziIsManual == false)
        #expect(model.pinyinIsManual == false)
        #expect(model.isTranslating == false)
    }

    @Test("A finished translation never overwrites a hand-edited Hanzi")
    func finishedTranslationLeavesManualHanziAlone() {
        let model = CardEditorModel()
        model.translationSupport = installedSupport()
        model.german = "Apfel"
        model.hanzi = "水"
        model.hanziEditingEnded()

        model.completeTranslation(with: "苹果")

        #expect(model.hanzi == "水", "The value the user typed stays")
        #expect(model.pinyin == "shuǐ")
    }

    @Test("Typing while the translation runs is not overwritten")
    func inputDuringTranslationIsNotOverwritten() {
        // The reachable case: leaving the German field starts the translation,
        // and the way out of that field is usually a tap into the Hanzi field.
        // If the result landed blindly it would wipe what the user is typing —
        // and worse, mark it as automatic.
        let model = CardEditorModel()
        model.translationSupport = installedSupport()
        model.german = "Apfel"

        // Translation in flight; the user starts correcting.
        model.hanzi = "水"
        model.completeTranslation(with: "苹果")

        #expect(model.hanzi == "水", "The input must not be wiped")
        #expect(model.hanziIsManual, "And it must count as hand-edited")
    }

    @Test("Re-translating replaces Hanzi and Pinyin and makes both automatic again")
    func explicitRetranslationRegeneratesTheChain() {
        let model = CardEditorModel()
        model.translationSupport = installedSupport()
        model.german = "Apfel"
        model.hanzi = "水"
        model.hanziEditingEnded()
        model.pinyin = "hand-korrigiert"
        model.pinyinEditingEnded()
        #expect(model.hanziIsManual)
        #expect(model.pinyinIsManual)

        model.prepareExplicitRetranslation()
        model.completeTranslation(with: "苹果")

        #expect(model.hanzi == "苹果")
        #expect(model.pinyin == "píngguǒ", "The chain is regenerated in full")
        #expect(model.hanziIsManual == false, "Automatic again after a deliberate action")
        #expect(model.pinyinIsManual == false)
    }

    @Test("The overwrite permission is good for exactly one run")
    func overwritePermissionIsSpentAfterOneRun() {
        let model = CardEditorModel()
        model.translationSupport = installedSupport()
        model.german = "Apfel"
        model.hanzi = "水"
        model.hanziEditingEnded()

        model.prepareExplicitRetranslation()
        model.completeTranslation(with: "苹果")
        #expect(model.hanzi == "苹果")

        // The user corrects again and types new German text. The next
        // automatic run must not inherit the earlier permission.
        model.hanzi = "茶"
        model.hanziEditingEnded()
        model.german = "Tee"
        model.completeTranslation(with: "苹果")

        #expect(model.hanzi == "茶", "The permission was spent, so this stays")
    }

    @Test("A discarded stale run releases the spinner and the permission")
    func discardedRunReleasesItsState() {
        // The bug this guards against: the stale path used to return without
        // clearing state, leaving "Übersetze …" on screen forever and the
        // overwrite permission armed for the next automatic run.
        let model = CardEditorModel()
        model.translationSupport = installedSupport()
        model.german = "Apfel"
        model.hanzi = "水"
        model.hanziEditingEnded()
        model.prepareExplicitRetranslation()

        model.finishTranslationRun()
        #expect(model.isTranslating == false)

        // The permission is spent, so a later result — an automatic run for
        // the next German text — must leave the hand-typed Hanzi alone. Asked
        // as an outcome rather than as a predicate: this is what the user
        // would have lost.
        model.completeTranslation(with: "苹果")
        #expect(model.hanzi == "水", "The permission must not survive a discarded run")
        #expect(model.hanziIsManual)
    }

    @Test("An empty translation result leaves the fields alone and explains itself")
    func emptyTranslationResultIsReported() {
        let model = CardEditorModel()
        model.translationSupport = installedSupport()
        model.german = "Apfel"

        model.completeTranslation(with: "   ")

        #expect(model.hanzi.isEmpty)
        #expect(model.translationMessage != nil)
        #expect(model.isTranslating == false)
    }

    @Test("A translation error message does not block saving")
    func translationErrorDoesNotBlockSaving() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.translationSupport = installedSupport()
        model.german = "Apfel"
        model.finishTranslationRun(message: "Übersetzung nicht möglich.")
        #expect(model.translationMessage != nil)

        model.hanzi = "苹果"
        model.hanziEditingEnded()
        #expect(model.canSave)
        try model.save(into: context)

        #expect(try context.fetch(FetchDescriptor<Card>()).count == 1)
    }

    @Test("Saving fills a missing automatic Pinyin")
    func savingFillsMissingPinyin() throws {
        // "Type German, type Hanzi, hit save" must not store a card without
        // Pinyin just because tapping the toolbar did not move focus.
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.german = "Apfel"
        model.hanzi = "苹果"
        try model.save(into: context)

        let card = try #require(try context.fetch(FetchDescriptor<Card>()).first)
        #expect(card.pinyin == "píngguǒ")
        #expect(card.pinyinWasEditedManually == false)
    }

    @Test("Saving does not touch a hand-corrected Pinyin")
    func savingKeepsManualPinyin() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.german = "Apfel"
        model.hanzi = "苹果"
        model.pinyin = "ping guo"
        model.pinyinEditingEnded()
        try model.save(into: context)

        let card = try #require(try context.fetch(FetchDescriptor<Card>()).first)
        #expect(card.pinyin == "ping guo")
        #expect(card.pinyinWasEditedManually)
    }

    // MARK: - Saving reconciles the state (phase-4 device findings)

    @Test("Saving straight from the Hanzi field re-derives the Pinyin")
    func savingAfterHanziEditRegeneratesPinyin() throws {
        // The bug from the device test, verbatim: "Brot" translated to
        // 面包/miànbāo, the Hanzi was corrected to 水 by hand, and Save was
        // tapped without leaving the field. Stored was 水 with miànbāo.
        // Correctness must not depend on SwiftUI delivering a focus change.
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.translationSupport = installedSupport()
        model.german = "Brot"
        // Built through the real chain rather than through the two internal
        // seams: this is how 面包/miànbāo actually gets into the fields.
        #expect(model.germanEditingEnded())
        model.completeTranslation(with: "面包")
        #expect(model.pinyin == "miànbāo")

        model.hanzi = "水"
        try model.save(into: context)

        let card = try #require(try context.fetch(FetchDescriptor<Card>()).first)
        #expect(card.hanzi == "水")
        #expect(card.pinyin == "shuǐ")
        #expect(card.hanziWasEditedManually)
        #expect(card.pinyinWasEditedManually == false)
    }

    @Test("A translation that declines to overwrite leaves no stale Pinyin behind")
    func decliningTranslationDoesNotLeaveAStalePinyin() throws {
        // The same device bug on its second route, and the one the change-based
        // rule missed. `completeTranslation` reconciles the provenance before
        // it decides, which moves the Hanzi baseline forward — so by the time
        // the card is saved, "has the Hanzi changed?" answers no while the
        // Pinyin still describes the old word. Asking "was this Pinyin made
        // from this Hanzi?" gets it right.
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.translationSupport = installedSupport()
        model.german = "Brot"
        #expect(model.germanEditingEnded())
        model.completeTranslation(with: "面包")

        // Text changed, translation running, and the user types their own
        // Hanzi in the meantime — the editor's own normal flow.
        model.german = "Wasser"
        #expect(model.germanEditingEnded())
        model.hanzi = "水"
        model.completeTranslation(with: "水的翻译")

        #expect(model.hanzi == "水", "the typed Hanzi is protected")
        #expect(model.pinyin == "shuǐ", "and the Pinyin describes it, not 面包")

        try model.save(into: context)
        let card = try #require(try context.fetch(FetchDescriptor<Card>()).first)
        #expect(card.hanzi == "水")
        #expect(card.pinyin == "shuǐ")
    }

    @Test("That re-derivation still respects a hand-corrected Pinyin")
    func savingAfterHanziEditKeepsManualPinyin() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.german = "Brot"
        model.applyGeneratedHanzi("面包")
        model.pinyin = "mian bao"
        model.pinyinEditingEnded()

        model.hanzi = "水"
        try model.save(into: context)

        let card = try #require(try context.fetch(FetchDescriptor<Card>()).first)
        #expect(card.hanzi == "水")
        #expect(card.pinyin == "mian bao", "rule 5 outranks the re-derivation")
        #expect(card.pinyinWasEditedManually)
    }

    @Test("A Pinyin the user cleared stays cleared")
    func clearedPinyinIsNotFilledBackIn() throws {
        // "Pinyin kann leer bleiben" is what the editor promises. Clearing it
        // sets `pinyinIsManual` to false — an empty field has nothing to
        // protect — so without tracking the edit itself, saving would quietly
        // write the old value back.
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let card = Card(type: .word, german: "Brot", hanzi: "面包", pinyin: "miànbāo")
        context.insert(card)
        try context.save()

        let model = CardEditorModel(card: card)
        model.pinyin = ""
        model.pinyinEditingEnded()

        // Tabbing through the Hanzi field must not refill it either.
        model.hanziEditingEnded()
        #expect(model.pinyin.isEmpty)

        try model.save(into: context)
        #expect(card.pinyin.isEmpty, "saved as the user left it")
        #expect(card.hanzi == "面包")
    }

    @Test("Clearing the Pinyin and saving right away keeps it cleared")
    func clearedPinyinSurvivesAnImmediateSave() throws {
        // Same rule without any focus event in between.
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let card = Card(type: .word, german: "Brot", hanzi: "面包", pinyin: "miànbāo")
        context.insert(card)
        try context.save()

        let model = CardEditorModel(card: card)
        model.pinyin = ""
        try model.save(into: context)

        #expect(card.pinyin.isEmpty)
    }

    @Test("A changed Hanzi still fills a cleared Pinyin")
    func changedHanziFillsAClearedPinyin() {
        // The empty Pinyin belonged to the old word. A new word gets its own.
        let model = CardEditorModel()
        model.applyGeneratedHanzi("面包")
        model.applyGeneratedPinyin("miànbāo")

        model.pinyin = ""
        model.pinyinEditingEnded()
        #expect(model.pinyin.isEmpty)

        model.hanzi = "水"
        model.hanziEditingEnded()
        #expect(model.pinyin == "shuǐ")
    }

    @Test("The Hanzi field has to contain Chinese to be saveable")
    func savingRequiresHanCharacters() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.german = "Apfel"
        model.hanzi = "asdf"
        #expect(model.canSave == false)
        #expect(model.hanziHint != nil)
        #expect(throws: AppError.self) {
            try model.save(into: context)
        }
        #expect(try context.fetch(FetchDescriptor<Card>()).isEmpty)

        // Mixed content stays allowed as long as there is Chinese in it.
        model.hanzi = "苹果 asdf"
        #expect(model.canSave)
        #expect(model.hanziHint == nil)
    }

    @Test("Line breaks become spaces, ordinary spaces survive")
    func lineBreaksAreNormalized() throws {
        // No blanket ban on spaces: sentence cards need them, and so does
        // sentence Pinyin. Only line breaks are not card content.
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel(type: .sentence)
        model.german = "Ich möchte\netwas essen."
        _ = model.germanEditingEnded()
        #expect(model.german == "Ich möchte etwas essen.")

        model.hanzi = "我想吃点东西"
        try model.save(into: context)

        let card = try #require(try context.fetch(FetchDescriptor<Card>()).first)
        #expect(card.german == "Ich möchte etwas essen.")
        #expect(card.pinyin.contains(" "), "word spacing in the Pinyin stays")
    }

    @Test("A device without translation keeps saying so")
    func unsupportedDeviceKeepsItsNotice() {
        // The message used to live in one variable with the error text, so
        // leaving the German field cleared it and the footer went back to
        // promising automatic Hanzi on a device that cannot produce any.
        let model = CardEditorModel()
        model.translationSupport = .unsupported
        model.german = "Apfel"

        let message = model.translationMessage
        #expect(message?.contains("nicht verfügbar") == true)

        #expect(model.germanEditingEnded() == false)
        #expect(model.translationMessage == message, "still true after the field was left")

        model.hanzi = "苹果"
        model.hanziEditingEnded()
        #expect(model.translationMessage == message)
    }

    @Test("An error takes precedence, and the standing fact returns afterwards")
    func errorOutranksTheAvailabilityMessageOnlyWhileItLasts() {
        let model = CardEditorModel()
        model.translationSupport = TranslationService.Support(
            availability: .downloadable,
            isConfirmed: true
        )
        let standing = model.translationMessage
        #expect(standing?.contains("Sprachpaket") == true)

        model.finishTranslationRun(message: "Übersetzung nicht möglich.")
        #expect(model.translationMessage == "Übersetzung nicht möglich.")

        model.german = "Brot"
        _ = model.germanEditingEnded()
        #expect(model.translationMessage == standing, "the download hint is still the truth")
    }

    // MARK: - One user action, one translation

    @Test("Return and the focus change that follows translate only once")
    func returnAndFocusLossTranslateOnlyOnce() {
        // Return closes the keyboard by dropping the focus, so one keypress
        // can reach the model twice. The second one is not a request.
        let model = CardEditorModel()
        model.translationSupport = installedSupport()
        model.german = "Apfel"

        #expect(model.germanEditingEnded(), "Return starts the run")
        #expect(model.germanEditingEnded() == false, "the focus change does not start a second one")

        model.german = "Brot"
        #expect(model.germanEditingEnded(), "changed text is a new request")
    }

    @Test("A deliberate re-translation is not doubled by the focus change either")
    func explicitRetranslationIsNotDoubled() {
        let model = CardEditorModel()
        model.translationSupport = installedSupport()
        model.german = "Apfel"
        _ = model.germanEditingEnded()
        model.completeTranslation(with: "苹果")

        model.hanzi = "水"
        model.hanziEditingEnded()
        #expect(model.hanziIsManual)

        model.prepareExplicitRetranslation()
        // Real order: the tap may move the focus long before the translation
        // comes back, and the permission is still armed at that moment. That
        // is exactly when a second run must not start.
        #expect(model.germanEditingEnded() == false, "the focus change is not a second request")
        model.completeTranslation(with: "苹果")
        #expect(model.hanzi == "苹果", "the deliberate run still overwrites")
        #expect(model.hanziIsManual == false)
    }

    // MARK: - Translation gating

    @Test("A hand-edited Hanzi blocks the automatic translation")
    func manualHanziBlocksAutomaticTranslation() {
        let model = CardEditorModel()
        model.translationSupport = TranslationService.Support(
            availability: .installed, requiresLowLatencyStrategy: false
        )
        model.german = "Apfel"
        #expect(model.shouldTranslateAutomatically)

        model.hanzi = "水"
        model.hanziEditingEnded()
        #expect(model.shouldTranslateAutomatically == false)
    }

    @Test("The re-translate button lifts that block")
    func retranslateButtonLiftsTheBlock() {
        let model = CardEditorModel()
        model.translationSupport = TranslationService.Support(
            availability: .installed, requiresLowLatencyStrategy: false
        )
        model.german = "Apfel"
        model.hanzi = "水"
        model.hanziEditingEnded()
        #expect(model.shouldTranslateAutomatically == false)

        // The tap does not go through `shouldTranslateAutomatically` — the
        // view triggers the run directly. What matters is that the finished
        // run may now replace the hand-typed Hanzi.
        model.prepareExplicitRetranslation()
        model.completeTranslation(with: "苹果")
        #expect(model.hanzi == "苹果")
        #expect(model.hanziIsManual == false)
    }

    @Test("Without German text nothing is translated")
    func blankGermanTranslatesNothing() {
        let model = CardEditorModel()
        model.translationSupport = TranslationService.Support(
            availability: .installed, requiresLowLatencyStrategy: false
        )
        model.german = "   "
        #expect(model.shouldTranslateAutomatically == false)
        #expect(model.canTranslate == false)
    }

    @Test("A card is saveable even when translation is unavailable")
    func savingWorksWithoutTranslation() throws {
        // The automation must never block saving. Pinyin still works — it is
        // local and needs no models at all.
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let model = CardEditorModel()
        model.translationSupport = .unsupported
        model.german = "Apfel"
        model.hanzi = "苹果"
        model.hanziEditingEnded()

        #expect(model.canSave)
        try model.save(into: context)

        let card = try #require(try context.fetch(FetchDescriptor<Card>()).first)
        #expect(card.hanzi == "苹果")
        #expect(card.pinyin == "píngguǒ")
        #expect(card.hanziWasEditedManually, "Typed by hand because no translation ran")
    }

    @Test("Nothing is translated before the availability check has answered")
    func noTranslationBeforeAvailabilityIsKnown() {
        let model = CardEditorModel()
        model.german = "Apfel"
        #expect(model.translationSupport == nil)
        #expect(model.shouldTranslateAutomatically == false)
        #expect(model.canTranslate == false)
    }

    @Test("A downloadable pair may be translated")
    func downloadablePairMayBeTranslated() {
        let model = CardEditorModel()
        model.translationSupport = TranslationService.Support(availability: .downloadable)
        model.german = "Apfel"
        #expect(model.canTranslate)
        #expect(model.shouldTranslateAutomatically)
    }

    @Test("Pinyin can only be generated from actual Chinese")
    func pinyinNeedsHanzi() {
        let model = CardEditorModel()
        #expect(model.canGeneratePinyin == false)
        model.hanzi = "   "
        #expect(model.canGeneratePinyin == false)
        // Latin text is not Hanzi, so the refresh control stays disabled
        // instead of copying it into the Pinyin field.
        model.hanzi = "asdf"
        #expect(model.canGeneratePinyin == false)
        model.hanzi = "苹果"
        #expect(model.canGeneratePinyin)
    }

    @Test("On a device without support nothing is translated")
    func unsupportedDeviceTranslatesNothing() {
        let model = CardEditorModel()
        model.translationSupport = .unsupported
        model.german = "Apfel"
        #expect(model.shouldTranslateAutomatically == false)
        #expect(model.canTranslate == false)
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
