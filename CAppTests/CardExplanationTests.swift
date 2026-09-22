//
//  CardExplanationTests.swift
//  CAppTests
//

import Foundation
import FoundationModels
import SwiftData
import Testing
@testable import CApp

/// Phase 14. What is testable here is everything **except** what the model says:
/// the value that reaches the sheet, the error mapping, the schema shape and the
/// two neutrality promises — nothing written, nothing in the session moved.
///
/// Deliberately no mock of `FoundationModels`. A fake that returns a canned
/// explanation would prove that the fake works; the model's behaviour was
/// measured on the device instead (`docs/apple-frameworks.md` §12).
@MainActor
struct CardExplanationTests {

    private static let reviewDate = Date(timeIntervalSince1970: 1_700_000_000)

    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        container = try makeInMemoryContainer()
        context = container.mainContext
    }

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

    // MARK: - The value that reaches the sheet

    @Test("The sheet receives the card's strings, not the card")
    func explainedCardCopiesTheStrings() throws {
        let card = insert("Apfel", hanzi: "苹果", pinyin: "píngguǒ")
        let explained = ExplainedCard(card)

        #expect(explained.id == card.id)
        #expect(explained.german == "Apfel")
        #expect(explained.hanzi == "苹果")
        #expect(explained.pinyin == "píngguǒ")
    }

    @Test("Reading a card for the sheet changes nothing about it")
    func explainedCardIsReadOnly() throws {
        let card = insert("Apfel")
        let before = Snapshot(card)

        _ = ExplainedCard(card)
        try context.save()

        #expect(Snapshot(card) == before)
    }

    // MARK: - The error mapping

    @Test("A rate limit becomes its own case, with German text and no detail")
    func rateLimitMapsToItsOwnCase() {
        let thrown = LanguageModelSession.GenerationError.rateLimited(
            .init(debugDescription: "GEHEIMES-DEBUG-DETAIL")
        )
        let mapped = CardExplanationGenerator.appError(for: thrown)

        guard case .explanationRateLimited = mapped else {
            Issue.record("expected .explanationRateLimited, got \(mapped)")
            return
        }
        // The measured reality is that this happens in the foreground, so the
        // text has to be something a user can act on.
        #expect(mapped.message.isEmpty == false)
        #expect(mapped.technicalDetail == nil)
        #expect(mapped.userText.contains("GEHEIMES-DEBUG-DETAIL") == false)
    }

    @Test("The iOS 27 rate limit is recognised as well", .enabled(if: ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))))
    @available(iOS 27.0, *)
    func newFamilyRateLimitIsRecognised() {
        // Measured necessity, not belt-and-braces: on the iPhone 16 Pro under
        // iOS 27.0 the spike's `as? GenerationError` cast **never matched**,
        // although the request had failed with a rate limit
        // (`docs/apple-frameworks.md` §12.8). Checking only the documented
        // deployment-target family would have dropped the one error path this
        // phase calls „not an edge case" — on exactly the OS where it is the
        // normal case.
        let thrown = LanguageModelError.rateLimited(
            .init(resetDate: nil, debugDescription: "GEHEIM")
        )
        let mapped = CardExplanationGenerator.appError(for: thrown)

        guard case .explanationRateLimited = mapped else {
            Issue.record("expected .explanationRateLimited, got \(mapped)")
            return
        }
        #expect(mapped.userText.contains("GEHEIM") == false)
    }

    @Test("Any other generation failure becomes one German message")
    func otherFailuresMapToOneCase() {
        let thrown = LanguageModelSession.GenerationError.decodingFailure(
            .init(debugDescription: "GEHEIMES-DEBUG-DETAIL")
        )
        let mapped = CardExplanationGenerator.appError(for: thrown)

        guard case .explanationFailed = mapped else {
            Issue.record("expected .explanationFailed, got \(mapped)")
            return
        }
        #expect(mapped.message.contains("nichts geändert"))
    }

    @Test(
        "No explanation error ever shows Apple's debug description",
        arguments: [
            LanguageModelSession.GenerationError.rateLimited(.init(debugDescription: "GEHEIM")),
            .decodingFailure(.init(debugDescription: "GEHEIM")),
            .guardrailViolation(.init(debugDescription: "GEHEIM")),
            .exceededContextWindowSize(.init(debugDescription: "GEHEIM")),
            .unsupportedLanguageOrLocale(.init(debugDescription: "GEHEIM")),
            .assetsUnavailable(.init(debugDescription: "GEHEIM")),
            .concurrentRequests(.init(debugDescription: "GEHEIM")),
            .unsupportedGuide(.init(debugDescription: "GEHEIM")),
            // The ninth case. `Refusal(transcriptEntries:)` is public, so the
            // list can claim completeness instead of only implying it.
            .refusal(.init(transcriptEntries: []), .init(debugDescription: "GEHEIM"))
        ]
    )
    func noErrorLeaksTheDebugDescription(thrown: LanguageModelSession.GenerationError) {
        let text = CardExplanationGenerator.appError(for: thrown).userText
        #expect(text.contains("GEHEIM") == false)
        #expect(text.isEmpty == false)
    }

    @Test("An AppError passes through instead of being wrapped twice")
    func appErrorPassesThrough() {
        let mapped = CardExplanationGenerator.appError(for: AppError.explanationRateLimited)
        guard case .explanationRateLimited = mapped else {
            Issue.record("expected the original case back, got \(mapped)")
            return
        }
    }

    // MARK: - The schema shape

    @Test("An example carries Chinese and German as two separate fields")
    func exampleHasTwoFields() {
        // The measured reason: with `[String]` the model filled slot 1 with
        // Chinese and slot 2 with German — one example as two entries.
        let example = CardExplanationExample(chinese: "苹果好吃", german: "Der Apfel schmeckt gut.")
        #expect(example.chinese == "苹果好吃")
        #expect(example.german == "Der Apfel schmeckt gut.")

        let explanation = CardExplanation(meaning: "m", usage: "g", examples: [example])
        #expect(explanation.examples.count == 1)
        #expect(explanation.examples.first?.chinese == "苹果好吃")
    }

    @Test("The app shows at most two examples, whatever the model returns")
    func atMostTwoExamplesAreShown() {
        // The `@Guide(.maximumCount(2))` tells the model; this enforces it.
        //
        // Why not a test on the schema instead: tried, and it does not work. A
        // differential check over `GenerationSchema`'s own `Codable` encoding
        // passed **with and without** the guide — so it could not fail and was
        // worth nothing. The limit is declared in the source, was honoured in
        // all five device measurements, and is guaranteed here.
        let many = (1...5).map { CardExplanationExample(chinese: "句\($0)", german: "Satz \($0)") }
        let explanation = CardExplanation(meaning: "m", usage: "g", examples: many)

        #expect(explanation.examples.count == 5, "the raw value is not trimmed")
        #expect(explanation.shownExamples.count == 2)
        #expect(explanation.shownExamples.map(\.chinese) == ["句1", "句2"])
        #expect(CardExplanation.maximumExamples == 2)
    }

    @Test("Fewer examples than the limit are all shown")
    func fewerExamplesPassThrough() {
        let one = CardExplanationExample(chinese: "苹果好吃", german: "Der Apfel schmeckt gut.")
        #expect(CardExplanation(meaning: "m", usage: "g", examples: [one]).shownExamples.count == 1)
        #expect(CardExplanation(meaning: "m", usage: "g", examples: []).shownExamples.isEmpty)
    }


    // MARK: - The real path, driven through the injected request

    /// Counts requests and decides what they do. Not a stand-in for the model:
    /// it has no opinion about what an explanation says, it only lets a test see
    /// the app's control flow. The model itself was measured on the device.
    @MainActor
    private final class Requests {
        private(set) var count = 0
        var result: Result<CardExplanation, any Error> = .success(
            CardExplanation(meaning: "Bedeutung", usage: "Gebrauch", examples: [])
        )

        /// Run **inside** a request, once, so a test can try to start a second
        /// one while the first is still in flight.
        ///
        /// Deterministic on purpose. The first version of this helper resumed a
        /// continuation and returned immediately — by the time the test tapped
        /// again the request had finished, `isGenerating` was already `false`,
        /// and the test failed for the wrong reason. Calling from inside the
        /// request needs no scheduling assumptions at all.
        var whileRunning: (() async -> Void)?
        private var reentered = false

        func explain(_ german: String, _ hanzi: String) async throws -> CardExplanation {
            count += 1
            if reentered == false, let whileRunning {
                // Once. Without the limit, removing the guard under test would
                // recurse forever and the mutation would hang instead of failing.
                reentered = true
                await whileRunning()
            }
            return try result.get()
        }
    }

    @Test("Opening the sheet asks nothing")
    func openingAsksNothing() async {
        let requests = Requests()
        _ = CardExplanationModel(card: Self.sample, explain: requests.explain)

        // `await Task.yield()` is what makes this falsifiable, and it was added
        // because the second audit showed the first version could not fail: a
        // `Task { await generate() }` in the initialiser would not have run
        // before a synchronous assertion, so the very mutation the test names
        // would have stayed green. Yielding lets such a task run first.
        await Task.yield()

        // The measured reason this matters: on the device only the first request
        // of a process succeeded. An automatic request on open would spend it.
        #expect(requests.count == 0)
    }

    @Test("One tap is exactly one request")
    func oneTapIsOneRequest() async {
        let requests = Requests()
        let model = CardExplanationModel(card: Self.sample, explain: requests.explain)

        await model.generate()

        #expect(requests.count == 1)
        #expect(model.explanation?.meaning == "Bedeutung")
        #expect(model.failure == nil)
        #expect(model.isGenerating == false)
    }

    @Test("A second request while one runs is refused")
    func noSecondRequestWhileGenerating() async {
        let requests = Requests()
        let model = CardExplanationModel(card: Self.sample, explain: requests.explain)

        // Ask again from inside the running request, where `isGenerating` is
        // still true. Without the guard the second call goes through — and by
        // the device measurement it would burn the request that works.
        requests.whileRunning = { await model.generate() }
        await model.generate()

        #expect(requests.count == 1)
        #expect(model.isGenerating == false, "the flag has to be cleared afterwards")
    }

    @Test("Generating again after a result is a second, deliberate request")
    func regeneratingIsASecondRequest() async {
        let requests = Requests()
        let model = CardExplanationModel(card: Self.sample, explain: requests.explain)

        await model.generate()
        #expect(model.hasExplanation)
        await model.generate()

        #expect(requests.count == 2, "Neu erzeugen must ask again, not reuse")
    }

    @Test("A failed retry keeps the text the user was reading")
    func failureKeepsThePreviousText() async {
        let requests = Requests()
        let model = CardExplanationModel(card: Self.sample, explain: requests.explain)

        await model.generate()
        let first = model.explanation
        #expect(first != nil, "the first request has to succeed for this test to mean anything")

        requests.result = .failure(
            LanguageModelSession.GenerationError.rateLimited(.init(debugDescription: "x"))
        )
        await model.generate()

        // Both at once: the message appears **and** the explanation stays.
        #expect(model.explanation == first)
        guard case .explanationRateLimited = model.failure else {
            Issue.record("expected the rate limit to surface, got \(String(describing: model.failure))")
            return
        }
        #expect(model.isGenerating == false, "the sheet has to stay usable")
    }

    @Test("A new request clears the previous failure when it starts")
    func startingClearsTheFailure() async {
        let requests = Requests()
        requests.result = .failure(
            LanguageModelSession.GenerationError.rateLimited(.init(debugDescription: "x"))
        )
        let model = CardExplanationModel(card: Self.sample, explain: requests.explain)
        await model.generate()
        #expect(model.failure != nil)

        // Checked **from inside** the next request, not after it. The weaker
        // version — assert afterwards — stayed green when the clearing was moved
        // into the success branch, and then a spinner and a stale error would
        // show at the same time. The second audit spotted that gap.
        var failureDuringRequest: AppError?
        requests.whileRunning = { failureDuringRequest = model.failure }
        requests.result = .success(CardExplanation(meaning: "m", usage: "g", examples: []))
        await model.generate()

        #expect(failureDuringRequest == nil, "the message has to go when the request starts")
        #expect(model.failure == nil)
        #expect(model.explanation?.meaning == "m")
    }

    private static let sample = ExplainedCard(german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ")

    // MARK: - Nothing is written

    @Test("A full explanation lifecycle leaves the store byte-identical")
    func nothingIsWritten() async throws {
        let first = insert("Apfel", hanzi: "苹果")
        let second = insert("essen", hanzi: "吃", status: .good)
        try context.save()

        let before = [Snapshot(first), Snapshot(second)]
        let countBefore = try context.fetchCount(FetchDescriptor<Card>())

        // **The real path this time.** The first version of this test called
        // three pure functions and compared before and after — which proves that
        // three pure functions are pure, and would have stayed green if someone
        // had put a `context.insert` into the sheet's generate action. The
        // independent audit was right about that, so the whole lifecycle runs
        // here: open, ask, succeed, ask again, fail, finish.
        let requests = Requests()
        let model = CardExplanationModel(card: ExplainedCard(first), explain: requests.explain)
        await model.generate()
        requests.result = .failure(
            LanguageModelSession.GenerationError.rateLimited(.init(debugDescription: "x"))
        )
        await model.generate()
        _ = model.failure?.userText
        try context.save()

        #expect(requests.count == 2, "the lifecycle really ran")
        #expect(try context.fetchCount(FetchDescriptor<Card>()) == countBefore)
        #expect([Snapshot(first), Snapshot(second)] == before)
        // And no review has appeared.
        #expect(try context.fetchCount(FetchDescriptor<ReviewLog>()) == 0)
    }

    // MARK: - The session does not move

    @Test("Looking a card up mid-session changes no session state")
    func sessionStateStaysNeutral() async throws {
        let card = insert("Apfel", hanzi: "苹果", status: .medium)
        // One clean attempt at this status, so the recognition below earns a
        // real offer. Without it `proposedStatus` is `nil` and this test would
        // compare `nil == nil` — which is exactly what the first version did,
        // because `reveal` sets `proposal = nil`. The audit found that; the
        // setup follows `LearnSessionModelTests`.
        context.insert(ReviewLog(
            reviewedAt: Self.reviewDate.addingTimeInterval(-60),
            direction: .germanToChinese, previousStatus: .medium,
            usedSpeech: true, speechMatched: true, card: card
        ))
        try context.save()

        let session = LearnSessionModel(
            configuration: SessionConfiguration(cardType: .word, tagKeys: []),
            generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
            now: { Self.reviewDate },
            defaults: .standard
        )
        session.start(in: context)
        session.applyRecognition("苹果", forCardWith: card.id)
        #expect(session.proposedStatus == .good, "there has to be an open offer to preserve")

        let sessionBefore = SessionSnapshot(session)
        let cardBefore = Snapshot(card)
        let reviewsBefore = try context.fetchCount(FetchDescriptor<ReviewLog>())

        // The whole sheet lifecycle over a session with a standing offer:
        // open, ask, succeed, ask again, fail. The sheet gets an `ExplainedCard`
        // and never the session — so there is no call it could make (A48). This
        // test pins that the path really is the value-only one: hand the sheet
        // the model or the context one day and the neutrality stops being
        // structural.
        let requests = Requests()
        let explanation = CardExplanationModel(
            card: ExplainedCard(card),
            explain: requests.explain
        )
        await explanation.generate()
        requests.result = .failure(
            LanguageModelSession.GenerationError.rateLimited(.init(debugDescription: "x"))
        )
        await explanation.generate()

        #expect(requests.count == 2, "the lifecycle really ran")
        #expect(session.proposedStatus == .good, "the offer must still be open")
        #expect(SessionSnapshot(session) == sessionBefore)
        #expect(Snapshot(card) == cardBefore)
        #expect(try context.fetchCount(FetchDescriptor<ReviewLog>()) == reviewsBefore)
    }

    // MARK: - Fixtures

    /// Everything about a card that any write in this app could move.
    private struct Snapshot: Equatable {
        let german: String
        let hanzi: String
        let pinyin: String
        let status: LearningStatus
        let reviewCount: Int
        let correctCount: Int
        let lastReviewedAt: Date?
        let evidenceReset: Date?
        let tagCount: Int

        init(_ card: Card) {
            german = card.german
            hanzi = card.hanzi
            pinyin = card.pinyin
            status = card.status
            reviewCount = card.reviewCount
            correctCount = card.correctCount
            lastReviewedAt = card.lastReviewedAt
            evidenceReset = card.classificationEvidenceResetAt
            tagCount = card.tags.count
        }
    }

    /// Everything observable about a running session.
    ///
    /// `@MainActor` because `LearnSessionModel` is — a nested type does not
    /// inherit the enclosing type's isolation, and reading the model from a
    /// nonisolated initialiser is exactly the kind of warning the project's
    /// zero-diagnostics gate exists to catch.
    @MainActor
    private struct SessionSnapshot: Equatable {
        let currentCardID: UUID?
        let isRevealed: Bool
        let hasShownHanzi: Bool
        let proposedStatus: LearningStatus?
        let answeredCount: Int
        let currentBatchSize: Int
        let poolCount: Int
        let speechCheck: SpeechCheck?

        init(_ model: LearnSessionModel) {
            currentCardID = model.currentCard?.id
            isRevealed = model.isRevealed
            hasShownHanzi = model.hasShownHanzi
            proposedStatus = model.proposedStatus
            answeredCount = model.answeredCount
            currentBatchSize = model.currentBatchSize
            poolCount = model.pool.count
            speechCheck = model.speechCheck
        }
    }
}
