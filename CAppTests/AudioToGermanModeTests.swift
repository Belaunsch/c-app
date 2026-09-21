//
//  AudioToGermanModeTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

/// Mode B — Chinese audio to German.
///
/// The load-bearing promise of this mode is a **negative** one: the middle
/// step shows the Hanzi and does **not** give the meaning away. A rule like
/// that decays quietly, because nothing fails when it stops holding — the
/// screen just becomes easier. So it is a pure function here rather than a
/// condition in a `body`, and it is asked in both directions.
///
/// What these tests cannot reach is stated rather than blurred: whether the
/// speaker is audible and whether the buttons receive their taps are device
/// questions, and they sit on the physical checklist.
@MainActor
struct AudioToGermanModeTests {

    let container: ModelContainer

    init() throws {
        container = try makeInMemoryContainer()
    }

    private var context: ModelContext { container.mainContext }

    @discardableResult
    private func insert(
        _ german: String,
        hanzi: String = "苹果",
        pinyin: String = "píngguǒ",
        type: CardType = .word,
        status: LearningStatus = .weak,
        tags: [Tag] = []
    ) -> Card {
        let card = Card(
            type: type, german: german, hanzi: hanzi, pinyin: pinyin,
            status: status, tags: tags
        )
        context.insert(card)
        return card
    }

    private func model(
        type: CardType = .word,
        tagKeys: Set<String> = [],
        direction: SessionDirection = .audioToGerman
    ) -> LearnSessionModel {
        LearnSessionModel(
            configuration: SessionConfiguration(
                cardType: type, tagKeys: tagKeys, direction: direction
            ),
            generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
            now: { Date(timeIntervalSince1970: 0) }
        )
    }

    // MARK: - The configuration

