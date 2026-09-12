//
//  SpeechRecognitionTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

/// Phase 9 — what can honestly be tested without a microphone.
///
/// The split is stated rather than blurred. **Testable here:** which locale is
/// accepted, what a comparison produces, which card a result may touch, and
/// that recognition never rates anything. **Not testable here:** the
/// microphone, the audio conversion, the analyzer, and whether a tap reaches a
/// button. Those need hardware, and no amount of protocol-wrapping around
/// `AVAudioEngine` would change that — it would only produce a mock that
/// agrees with itself. They sit on the device checklist and are named there.
@MainActor
struct SpeechRecognitionTests {

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
        status: LearningStatus = .weak
    ) -> Card {
        let card = Card(type: .word, german: german, hanzi: hanzi, pinyin: pinyin, status: status)
        context.insert(card)
        return card
    }

    private func model(direction: SessionDirection = .germanToChinese) -> LearnSessionModel {
        LearnSessionModel(
            configuration: SessionConfiguration(cardType: .word, direction: direction),
            generator: AnyRandomNumberGenerator(SeededGenerator(seed: 5)),
            now: { Date(timeIntervalSince1970: 0) }
        )
    }

    // MARK: - Which Mandarin the app will accept

    @Test("Mainland Simplified is accepted")
    func mainlandSimplifiedIsAccepted() {
        #expect(MandarinRecognitionLocale.isMainlandSimplified(Locale(identifier: "zh-Hans-CN")))
        #expect(MandarinRecognitionLocale.isMainlandSimplified(Locale(identifier: "zh_CN")))
        #expect(MandarinRecognitionLocale.isMainlandSimplified(Locale(identifier: "zh-CN")))
    }

    @Test("Traditional and Cantonese are refused")
    func traditionalAndCantoneseAreRefused() {
        // The exact locales the device offers alongside zh_CN, measured in the
        // phase-9 spike. Accepting one of them would transcribe into
        // Traditional characters and compare them against a Simplified deck —
        // every answer would mismatch, and the reason would be invisible.
        #expect(MandarinRecognitionLocale.isMainlandSimplified(Locale(identifier: "zh_TW")) == false)
        #expect(MandarinRecognitionLocale.isMainlandSimplified(Locale(identifier: "zh_HK")) == false)
        #expect(MandarinRecognitionLocale.isMainlandSimplified(Locale(identifier: "yue_CN")) == false)
        #expect(MandarinRecognitionLocale.isMainlandSimplified(Locale(identifier: "zh-Hant-TW")) == false)
        #expect(MandarinRecognitionLocale.isMainlandSimplified(Locale(identifier: "en_US")) == false)

        // The two halves of the rule, each isolated. Every locale above
        // carries **both** a wrong script and a wrong region, so either check
        // alone would refuse them — a counter-probe showed that deleting the
        // script half left the whole suite green. These two cases each have
        // exactly one thing wrong with them, so each half is falsifiable on
        // its own.
        #expect(
            MandarinRecognitionLocale.isMainlandSimplified(Locale(identifier: "zh-Hant-CN")) == false,
            "right region, wrong script — only the script check refuses this"
        )
        #expect(
            MandarinRecognitionLocale.isMainlandSimplified(Locale(identifier: "zh-Hans-TW")) == false,
            "right script, wrong region — only the region check refuses this"
        )
    }

    @Test("A refused locale means the feature is unavailable, not a wrong variant")
    func refusedLocaleBecomesUnavailable() {
        // `accepted` is what the service hangs the decision on. Apple's
        // near-equivalence rule names only LanguageCode and Region — not
        // Script — so a request for Mainland Mandarin may legitimately come
        // back as Taiwan. Silently using it is the failure this guards.
        #expect(MandarinRecognitionLocale.accepted(Locale(identifier: "zh_TW")) == nil)
        #expect(MandarinRecognitionLocale.accepted(nil) == nil)
        #expect(MandarinRecognitionLocale.accepted(Locale(identifier: "zh_CN")) != nil)
    }

    @Test("The request the app makes is the fullest form")
    func theRequestIsSpecific() {
        let requested = MandarinRecognitionLocale.requested
        #expect(requested.language.languageCode?.identifier == "zh")
        #expect(requested.language.script?.identifier == "Hans")
        #expect(requested.region?.identifier == "CN")
        #expect(MandarinRecognitionLocale.isMainlandSimplified(requested), "we ask for what we accept")
    }

    // MARK: - The comparison

    @Test("A match is a match, and it goes through AnswerNormalization")
    func matchUsesNormalization() {
        #expect(SpeechCheck.compare(recognized: "苹果", expected: "苹果") == .match(recognized: "苹果"))

        // The whole point of reusing `AnswerNormalization`: punctuation and
        // whitespace the recogniser adds must not produce a mismatch. A plain
        // `==` would fail all three of these.
        #expect(SpeechCheck.compare(recognized: "苹果。", expected: "苹果").isMatch)
        #expect(SpeechCheck.compare(recognized: " 苹果 ", expected: "苹果").isMatch)
        #expect(SpeechCheck.compare(recognized: "我想吃点东西。", expected: "我 想 吃 点 东西").isMatch)
    }

    @Test("A mismatch carries both texts, and neither is called wrong")
    func mismatchCarriesBoth() {
        let check = SpeechCheck.compare(recognized: "香蕉", expected: "苹果")
        #expect(check == .mismatch(recognized: "香蕉", expected: "苹果"))
        #expect(check.isMatch == false)

        guard case .mismatch(let recognized, let expected) = check else {
            Issue.record("expected a mismatch")
            return
        }
        #expect(recognized == "香蕉", "what was heard")
        #expect(expected == "苹果", "what the card stores — which can itself be wrong")
    }

    @Test("There is no third outcome, and nothing carries a score")
    func onlyTwoOutcomes() {
        // The type is the guarantee: a confidence, a percentage or a star
        // rating would need somewhere to live, and there is nowhere. Hard
        // rule 7. If a case is ever added, this stops compiling.
        for check in [
            SpeechCheck.compare(recognized: "苹果", expected: "苹果"),
            SpeechCheck.compare(recognized: "香蕉", expected: "苹果"),
        ] {
            switch check {
            case .match(let recognized):
                #expect(recognized.isEmpty == false)
            case .mismatch(let recognized, let expected):
                #expect(recognized != expected)
            }
        }
    }

    @Test("Nothing is converted, corrected or scored on the way in")
    func nothingIsSmuggledIn() {
        // Simplified against Traditional stays a mismatch: converting scripts
        // would undo the locale validation that keeps Traditional output away
        // in the first place, and it would quietly accept an answer in the
        // wrong writing system.
        #expect(SpeechCheck.compare(recognized: "蘋果", expected: "苹果").isMatch == false)
        // No Pinyin bridge either.
        #expect(SpeechCheck.compare(recognized: "píngguǒ", expected: "苹果").isMatch == false)
        // And no similarity: one character off is off.
        #expect(SpeechCheck.compare(recognized: "苹里", expected: "苹果").isMatch == false)
    }

    // MARK: - Which card a result may touch

    @Test("A result for the card on screen lands and reveals it")
    func resultLandsOnItsOwnCard() throws {
        let card = insert("Apfel", hanzi: "苹果")
        try context.save()

        let session = model()
        session.start(in: context)
        let current = try #require(session.currentCard)
        #expect(session.speechCheck == nil)
        #expect(session.isRevealed == false)

        session.applyRecognition("苹果", forCardWith: current.id)

        #expect(session.speechCheck?.isMatch == true)
        #expect(session.isRevealed, "speaking checks the card, so the card opens")
        #expect(card.hanzi == "苹果", "and it is the card we inserted")
    }

    @Test("A result for a card the session has left is dropped")
    func lateResultForAnotherCardIsDropped() throws {
        insert("Apfel", hanzi: "苹果")
        try context.save()

        let session = model()
        session.start(in: context)
        _ = try #require(session.currentCard, "a card is on screen")

        // The id of a card that is not on screen — what a recording started
        // two cards ago would carry. Recognition is asynchronous, and the
        // learner can reveal, rate and move on while the analyzer finalises.
        session.applyRecognition("苹果", forCardWith: UUID())

        #expect(session.speechCheck == nil, "nothing attached itself to the wrong card")
        #expect(session.isRevealed == false, "and nothing revealed a card the learner is still working on")
    }

    @Test("The result is compared against the card it belongs to")
    func resultIsComparedAgainstTheRightCard() throws {
        let card = insert("Wasser", hanzi: "水")
        try context.save()

        let session = model()
        session.start(in: context)
        let current = try #require(session.currentCard)

        session.applyRecognition("苹果", forCardWith: current.id)
        #expect(session.speechCheck == .mismatch(recognized: "苹果", expected: "水"))
        #expect(card.hanzi == "水", "compared against this card, not another")
    }

    @Test("A new card starts with no recognition state")
    func newCardResetsTheResult() throws {
        insert("Apfel", hanzi: "苹果")
        insert("Wasser", hanzi: "水")
        insert("Brot", hanzi: "面包")
        try context.save()

        let session = model()
        session.start(in: context)
        let first = try #require(session.currentCard)

        session.applyRecognition("苹果", forCardWith: first.id)
        #expect(session.speechCheck != nil)

        session.submit(.good, in: context)

        #expect(session.currentCard !== first)
        #expect(session.speechCheck == nil, "the next card is not carrying the previous answer")
        #expect(session.isRevealed == false)
    }

    // MARK: - Recognition judges nothing

    @Test("Recognition never changes the learning status")
    func recognitionDoesNotRate() throws {
        let card = insert("Apfel", hanzi: "苹果", status: .weak)
        try context.save()

        let session = model()
        session.start(in: context)
        let current = try #require(session.currentCard)

        session.applyRecognition("苹果", forCardWith: current.id)

        #expect(card.status == .weak, "a match is not an assessment")
        #expect(session.answeredCount == 0, "and nothing was recorded")

        // Only the self-assessment moves it, exactly as before phase 9.
        session.submit(.good, in: context)
        #expect(card.status != .weak)
        #expect(session.answeredCount == 1)
    }

    @Test("A mismatch does not punish the card either")
    func mismatchDoesNotRate() throws {
        let card = insert("Apfel", hanzi: "苹果", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        let current = try #require(session.currentCard)

        session.applyRecognition("香蕉", forCardWith: current.id)

        #expect(card.status == .good, "the learner decides, not the recogniser")
        #expect(session.answeredCount == 0)
    }

    // MARK: - Where the microphone appears

    @Test("The microphone is offered in mode A before the reveal, and nowhere else")
    func microphoneOnlyInModeABeforeReveal() {
        #expect(RecordAnswerButton.isOffered(in: .germanToChinese, revealed: false))
        #expect(RecordAnswerButton.isOffered(in: .germanToChinese, revealed: true) == false,
                "speaking an answer already on screen proves nothing")
        // Mode B asks the learner for a meaning, not for Chinese. A
        // microphone there would pose a question the mode does not ask.
        #expect(RecordAnswerButton.isOffered(in: .audioToGerman, revealed: false) == false)
        #expect(RecordAnswerButton.isOffered(in: .audioToGerman, revealed: true) == false)
    }

    @Test("The button says something in every state and never lies about readiness")
    func buttonStateTable() {
        let states: [SpeechRecognitionService.Phase] = [
            .idle, .unavailable, .permissionDenied, .preparing,
            .downloading, .ready, .recording, .finalizing,
            .noSpeechDetected, .failed,
        ]
        for phase in states {
            #expect(RecordAnswerButton.title(for: phase).isEmpty == false, "\(phase)")
            #expect(RecordAnswerButton.symbol(for: phase).isEmpty == false, "\(phase)")
        }

        // Only a running recording stops; everything else starts.
        #expect(RecordAnswerButton.isStopping(at: .recording))
        for phase in states where phase != .recording {
            #expect(RecordAnswerButton.isStopping(at: phase) == false, "\(phase)")
        }

        // Nothing is tappable while the system is busy — a second tap during
        // preparation would start a recording the assets are not ready for.
        for phase in [SpeechRecognitionService.Phase.preparing, .downloading, .finalizing] {
            #expect(RecordAnswerButton.isEnabled(at: phase) == false, "\(phase)")
        }

        // A refused microphone stays tappable on purpose: the learner may
        // have granted it in the iOS settings since, and asking again is the
        // only way to find out. Refusing would strand them for the rest of
        // the app's run.
        #expect(RecordAnswerButton.isEnabled(at: .permissionDenied))
        #expect(RecordAnswerButton.isEnabled(at: .noSpeechDetected), "and trying again is the point")
        #expect(RecordAnswerButton.isHidden(at: .unavailable), "a permanently dead control invites taps")
        for phase in states where phase != .unavailable {
            #expect(RecordAnswerButton.isHidden(at: phase) == false, "\(phase)")
        }
    }

    @Test("Every state that needs explaining gets one, and no state passes a verdict")
    func everyStateExplainsItself() {
        // The silent cases used to be the problem: a recording that produced
        // nothing looked exactly like a bug, and an asset error never reached
        // the screen at all. Both now say something.
        #expect(RecordAnswerButton.note(for: .noSpeechDetected) != nil)
        #expect(RecordAnswerButton.note(for: .unavailable) != nil,
                "the button is hidden, so the sentence is all there is")
        #expect(RecordAnswerButton.note(for: .permissionDenied) != nil)

        // A real failure shows the real reason rather than a placeholder.
        let real = AppError.speechAssetsFailed(URLError(.notConnectedToInternet))
        #expect(RecordAnswerButton.note(for: .failed, failure: real) == real.message)
        #expect(RecordAnswerButton.note(for: .failed) != nil, "and there is always something to say")

        // Quiet where nothing needs saying.
        for phase in [SpeechRecognitionService.Phase.idle, .ready, .recording, .preparing, .downloading, .finalizing] {
            #expect(RecordAnswerButton.note(for: phase) == nil, "\(phase)")
        }

        // Hard rule 7 applies to every one of these sentences too: none of
        // them may comment on how the answer was spoken.
        for phase in [SpeechRecognitionService.Phase.idle, .unavailable, .permissionDenied,
                      .preparing, .downloading, .ready, .recording, .finalizing,
                      .noSpeechDetected, .failed] {
            let text = (RecordAnswerButton.note(for: phase) ?? "") + RecordAnswerButton.title(for: phase)
            for word in Self.forbiddenWordings {
                #expect(text.contains(word) == false, "\(phase) says \(word)")
            }
        }
    }

    /// Wordings no user-facing string may contain.
    ///
    /// The first seven are hard rule 7: nothing here measured pronunciation,
    /// tones or correctness, so nothing here may claim them. The last is the
    /// phase-9 lesson — `Antwort wahrscheinlich korrekt` was a statement about
    /// the **answer**, and the benchmark showed the transcriber returns a
    /// different Chinese text often enough that the claim had no ground. It
    /// is listed so it cannot quietly return.
    static let forbiddenWordings = [
        "ausgesproch", "Aussprache", "Ton", "korrekt gesprochen",
        "%", "Punkte", "Score",
        "wahrscheinlich korrekt",
    ]

    @Test("A match says what happened to the text, not what the learner did")
    func matchWordingIsNarrow() {
        #expect(SpeechCheck.matchTitle == "Erkannt wie erwartet")

        // Every user-facing string of this feature, in one place, against the
        // same list. `matchTitle` is what a learner reads after a successful
        // attempt, so it carries the strictest version of the rule.
        let visible = [
            SpeechCheck.matchTitle,
            SpeechCheck.recognizedLabel,
            SpeechCheck.expectedLabel,
        ]
        for text in visible {
            for word in Self.forbiddenWordings {
                #expect(text.contains(word) == false, "\(text.debugDescription) says \(word)")
            }
        }

        // The mismatch keeps naming both sides and judging neither.
        #expect(SpeechCheck.recognizedLabel == "Erkannt")
        #expect(SpeechCheck.expectedLabel == "Erwartet")
    }

    // MARK: - Everything still works without a microphone

    @Test("The manual reveal is untouched by phase 9")
    func manualRevealStillWorks() throws {
        let card = insert("Apfel", hanzi: "苹果", status: .medium)
        try context.save()

        let session = model()
        session.start(in: context)
        _ = try #require(session.currentCard, "a card is on screen")

        // No recognition anywhere in this flow — the path a learner without a
        // microphone, or without permission, takes every time.
        session.reveal()
        #expect(session.isRevealed)
        #expect(session.speechCheck == nil, "and the revealed card shows no recognition note")

        session.submit(.secure, in: context)
        #expect(session.answeredCount == 1)
        #expect(card.status != .medium)
    }
}
