//
//  SpeechIntegrationTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

/// Where the speaker appears, and which text it speaks.
///
/// These tests check the **conditions** the three call sites are built on,
/// not the rendered hierarchy: whether a `Button` really ends up on screen and
/// really receives the tap is a device question, and phase 6 showed twice that
/// it is one a simulator cannot settle. So the split is stated rather than
/// blurred — the decisions are here, the tap is on the physical checklist.
@MainActor
struct SpeechIntegrationTests {

    private func makeCard(
        hanzi: String = "苹果",
        german: String = "Apfel",
        pinyin: String = "píngguǒ",
        type: CardType = .word
    ) -> Card {
        Card(type: type, german: german, hanzi: hanzi, pinyin: pinyin, status: .weak)
    }

    // MARK: - Learn: only after revealing

    @Test("A session starts unrevealed, so no answer and no speaker")
    func learnStartsUnrevealed() throws {
        // The speaker lives inside the revealed answer, so this is the
        // condition that keeps it away: before revealing, the learner is
        // meant to produce the answer themselves, and sound would hand it
        // over.
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        context.insert(makeCard())
        try context.save()

        let model = LearnSessionModel(
            configuration: SessionConfiguration(cardType: .word),
            generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
            now: { Date(timeIntervalSince1970: 0) }
        )
        model.start(in: context)

        #expect(model.isRevealed == false)
        model.reveal()
        #expect(model.isRevealed, "and only then does the answer exist")
    }

    @Test("The learn speaker reads the card's Hanzi, not its Pinyin")
    func learnSpeaksTheHanzi() {
        // `LearnAnswer.hanzi(for:)` is the exact expression the view hands to
        // the button, so what it returns is what gets spoken.
        let card = makeCard(hanzi: "水果", pinyin: "shuíguǒ")
        #expect(LearnAnswer.hanzi(for: card) == "水果")
        #expect(SpeechSynthesisService.canSpeak(LearnAnswer.hanzi(for: card)))
        #expect(SpeechSynthesisService.canSpeak(LearnAnswer.pinyin(for: card)) == false)
    }

    @Test("A session card always has speakable Chinese")
    func sessionCardsAreSpeakable() throws {
        // The pool already requires Han script (`docs/learning-engine.md`
        // §9), so a card that reaches the learn mode can always be spoken —
        // the speaker never sits there hidden mid-session.
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        context.insert(makeCard())
        context.insert(makeCard(hanzi: "", german: "Ohne Hanzi", pinyin: ""))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Card>())
        let pool = LearnSessionModel.poolCards(
            from: all,
            configuration: SessionConfiguration(cardType: .word)
        )
        #expect(pool.isEmpty == false)
        for card in pool {
            #expect(SpeechSynthesisService.canSpeak(card.hanzi), "\(card.german)")
        }
    }

    // MARK: - Card list

    @Test("A card with Chinese offers speech, one without does not")
    func cardListCondition() {
        #expect(SpeechSynthesisService.canSpeak(makeCard().hanzi))
        #expect(SpeechSynthesisService.canSpeak(makeCard(hanzi: "").hanzi) == false)
        #expect(SpeechSynthesisService.canSpeak(makeCard(hanzi: "   ").hanzi) == false)
        // A card the user filled in by hand with nonsense also gets no dead
        // button.
        #expect(SpeechSynthesisService.canSpeak(makeCard(hanzi: "asdf").hanzi) == false)
    }

    @Test("Sentences are as speakable as words")
    func sentencesAreSpeakable() {
        let sentence = makeCard(
            hanzi: "我想吃点东西。",
            german: "Ich möchte etwas essen.",
            pinyin: "wǒ xiǎng chī diǎn dōngxī",
            type: .sentence
        )
        #expect(SpeechSynthesisService.canSpeak(sentence.hanzi))
    }

    // MARK: - Editor: the live text

    @Test("The editor speaks what is in the field, not what was saved")
    func editorSpeaksTheLiveText() throws {
        // The point of the speaker in the editor is checking a pronunciation
        // **before** saving: type German, get Hanzi, hear it. So the source
        // is the model's live `hanzi`, and the view passes exactly that.
        let card = makeCard(hanzi: "苹果")
        let model = CardEditorModel(card: card)
        #expect(model.hanzi == "苹果")

        // The user corrects the field and has not saved.
        model.hanzi = "水"
        #expect(model.hanzi == "水", "the live value is what a speaker would read")
        #expect(card.hanzi == "苹果", "and the card still holds the old one")
        #expect(SpeechSynthesisService.canSpeak(model.hanzi))
    }

    @Test("An empty or unusable editor field offers no speech")
    func editorWithoutUsableHanzi() {
        let model = CardEditorModel()
        #expect(model.hanzi.isEmpty)
        #expect(SpeechSynthesisService.canSpeak(model.hanzi) == false)

        model.hanzi = "asdf"
        #expect(SpeechSynthesisService.canSpeak(model.hanzi) == false)

        model.hanzi = "苹果"
        #expect(SpeechSynthesisService.canSpeak(model.hanzi))
    }

    @Test("Speaking in the editor touches no provenance and saves nothing")
    func editorSpeechChangesNothing() throws {
        // The phase-6 lesson applied to audio: a control tap must not make
        // the editor think a field was edited, and must not trigger a save
        // (A17, A19).
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let card = makeCard()
        context.insert(card)
        try context.save()

        let model = CardEditorModel(card: card)
        let before = (model.hanzi, model.pinyin, model.german,
                      model.hanziIsManual, model.pinyinIsManual, model.pinyinNeedsReview)

        let service = SpeechSynthesisService()
        defer { service.stop() }
        service.speak(model.hanzi)

        #expect(model.hanzi == before.0)
        #expect(model.pinyin == before.1)
        #expect(model.german == before.2)
        #expect(model.hanziIsManual == before.3)
        #expect(model.pinyinIsManual == before.4)
        #expect(model.pinyinNeedsReview == before.5)
        #expect(context.hasChanges == false)
    }

    // MARK: - The learning engine stays out of it

    @Test("Speech is not part of the learning engine")
    func engineUntouched() {
        // Phase 7 needed no change in `CApp/Learning/`, and this pins the
        // reason: the engine works on `CardSnapshot`, which carries an id and
        // a status and no text at all. There is nothing for a speaker to
        // reach into.
        let snapshot = CardSnapshot(id: UUID(), status: .medium)
        #expect(snapshot.status == .medium)
        // If a later phase adds text to the snapshot, this line stops
        // compiling and the question gets asked again.
        #expect(Mirror(reflecting: snapshot).children.count == 2)
    }
}
