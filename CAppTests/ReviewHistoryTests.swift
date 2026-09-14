//
//  ReviewHistoryTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

/// Phase 11 wired to SwiftData: what gets written, when the app stops asking,
/// and what it must never do on its own.
///
/// The rule itself is tested in `AssistedAssessmentTests` without a store.
/// What is checked here is the integration — that the session builds the
/// signals it claims to build, writes one entry per review, and leaves the
/// status alone when nobody rated anything.
@MainActor
struct ReviewHistoryTests {

    private static let reviewDate = Date(timeIntervalSince1970: 1_700_000_000)

    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        container = try makeInMemoryContainer()
        context = container.mainContext
    }

    @discardableResult
    private func insert(_ german: String, hanzi: String = "苹果", status: LearningStatus = .good) -> Card {
        let card = Card(type: .word, german: german, hanzi: hanzi, pinyin: "píngguǒ", status: status)
        context.insert(card)
        return card
    }

    private func model(direction: SessionDirection = .germanToChinese) -> LearnSessionModel {
        LearnSessionModel(
            configuration: SessionConfiguration(cardType: .word, direction: direction),
            generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
            now: { Self.reviewDate }
        )
    }

    /// Earlier clean attempts, newest last so the dates order correctly.
    private func seedCleanHistory(_ card: Card, count: Int, assessedAt index: Int? = nil) {
        for step in 0..<count {
            let log = ReviewLog(
                reviewedAt: Self.reviewDate.addingTimeInterval(Double(step) - Double(count) * 60),
                direction: .germanToChinese,
                previousStatus: card.status,
                usedSpeech: true,
                speechMatched: true,
                assessment: step == index ? .good : nil,
                card: card
            )
            context.insert(log)
        }
    }

    // MARK: - Every review is written down

    @Test("A rated review is recorded with what actually happened")
    func manualReviewIsLogged() throws {
        let card = insert("Apfel", status: .medium)
        try context.save()

        let session = model()
        session.start(in: context)
        session.reveal()
        session.submit(.good, in: context)

        let logs = try context.fetch(FetchDescriptor<ReviewLog>())
        let log = try #require(logs.first)
        #expect(logs.count == 1, "one entry per review, not one per tap")
        #expect(log.card?.id == card.id)
        #expect(log.reviewedAt == Self.reviewDate, "the session's clock, not the wall clock")
        #expect(log.direction == .germanToChinese)
        #expect(log.previousStatus == .medium, "the status *before* the rating")
        #expect(log.assessment == .good)
        #expect(log.usedSpeech == false)
        #expect(log.speechMatched == nil, "no speech, so nothing to say about a match")
        #expect(log.wasManualReveal, "the answer was uncovered by hand")
        #expect(log.wasRetry == false)
        #expect(card.status == .good, "and the phase-5 transition still applies")
    }

    @Test("Mode B is recorded as mode B")
    func directionIsRecorded() throws {
        insert("Apfel")
        try context.save()

        let session = model(direction: .audioToGerman)
        session.start(in: context)
        session.reveal()
        session.submit(.good, in: context)

        let log = try #require(try context.fetch(FetchDescriptor<ReviewLog>()).first)
        #expect(log.direction == .audioToGerman)
    }

    @Test("A retry is recorded as a retry")
    func retryIsRecorded() throws {
        // "Nochmal" puts the card back into the batch; the second attempt at
        // the same card inside one batch is not a first attempt.
        insert("Apfel", status: .medium)
        try context.save()

        let session = model()
        session.start(in: context)
        session.reveal()
        session.submit(.again, in: context)
        session.reveal()
        session.submit(.good, in: context)

        let logs = try context.fetch(FetchDescriptor<ReviewLog>())
            .sorted { $0.wasRetry == false && $1.wasRetry }
        #expect(logs.count == 2)
        #expect(logs.first?.wasRetry == false)
        #expect(logs.last?.wasRetry == true)
    }

    @Test("The history survives a restart")
    func historyIsPersisted() throws {
        let store = TemporaryStore()
        defer { store.remove() }

        do {
            let container = try store.openContainer()
            let context = container.mainContext
            let card = Card(type: .word, german: "Apfel", hanzi: "苹果", status: .good)
            context.insert(card)
            context.insert(ReviewLog(
                reviewedAt: Self.reviewDate, direction: .audioToGerman,
                previousStatus: .good, usedSpeech: true, speechMatched: true,
                assessment: .secure, card: card
            ))
            try context.save()
        }

        let container = try store.openContainer()
        let card = try #require(try container.mainContext.fetch(FetchDescriptor<Card>()).first)
        let log = try #require(card.reviews.first)
        #expect(log.direction == .audioToGerman, "raw values, so a rename cannot rewrite history")
        #expect(log.assessment == .secure)
        #expect(log.speechMatched == true)
        #expect(log.previousStatus == .good)
    }

    // MARK: - When the app stops asking

    @Test("A single match still asks, and changes nothing")
    func singleMatchAsks() throws {
        let card = insert("Apfel", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        session.applyRecognition(card.hanzi, forCardWith: card.id, in: context)

        #expect(session.isRevealed, "the card opens either way")
        #expect(session.suggestedAssessment == nil, "one match suggests nothing")
        #expect(card.status == .good, "and nothing moved")
        #expect(try context.fetch(FetchDescriptor<ReviewLog>()).isEmpty,
                "nothing is written until the review is finished")
    }

    @Test("A repeated clean match moves on without asking, and leaves the status alone")
    func repeatedMatchAutoAdvances() throws {
        insert("Apfel", status: .good)
        insert("Wasser", hanzi: "水")
        try context.save()

        let session = model()
        session.start(in: context)
        // Seeded onto whichever card was drawn, so the test does not depend
        // on the generator's order.
        let card = try #require(session.currentCard)
        seedCleanHistory(card, count: 1)
        try context.save()
        let before = session.answeredCount

        session.applyRecognition(card.hanzi, forCardWith: card.id, in: context)

        #expect(session.isRevealed == false, "the app has moved on")
        #expect(session.currentCard?.id != card.id)
        #expect(session.answeredCount == before + 1)
        #expect(card.status == .good, "**the status is untouched** — nobody rated anything")
        #expect(card.reviewCount == 1, "a review happened")
        // And `correctCount` deliberately does **not** move: „richtig" is a
        // judgement, and nobody made one. The only thing that happened is a
        // text match whose false-accept property phase 9 never measured
        // (`learning-engine.md` §7.1).
        #expect(card.correctCount == 0)

        // Counted, and told apart from the seeded one. The first version read
        // `card.reviews.first` on an **unordered** relationship whose seeded
        // entry carries the same four values — so „write no entry at all"
        // stayed green. The audit found it; this is the fix.
        #expect(card.reviews.count == 2, "the seeded one plus exactly one new one")
        let log = try #require(card.reviews.first { $0.reviewedAt == Self.reviewDate })
        #expect(log.assessment == nil, "an automatic review has no rating")
        #expect(log.usedSpeech)
        #expect(log.speechMatched == true)
        #expect(log.wasManualReveal == false)
        #expect(log.wasRetry == false)
        #expect(log.previousStatus == .good, "the status going into the attempt")
        #expect(log.direction == .germanToChinese)
    }

    @Test("A brand-new card is always rated by a person")
    func newCardAlwaysAsks() throws {
        insert("Apfel", status: .new)
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)
        // One **rated** clean review: enough of a run to skip the question on
        // any other card, and not enough automatic reviews to trigger the
        // recalibration. What is left is the rule about `new` — the first
        // version seeded four unrated reviews and passed because of
        // recalibration instead, which a counter-mutation exposed.
        seedCleanHistory(card, count: 1, assessedAt: 0)
        try context.save()
        session.applyRecognition(card.hanzi, forCardWith: card.id, in: context)

        #expect(session.isRevealed, "still on the card, waiting for a rating")
        #expect(card.status == .new)
    }

    @Test("A mismatch asks and never lowers anything")
    func mismatchAsksAndDoesNotDowngrade() throws {
        // Deliberately **not** at the top of the ladder and **not** with
        // enough history to trigger the recalibration: both produce „ask, no
        // suggestion" on their own, and the audit found this test leaning on
        // them instead of on the mismatch.
        insert("Apfel", status: .medium)
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)
        seedCleanHistory(card, count: 1, assessedAt: 0)
        try context.save()

        // Gegenprobe im selben Test: dieselbe Lage mit einem Treffer geht
        // durch. Also trägt unten wirklich der Mismatch und nichts sonst.
        #expect(AssistedAssessment.decision(
            currentStatus: .medium,
            current: ReviewSignal(direction: .germanToChinese, previousStatus: .medium,
                                  usedSpeech: true, speechMatched: true),
            history: card.reviews.map(\.signal)
        ) == .autoAdvance)

        session.applyRecognition("香蕉", forCardWith: card.id, in: context)

        #expect(session.speechCheck?.isMatch == false)
        #expect(session.isRevealed, "the learner decides what that was worth")
        #expect(session.suggestedAssessment == nil, "and gets no nudge in either direction")
        #expect(card.status == .medium, "a mismatch is not evidence against the card")
    }

    @Test("After enough automatic reviews the app asks again and highlights its pick")
    func recalibrationHighlights() throws {
        insert("Apfel", status: .medium)
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)
        seedCleanHistory(card, count: AssistedAssessment.autoAdvancesBeforeRecalibration)
        try context.save()
        session.applyRecognition(card.hanzi, forCardWith: card.id, in: context)

        #expect(session.isRevealed)
        #expect(session.suggestedAssessment == .good, "one step up, highlighted")
        #expect(card.status == .medium, "a highlight is not a result")
    }

    @Test("The learner can override the suggestion, and the override is what counts")
    func overrideWins() throws {
        insert("Apfel", status: .medium)
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)
        seedCleanHistory(card, count: AssistedAssessment.autoAdvancesBeforeRecalibration)
        try context.save()
        session.applyRecognition(card.hanzi, forCardWith: card.id, in: context)
        try #require(session.suggestedAssessment == .good)

        // The learner knows better: they guessed, or the recogniser was
        // generous. "Nochmal" wins, and it wins completely.
        session.submit(.again, in: context)

        #expect(card.status == .weak, "medium minus two, exactly as in phase 5")
        let log = try #require(card.reviews.sorted { $0.reviewedAt > $1.reviewedAt }.first)
        #expect(log.assessment == .again, "what the learner said, not what the app thought")
        #expect(log.speechMatched == true, "and the match is still recorded as the fact it was")
    }

    @Test("Without the microphone the app behaves exactly as in phase 10")
    func withoutSpeechNothingChanges() throws {
        insert("Apfel", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)
        seedCleanHistory(card, count: 5)
        try context.save()
        session.reveal()

        #expect(session.suggestedAssessment == nil, "no attempt was made, so nothing is suggested")
        #expect(session.isRevealed)
        session.submit(.good, in: context)
        #expect(card.status == .secure, "the phase-5 ladder, unchanged")
    }

    @Test("Revealing by hand rules out the shortcut, even after a match")
    func manualRevealRulesOutAutoAdvance() throws {
        insert("Apfel", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)
        seedCleanHistory(card, count: 3)
        try context.save()
        session.reveal()
        session.applyRecognition(card.hanzi, forCardWith: card.id, in: context)

        #expect(session.isRevealed, "still here")
        #expect(session.currentCard?.id == card.id)
        #expect(session.suggestedAssessment == nil, "reading the answer is not a recall")
    }


    // MARK: - The attempt state has to be reset between cards

    @Test("A manual reveal on one card does not disable the shortcut on the next")
    func revealStateIsResetBetweenCards() throws {
        // The mutation the audit named: drop `revealedByHand = false` from the
        // reset and the very first „Antwort zeigen" of a session would poison
        // every later card — no auto-advance again until the app restarts.
        insert("Apfel", hanzi: "苹果", status: .good)
        insert("Wasser", hanzi: "水", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        let first = try #require(session.currentCard)
        session.reveal()
        session.submit(.good, in: context)

        let second = try #require(session.currentCard)
        #expect(second.id != first.id)
        seedCleanHistory(second, count: 1, assessedAt: 0)
        try context.save()

        session.applyRecognition(second.hanzi, forCardWith: second.id, in: context)

        #expect(session.currentCard?.id != second.id, "the second card advanced on its own")
        let log = try #require(second.reviews.first { $0.assessment == nil && $0.reviewedAt == Self.reviewDate })
        #expect(log.wasManualReveal == false, "the previous card's reveal is not this card's")
    }

    @Test("Speech on one card does not colour the next card's entry")
    func speechStateIsResetBetweenCards() throws {
        // Same shape for `usedSpeechThisAttempt`: without the reset the next
        // card's entry would claim a microphone attempt that never happened,
        // with `speechMatched` nil — a record of something that did not occur.
        insert("Apfel", hanzi: "苹果", status: .good)
        insert("Wasser", hanzi: "水", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        let first = try #require(session.currentCard)
        session.applyRecognition(first.hanzi, forCardWith: first.id, in: context)
        session.submit(.good, in: context)

        let second = try #require(session.currentCard)
        session.reveal()
        session.submit(.good, in: context)

        let log = try #require(second.reviews.first)
        #expect(log.usedSpeech == false, "this card was never spoken")
        #expect(log.speechMatched == nil)
    }

    @Test("A retry with a matching attempt is still a retry, and still asks")
    func retryWithSpeechStillAsks() throws {
        // Retry **and** speech in one attempt — the combination no test had.
        // The rule must see `wasRetry` through `attemptSignal`, not only
        // through the stored entry.
        insert("Apfel", hanzi: "苹果", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)
        seedCleanHistory(card, count: 2)
        try context.save()

        session.reveal()
        session.submit(.again, in: context)
        #expect(session.currentCard?.id == card.id, "Nochmal keeps the card in the batch")

        session.applyRecognition(card.hanzi, forCardWith: card.id, in: context)

        #expect(session.currentCard?.id == card.id, "a second attempt is not a first one")
        #expect(session.isRevealed)
        #expect(session.suggestedAssessment == nil)
    }

    @Test("The newest reviews are the ones that count")
    func historyIsReadNewestFirst() throws {
        // Two entries that differ: an old clean one and a **newer** mismatch.
        // Read in the wrong order the run would look unbroken and the card
        // would advance on its own; read correctly the newer slip ends it.
        insert("Apfel", hanzi: "苹果", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)
        context.insert(ReviewLog(
            reviewedAt: Self.reviewDate.addingTimeInterval(-600),
            direction: .germanToChinese, previousStatus: .good,
            usedSpeech: true, speechMatched: true, card: card
        ))
        context.insert(ReviewLog(
            reviewedAt: Self.reviewDate.addingTimeInterval(-60),
            direction: .germanToChinese, previousStatus: .good,
            usedSpeech: true, speechMatched: false, assessment: .hard, card: card
        ))
        try context.save()

        session.applyRecognition(card.hanzi, forCardWith: card.id, in: context)

        #expect(session.currentCard?.id == card.id, "the newer slip breaks the run")
        #expect(session.isRevealed)
    }

    @Test("Auto-advancing the last card of a batch starts the next one")
    func autoAdvanceOnTheLastCardOfABatch() throws {
        // `skipCurrentCard()` empties the queue; the session has to notice and
        // draw a new batch rather than stall on an empty one.
        for index in 0..<12 { insert("Wort \(index)", hanzi: "苹果", status: .good) }
        try context.save()

        let session = model()
        session.start(in: context)

        // Resolve everything but the last card of the batch by hand.
        let size = session.currentBatchSize
        #expect(size > 1)
        for _ in 0..<(size - 1) {
            session.reveal()
            session.submit(.good, in: context)
        }

        let last = try #require(session.currentCard)
        seedCleanHistory(last, count: 1, assessedAt: 0)
        try context.save()

        session.applyRecognition(last.hanzi, forCardWith: last.id, in: context)

        #expect(session.currentCard != nil, "a new batch follows without a pause")
        #expect(session.answeredCount == size)
        #expect(session.currentBatchSize == size)
    }

}