    @Test("A configuration written before phase 8 still means mode A")
    func directionDefaultsToModeA() {
        // The reason for the default: every phase-6 and phase-7 caller and
        // test says what it always said. Rewriting them all to spell out
        // "as before" would be churn that hides which call sites actually
        // chose a direction.
        #expect(SessionConfiguration(cardType: .word).direction == .germanToChinese)
        #expect(SessionConfiguration(cardType: .sentence, tagKeys: ["essen"]).direction
            == .germanToChinese)
    }

    @Test("Mode B is configured explicitly and nothing else changes with it")
    func directionIsIndependentOfTypeAndCategories() {
        let keys: Set<String> = ["essen", "reisen"]
        let audio = SessionConfiguration(cardType: .sentence, tagKeys: keys, direction: .audioToGerman)

        #expect(audio.direction == .audioToGerman)
        #expect(audio.cardType == .sentence, "the direction does not touch the type")
        #expect(audio.tagKeys == keys, "nor the categories")

        // Equality now sees the direction, which is what makes two otherwise
        // identical configurations distinguishable.
        let german = SessionConfiguration(cardType: .sentence, tagKeys: keys)
        #expect(audio != german)
        #expect(audio == SessionConfiguration(cardType: .sentence, tagKeys: keys, direction: .audioToGerman))
    }

    // MARK: - The stage rule

    @Test("The stage follows the two flags, and revealed always wins")
    func stageDerivation() {
        #expect(PromptStage.stage(isRevealed: false, hasShownHanzi: false) == .audioOnly)
        #expect(PromptStage.stage(isRevealed: false, hasShownHanzi: true) == .hanziShown)
        #expect(PromptStage.stage(isRevealed: true, hasShownHanzi: false) == .revealed)
        // Having taken the middle step cannot un-reveal a card.
        #expect(PromptStage.stage(isRevealed: true, hasShownHanzi: true) == .revealed)
    }

    @Test("Audio only means audio only — the writing is not on screen")
    func nothingIsVisibleAtFirst() {
        #expect(AudioPrompt.showsHanzi(at: .audioOnly) == false)
        #expect(AudioPrompt.allowsDecision(at: .audioOnly) == false)
        #expect(AudioPrompt.offersHanziStep(at: .audioOnly, in: .audioToGerman))
    }

    // What is **not** asserted here, and why it is not a gap: that the German
    // meaning and the Pinyin stay off screen before the reveal. There used to
    // be `AudioPrompt.showsGerman`/`showsPinyin` to ask, and tests that asked
    // them — but once the revealed card became a shared view, nothing in the
    // app called those functions any more. The assertions kept passing and
    // guarded nothing, which is worse than no assertion because it reads like
    // cover. The rule is now structural: `PromptAudioToGermanView.covered`
    // contains no German and no Pinyin, and the `switch` that selects it
    // takes no predicate that could be swapped. No unit test reaches a
    // `body`, so that half sits on the device checklist and says so.

    @Test("Hanzi anzeigen shows the Hanzi and does not open the answer")
    func theMiddleStepShowsOnlyTheWriting() {
        #expect(AudioPrompt.showsHanzi(at: .hanziShown))
        #expect(AudioPrompt.allowsDecision(at: .hanziShown) == false,
                "a half-open card cannot be rated, and the shared answer view is not reached")
        #expect(AudioPrompt.offersHanziStep(at: .hanziShown, in: .audioToGerman) == false,
                "already taken")
    }

    @Test("Only the last stage allows a rating")
    func revealShowsEverything() {
        #expect(AudioPrompt.showsHanzi(at: .revealed))
        #expect(AudioPrompt.allowsDecision(at: .revealed))
        #expect(AudioPrompt.offersHanziStep(at: .revealed, in: .audioToGerman) == false)
    }

    @Test("No stage before the last allows a rating")
    func nothingIsRateableBeforeTheEnd() {
        // Asked over all cases, so a fourth stage added later has to answer
        // this question rather than inherit an assumption. This is also the
        // rule the session's own guard enforces — `submit` is bound to
        // `isRevealed` — so the two cannot drift apart unnoticed.
        for stage in PromptStage.allCases where stage != .revealed {
            #expect(AudioPrompt.allowsDecision(at: stage) == false, "\(stage)")
        }
    }

    @Test("Mode A is never offered the middle step, at any stage")
    func modeANeverOffersTheHanziStep() {
        // Both halves of the rule in one place, so neither can be deleted
        // unnoticed. Without the direction check the button would appear in
        // mode A, where it sets a flag that view does not read — a control
        // on screen that visibly does nothing, with the whole suite green.
        for stage in PromptStage.allCases {
            #expect(AudioPrompt.offersHanziStep(at: stage, in: .germanToChinese) == false, "\(stage)")
        }
        #expect(AudioPrompt.offersHanziStep(at: .audioOnly, in: .audioToGerman),
                "and mode B does get it, exactly once")
    }

    // MARK: - The session

    @Test("A card in mode B starts covered")
    func sessionStartsAtAudioOnly() throws {
        insert("Apfel")
        try context.save()

        let session = model()
        session.start(in: context)

        #expect(session.currentCard != nil)
        #expect(session.promptStage == .audioOnly)
        #expect(session.isRevealed == false)
        #expect(session.hasShownHanzi == false)
    }

    @Test("Showing the Hanzi moves exactly one step, and repeating is harmless")
    func showHanziIsIdempotent() throws {
        insert("Apfel")
        try context.save()

        let session = model()
        session.start(in: context)

        session.showHanzi()
        #expect(session.promptStage == .hanziShown)
        #expect(session.isRevealed == false, "the answer is not out")

        session.showHanzi()
        session.showHanzi()
        #expect(session.promptStage == .hanziShown, "still the middle step, not further")
    }

    @Test("Revealing after the middle step lands on the answer")
    func revealAfterTheMiddleStep() throws {
        insert("Apfel")
        try context.save()

        let session = model()
        session.start(in: context)
        session.showHanzi()
        session.reveal(recordingWasPossible: false)

        #expect(session.promptStage == .revealed)
        #expect(session.isRevealed)
    }

    @Test("Revealing without the middle step works just as well")
    func revealDirectly() throws {
        insert("Apfel")
        try context.save()

        let session = model()
        session.start(in: context)
        session.reveal(recordingWasPossible: false)

        #expect(session.promptStage == .revealed, "the middle step is an offer, not a gate")
    }

    @Test("Closing the attempt before the full answer does nothing")
    func closingNeedsTheFullAnswer() throws {
        let card = insert("Apfel", status: .weak)
        try context.save()

        let session = model()
        session.start(in: context)

        session.moveOn(in: context)
        #expect(session.answeredCount == 0, "not closeable while only audio is out")
        #expect(card.status == .weak, "and the status is untouched")

        session.showHanzi()
        session.moveOn(in: context)
        #expect(session.answeredCount == 0, "nor from the middle step")
        #expect(card.status == .weak)

        session.reveal(recordingWasPossible: false)
        session.moveOn(in: context)
        #expect(session.answeredCount == 1, "only now")
        #expect(card.status == .weak, "and closing still changes no status (§13.3)")
    }

    @Test("The next card is covered again, and the middle step does not carry over")
    func nextCardStartsCovered() throws {
        insert("Apfel", hanzi: "苹果")
        insert("Wasser", hanzi: "水")
        insert("Brot", hanzi: "面包")
        try context.save()

        let session = model()
        session.start(in: context)

        let first = try #require(session.currentCard)
        session.showHanzi()
        session.reveal(recordingWasPossible: false)
        #expect(session.promptStage == .revealed)

        session.moveOn(in: context)

        #expect(session.currentCard != nil)
        #expect(session.currentCard !== first, "a different card")
        #expect(session.promptStage == .audioOnly, "covered again")
        #expect(session.hasShownHanzi == false, "the middle step did not carry over")
    }

    // MARK: - The pool is the same in both directions

    @Test("Both directions draw from exactly the same pool")
    func poolIsIdenticalInBothDirections() throws {
        let food = Tag(name: "Essen")
        let travel = Tag(name: "Reisen")
        context.insert(food)
        context.insert(travel)

        insert("Apfel", hanzi: "苹果", tags: [food])
        insert("Bahnhof", hanzi: "火车站", tags: [travel])
        insert("Uhr", hanzi: "钟", tags: [])
        insert("Guten Morgen!", hanzi: "早上好！", type: .sentence, tags: [food])
        try context.save()

        let all = try context.fetch(FetchDescriptor<Card>())
        let keys: Set<String> = [TagNormalization.key(for: "Essen")]

        for type in CardType.allCases {
            for selection in [Set<String>(), keys] {
                let german = LearnSessionModel.poolCards(
                    from: all,
                    configuration: SessionConfiguration(cardType: type, tagKeys: selection)
                )
                let audio = LearnSessionModel.poolCards(
                    from: all,
                    configuration: SessionConfiguration(
                        cardType: type, tagKeys: selection, direction: .audioToGerman
                    )
                )
                // Without this, two empty pools would satisfy the comparison
                // below and the test would pass for the wrong reason.
                #expect(german.isEmpty == false, "\(type.title), selection \(selection): empty pool")
                #expect(german.map(\.id) == audio.map(\.id),
                        "\(type.title), selection \(selection)")
            }
        }
    }

    @Test("A card without usable Chinese is out of the audio pool too")
    func cardsWithoutHanziAreExcludedFromModeB() throws {
        // Task 8.7. It is already satisfied by the shared pool rule from
        // phase 6, so nothing direction-specific was added — this is the
        // test that says so, and that would notice if the shared filter were
        // ever removed on the assumption that only mode A needed it.
        insert("Apfel", hanzi: "苹果")
        insert("Ohne Chinesisch", hanzi: "")
        insert("Nur Leerzeichen", hanzi: "   ")
        insert("Lateinisch", hanzi: "pingguo")
        try context.save()

        let all = try context.fetch(FetchDescriptor<Card>())
        let pool = LearnSessionModel.poolCards(
            from: all,
            configuration: SessionConfiguration(cardType: .word, direction: .audioToGerman)
        )

        #expect(pool.map(\.german) == ["Apfel"])
        // A card with nothing to speak would be a silent prompt with no
        // question in it.
        for card in pool {
            #expect(SpeechSynthesisService.canSpeak(card.hanzi), "\(card.german)")
        }
    }

    @Test("Categories stay OR and types stay apart in mode B")
    func categoriesAndTypesBehaveAsBefore() throws {
        let food = Tag(name: "Essen")
        let travel = Tag(name: "Reisen")
        context.insert(food)
        context.insert(travel)

        insert("Apfel", hanzi: "苹果", tags: [food])
        insert("Bahnhof", hanzi: "火车站", tags: [travel])
        insert("Uhr", hanzi: "钟", tags: [])
        insert("Wo ist der Bahnhof?", hanzi: "火车站在哪里？", type: .sentence, tags: [travel])
        try context.save()

        let all = try context.fetch(FetchDescriptor<Card>())
        let both: Set<String> = [
            TagNormalization.key(for: "Essen"),
            TagNormalization.key(for: "Reisen"),
        ]

        let words = LearnSessionModel.poolCards(
            from: all,
            configuration: SessionConfiguration(
                cardType: .word, tagKeys: both, direction: .audioToGerman
            )
        )
        #expect(Set(words.map(\.german)) == ["Apfel", "Bahnhof"], "union, not intersection")
        #expect(words.contains { $0.type == .sentence } == false, "and no sentence slipped in")
    }

    // MARK: - Both directions are status-neutral (phase 13)

    @Test("Closing an attempt changes no status, in either mode")
    func closingIsStatusNeutralInBothModes() throws {
        // Until phase 12 this test compared the four assessments across the two
        // modes, because the risk was an easier or harder path through the
        // statuses for audio. Phase 13 removed the assessments from the flow, so
        // the property to protect changed shape: **no** closing action moves a
        // status by itself, in either direction and from any starting point. The
        // only way up is a confirmed suggestion, and the only way down is the
        // card list.
        func statusAfterClosing(
            from start: LearningStatus,
            in direction: SessionDirection
        ) throws -> LearningStatus {
            let store = try makeInMemoryContainer()
            let context = store.mainContext
            let card = Card(
                type: .word, german: "Apfel", hanzi: "苹果",
                pinyin: "píngguǒ", status: start
            )
            context.insert(card)
            try context.save()

            let session = LearnSessionModel(
                configuration: SessionConfiguration(cardType: .word, direction: direction),
                generator: AnyRandomNumberGenerator(SeededGenerator(seed: 7)),
                now: { Date(timeIntervalSince1970: 0) }
            )
            session.start(in: context)
            #expect(session.currentCard === card, "\(direction) did not offer the card")

            session.reveal(recordingWasPossible: false)
            #expect(session.proposedStatus == nil, "\(direction): a manual reveal earns no offer")
            session.moveOn(in: context)
            #expect(session.answeredCount == 1, "\(direction) recorded nothing")

            return card.status
        }

        for start in LearningStatus.allCases {
            let viaGerman = try statusAfterClosing(from: start, in: .germanToChinese)
            let viaAudio = try statusAfterClosing(from: start, in: .audioToGerman)

            #expect(viaGerman == start, "mode A moved \(start) on its own")
            #expect(viaAudio == start, "mode B moved \(start) on its own")
            #expect(viaAudio == viaGerman, "the two modes disagree from \(start)")
        }
    }

    @Test("Mode B never gets a classification offer, however much history it has")
    func modeBNeverOffersAClassification() throws {
        let card = insert("Apfel", status: .medium)
        // A history that would earn a suggestion in mode A — but recorded in
        // mode B, where there is no speech and therefore no evidence.
        for index in 0..<5 {
            context.insert(ReviewLog(
                reviewedAt: Date(timeIntervalSince1970: Double(index)),
                direction: .audioToGerman,
                previousStatus: .medium,
                usedSpeech: true,
                speechMatched: true,
                card: card
            ))
        }
        try context.save()

        let session = model()
        session.start(in: context)
        session.showHanzi()
        session.reveal(recordingWasPossible: false)

        #expect(session.proposedStatus == nil, "mode B is status-neutral in phase 13")
        session.moveOn(in: context)
        #expect(card.status == .medium)
    }

    // MARK: - The shared revealed answer

    @Test("Both modes open the shared answer at exactly the same moment")
    func bothModesRevealAtTheSamePoint() throws {
        // Since phase 8 the fully revealed card is one view, `LearnRevealedAnswerView`,
        // used by both directions — the device test found mode B's
        // arrangement clearer, so mode A adopted it. But the two views reach
        // it through different gates: mode A branches on `isRevealed`, mode B
        // on the stage. If those ever disagreed, one mode would put the
        // shared answer — German meaning and all — on screen a step earlier
        // than the other, and in mode B that step is the middle one whose
        // whole purpose is to withhold it.
        for direction in [SessionDirection.germanToChinese, .audioToGerman] {
            let store = try makeInMemoryContainer()
            let context = store.mainContext
            context.insert(Card(type: .word, german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ"))
            try context.save()

            let session = LearnSessionModel(
                configuration: SessionConfiguration(cardType: .word, direction: direction),
                generator: AnyRandomNumberGenerator(SeededGenerator(seed: 3)),
                now: { Date(timeIntervalSince1970: 0) }
            )
            session.start(in: context)

            func gatesAgree(_ note: String) {
                #expect(session.isRevealed == AudioPrompt.allowsDecision(at: session.promptStage),
                        "\(direction) at \(note)")
            }

            gatesAgree("start")
            session.showHanzi()
            gatesAgree("after the middle step")
            session.reveal(recordingWasPossible: false)
            gatesAgree("after revealing")
            #expect(session.isRevealed, "\(direction) reached the answer")
        }
    }

    // MARK: - Mode A is untouched

    @Test("Mode A never enters the middle step")
    func modeAHasNoMiddleStep() throws {
        insert("Apfel")
        try context.save()

        let session = model(direction: .germanToChinese)
        session.start(in: context)

        #expect(session.hasShownHanzi == false)
        session.reveal(recordingWasPossible: false)
        #expect(session.promptStage == .revealed)
        #expect(AudioPrompt.allowsDecision(at: session.promptStage))
        // `showHanzi` is reachable in mode A only by writing code that calls
        // it; the view never does. Even then it changes nothing that mode A
        // reads, because `isRevealed` is what its prompt is driven by.
        session.showHanzi()
        #expect(session.isRevealed, "still revealed, unchanged")
    }
}
