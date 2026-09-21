//
//  ReviewHistoryTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

/// The review history wired to SwiftData: what gets written, when the app offers
/// a new classification, and what it must never do on its own.
///
/// The rule itself is tested in `AssistedAssessmentTests` without a store. What
/// is checked here is the integration — that the session builds the signals it
/// claims to build, writes exactly one entry per closed attempt, and leaves the
/// status alone unless the learner confirms an offer.
///
/// **Rewritten for phase 13.** The phase-11 shape of these tests was „does the
/// app stop asking?"; the questions are gone, so the shape is now „does the app
/// offer the right step, and does it record what became of the offer?". Every
/// rule the phase-11 suite protected is still here, and the ones about
/// auto-advance became rules about the offer.
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

    /// Earlier clean attempts at the card's **current** status, newest last so
    /// the dates order correctly.
    ///
    /// The status matters since phase 13: only reviews taken at the card's
    /// current status are comparable, so seeding at any other status would seed
    /// evidence the rule must ignore.
    private func seedCleanHistory(_ card: Card, count: Int) {
        for step in 0..<count {
            let log = ReviewLog(
                reviewedAt: Self.reviewDate.addingTimeInterval(Double(step) - Double(count) * 60),
                direction: .germanToChinese,
                previousStatus: card.status,
                usedSpeech: true,
                speechMatched: true,
                card: card
            )
            context.insert(log)
        }
    }

    /// This card's reviews, newest first — a relationship is unordered.
    private func reviews(of card: Card) -> [ReviewLog] {
        card.reviews.sorted { $0.reviewedAt > $1.reviewedAt }
    }

    private func newestReview(of card: Card) -> ReviewLog? {
        reviews(of: card).first
    }

    /// A clock that moves, for the tests that write several entries.
    ///
    /// The rule reads history newest first, so entries written in one test have to
    /// be distinguishable by time. A frozen clock makes them all equal and the
    /// order undefined — which is a test that passes by luck.
    private final class AdvancingClock {
        private var offset: TimeInterval = 0
        private let base: Date

        init(from base: Date) { self.base = base }

        func next() -> Date {
            offset += 60
            return base.addingTimeInterval(offset)
        }
    }

    // MARK: - Every closed attempt is written down

    @Test("A given-up review is recorded with what actually happened")
    func givenUpReviewIsLogged() throws {
        let card = insert("Apfel", status: .medium)
        try context.save()

        let session = model()
        session.start(in: context)
        session.reveal(recordingWasPossible: true)
        session.moveOn(in: context)

        let logs = try context.fetch(FetchDescriptor<ReviewLog>())
        let log = try #require(logs.first)
        #expect(logs.count == 1, "one entry per attempt, not one per tap")
        #expect(log.card?.id == card.id)
        #expect(log.reviewedAt == Self.reviewDate, "the session's clock, not the wall clock")
        #expect(log.direction == .germanToChinese)
        #expect(log.previousStatus == .medium, "the status *before* the attempt")
        #expect(log.assessment == nil, "the new flow never writes a self-assessment")
        #expect(log.suggestedStatus == nil, "nothing was offered")
        #expect(log.suggestionDecision == nil)
        #expect(log.usedSpeech == false)
        #expect(log.speechMatched == nil, "no speech, so nothing to say about a match")
        #expect(log.wasManualReveal, "the answer was uncovered by hand")
        #expect(log.wasRetry == false)
        #expect(card.status == .medium, "and giving up moves nothing")
    }

    @Test("Mode B is recorded as mode B")
    func directionIsRecorded() throws {
        insert("Apfel")
        try context.save()

        let session = model(direction: .audioToGerman)
        session.start(in: context)
        session.reveal(recordingWasPossible: true)
        session.moveOn(in: context)

        let log = try #require(try context.fetch(FetchDescriptor<ReviewLog>()).first)
        #expect(log.direction == .audioToGerman)
    }

    @Test("A retry is recorded as a retry")
    func retryIsRecorded() throws {
        // „Aufgeben" puts the card back into the batch; the second attempt at
        // the same card inside one batch is not a first attempt.
        insert("Apfel", status: .medium)
        try context.save()

        let session = model()
        session.start(in: context)
        session.reveal(recordingWasPossible: true)
        session.moveOn(in: context)
        session.reveal(recordingWasPossible: true)
        session.moveOn(in: context)

        let logs = try context.fetch(FetchDescriptor<ReviewLog>())
            .sorted { $0.wasRetry == false && $1.wasRetry }
        #expect(logs.count == 2)
        #expect(logs.first?.wasRetry == false)
        #expect(logs.last?.wasRetry == true)
    }

    @Test("The history survives a restart, including a declined offer")
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
            context.insert(ReviewLog(
                reviewedAt: Self.reviewDate.addingTimeInterval(60),
                direction: .germanToChinese,
                previousStatus: .good, usedSpeech: true, speechMatched: true,
                suggestedStatus: .secure, suggestionDecision: .declined, card: card
            ))
            try context.save()
        }

        let container = try store.openContainer()
        let card = try #require(try container.mainContext.fetch(FetchDescriptor<Card>()).first)
        let sorted = card.reviews.sorted { $0.reviewedAt < $1.reviewedAt }
        #expect(sorted.count == 2)

        let historical = try #require(sorted.first)
        #expect(historical.direction == .audioToGerman, "raw values, so a rename cannot rewrite history")
        #expect(historical.assessment == .secure)
        #expect(historical.speechMatched == true)
        #expect(historical.previousStatus == .good)
        #expect(historical.suggestedStatus == nil, "the old flow made no offers")

        let declined = try #require(sorted.last)
        #expect(declined.suggestedStatus == .secure, "what was offered")
        #expect(declined.suggestionDecision == .declined, "and that it was turned down")
        #expect(declined.assessment == nil)
    }

    @Test("The two suggestion fields are set together or not at all")
    func suggestionFieldsAreConsistent() throws {
        let card = insert("Apfel", status: .medium)
        try context.save()

        // The probes live in a **container of their own**, for two reasons. They
        // must not end up on this card: assigning the relationship pulls the new
        // entry into the context, and the deliberately broken ones would then show
        // up in `card.reviews`, which the last assertion of this test reads. And
        // they must be inserted somewhere at all — a `@Model` that belongs to no
        // context has no backing store, and reading its properties takes the whole
        // test process down with it rather than failing one test.
        let probes = try makeInMemoryContainer()
        let probeContext = probes.mainContext
        func probe(_ status: LearningStatus?, _ decision: SuggestionDecision?) -> ReviewLog {
            let log = ReviewLog(suggestedStatus: status, suggestionDecision: decision)
            probeContext.insert(log)
            return log
        }

        // Both nil: a plain „Weiter".
        #expect(probe(nil, nil).hasConsistentSuggestion)
        // Both set: an offer with an outcome.
        #expect(probe(.good, .accepted).hasConsistentSuggestion)
        #expect(probe(.good, .declined).hasConsistentSuggestion)
        // Half set means nothing: an offer without an outcome is not a closed
        // attempt, and an outcome without an offer is not an outcome.
        #expect(probe(.good, nil).hasConsistentSuggestion == false)
        #expect(probe(nil, .accepted).hasConsistentSuggestion == false)

        // And what the flow itself writes is always consistent.
        let session = model()
        session.start(in: context)
        session.reveal(recordingWasPossible: true)
        session.moveOn(in: context)
        #expect(reviews(of: card).allSatisfy { $0.hasConsistentSuggestion })
    }

    // MARK: - When the app offers a new classification

    @Test("A single match offers nothing, and changes nothing")
    func singleMatchOffersNothing() throws {
        let card = insert("Apfel", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        session.applyRecognition(card.hanzi, forCardWith: card.id)

        #expect(session.isRevealed, "the card opens either way")
        #expect(session.proposedStatus == nil, "one match offers nothing")
        #expect(card.status == .good, "and nothing moved")
        #expect(try context.fetch(FetchDescriptor<ReviewLog>()).isEmpty,
                "nothing is written until the attempt is closed")
    }

    @Test("A repeated clean match offers one step up, and changes nothing by itself")
    func repeatedMatchOffersAStep() throws {
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

        session.applyRecognition(card.hanzi, forCardWith: card.id)

        #expect(session.isRevealed, "the learner sees the answer — no silent advance any more")
        #expect(session.currentCard?.id == card.id, "and stays on the card until they decide")
        #expect(session.proposedStatus == .secure, "Gut → Sicher")
        #expect(card.status == .good, "**an offer is not a result**")
        #expect(card.reviewCount == 0, "and nothing is counted before the attempt is closed")
        #expect(card.reviews.count == 1, "only the seeded entry so far")

        // Closing it is what writes, and „Weiter" writes an entry with no offer
        // outcome even though an offer was on screen — the learner simply moved
        // on without answering it.
        session.moveOn(in: context)
        #expect(card.reviewCount == 1)
        #expect(card.status == .good, "still untouched")
        let log = try #require(card.reviews.first { $0.reviewedAt == Self.reviewDate })
        #expect(log.assessment == nil)
        #expect(log.usedSpeech)
        #expect(log.speechMatched == true)
        #expect(log.wasManualReveal == false)
        #expect(log.wasRetry == false)
        #expect(log.previousStatus == .good, "the status going into the attempt")
        #expect(log.direction == .germanToChinese)
    }

    @Test("A brand-new card can be classified for the first time")
    func newCardCanBeClassified() throws {
        // The phase-13 requirement: `.new` must be able to receive a first
        // classification once the evidence is there. Phase 11 refused it
        // outright, which is what the same-status rule replaces.
        insert("Apfel", status: .new)
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)
        seedCleanHistory(card, count: 1)
        try context.save()

        session.applyRecognition(card.hanzi, forCardWith: card.id)

        #expect(session.proposedStatus == .medium, "Neu → Mittel, the Gut column of §6")
        #expect(card.status == .new, "until the learner agrees")

        session.acceptProposal(in: context)
        #expect(card.status == .medium)
    }

    @Test("A card reset to Neu by hand does not reuse its old evidence")
    func manualResetDiscardsOldEvidence() throws {
        // The hole the phase-11 review found, closed at the right place: the
        // history is real, but all of it was recorded at another status, so none
        // of it is comparable. The reset is a statement.
        let card = insert("Apfel", status: .good)
        seedCleanHistory(card, count: 5)
        try context.save()

        // The learner resets it by hand in the card list.
        card.status = .new
        try context.save()

        let session = model()
        session.start(in: context)
        #expect(session.currentCard?.id == card.id)
        session.applyRecognition(card.hanzi, forCardWith: card.id)

        #expect(session.proposedStatus == nil, "its old evidence belongs to another status")
        #expect(card.status == .new)
    }

    @Test("A mismatch offers nothing and never lowers anything")
    func mismatchOffersNothingAndDoesNotDowngrade() throws {
        insert("Apfel", status: .medium)
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)
        seedCleanHistory(card, count: 1)
        try context.save()

        // Counter-probe in the same test: the identical situation with a match
        // does produce an offer. So what carries below is really the mismatch.
        #expect(AssistedAssessment.decision(
            currentStatus: .medium,
            current: ReviewSignal(direction: .germanToChinese, previousStatus: .medium,
                                  usedSpeech: true, speechMatched: true),
            history: card.reviews.map(\.signal)
        ) == .propose(.good))

        session.applyRecognition("香蕉", forCardWith: card.id)

        #expect(session.speechCheck?.isMatch == false)
        #expect(session.isRevealed, "the learner sees what happened")
        #expect(session.proposedStatus == nil, "and gets no nudge in either direction")
        #expect(card.status == .medium, "a mismatch is not evidence against the card")

        session.moveOn(in: context)
        #expect(card.status == .medium, "still nothing, after closing too")
    }

    // MARK: - The decline (§13.7, rule 4)

    @Test("A declined offer comes back only after the full threshold again")
    func declineResetsTheEvidence() throws {
        let card = insert("Apfel", status: .medium)
        seedCleanHistory(card, count: 1)
        try context.save()

        // **An advancing clock, and that is not incidental.** The rule reads the
        // history newest first; with a frozen clock every entry written here would
        // share one timestamp and the order would be undefined, so the test could
        // pass or fail on how SwiftData happens to return an unordered
        // relationship.
        let clock = AdvancingClock(from: Self.reviewDate)
        let session = LearnSessionModel(
            configuration: SessionConfiguration(cardType: .word),
            generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
            now: clock.next
        )
        session.start(in: context)

        // The offer, and the „no".
        session.applyRecognition(card.hanzi, forCardWith: card.id)
        #expect(session.proposedStatus == .good)
        session.declineProposal(in: context)
        #expect(card.status == .medium)

        // One clean attempt afterwards is not enough.
        session.applyRecognition(card.hanzi, forCardWith: card.id)
        #expect(session.proposedStatus == nil, "the decline reset the evidence to zero")
        session.moveOn(in: context)

        // The second one brings it back.
        session.applyRecognition(card.hanzi, forCardWith: card.id)
        #expect(session.proposedStatus == .good, "two fresh clean attempts earn it again")
    }

    @Test("A decline outlives the session and the app")
    func declineSurvivesARestart() throws {
        let store = TemporaryStore()
        defer { store.remove() }
        let cardID = UUID()

        do {
            let container = try store.openContainer()
            let context = container.mainContext
            let card = Card(id: cardID, type: .word, german: "Apfel", hanzi: "苹果", status: .medium)
            context.insert(card)
            context.insert(ReviewLog(
                reviewedAt: Self.reviewDate.addingTimeInterval(-60),
                direction: .germanToChinese, previousStatus: .medium,
                usedSpeech: true, speechMatched: true, card: card
            ))
            try context.save()

            let session = LearnSessionModel(
                configuration: SessionConfiguration(cardType: .word),
                generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
                now: { Self.reviewDate }
            )
            session.start(in: context)
            session.applyRecognition("苹果", forCardWith: cardID)
            #expect(session.proposedStatus == .good)
            session.declineProposal(in: context)
        }

        // A new app run, a new session, the same store.
        let container = try store.openContainer()
        let context = container.mainContext
        let session = LearnSessionModel(
            configuration: SessionConfiguration(cardType: .word),
            generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
            now: { Self.reviewDate.addingTimeInterval(3600) }
        )
        session.start(in: context)
        session.applyRecognition("苹果", forCardWith: cardID)

        #expect(
            session.proposedStatus == nil,
            "a decline that only lived in memory would offer the same step again right away"
        )
    }

    // MARK: - Without the microphone

    @Test("Without the microphone nothing is offered and nothing moves")
    func withoutSpeechNothingIsOffered() throws {
        insert("Apfel", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)
        seedCleanHistory(card, count: 5)
        try context.save()
        session.reveal(recordingWasPossible: true)

        #expect(session.proposedStatus == nil, "no attempt was made, so nothing is offered")
        #expect(session.isRevealed)
        session.moveOn(in: context)
        #expect(card.status == .good, "mode A without speech evidence is status-neutral")
        #expect(card.reviewCount == 1, "but the attempt is still recorded")
    }

    @Test("Revealing by hand rules out the offer, even after a match")
    func manualRevealRulesOutTheOffer() throws {
        insert("Apfel", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)
        seedCleanHistory(card, count: 3)
        try context.save()
        session.reveal(recordingWasPossible: true)
        session.applyRecognition(card.hanzi, forCardWith: card.id)

        #expect(session.isRevealed, "still here")
        #expect(session.currentCard?.id == card.id)
        #expect(session.proposedStatus == nil, "reading the answer is not a recall")
    }

    // MARK: - The attempt state has to be reset between cards

    @Test("A manual reveal on one card does not poison the next")
    func revealStateIsResetBetweenCards() throws {
        // The mutation the audit named: drop `revealedByHand = false` from the
        // reset and the very first give-up of a session would poison every later
        // card — no offer again until the app restarts.
        insert("Apfel", hanzi: "苹果", status: .good)
        insert("Wasser", hanzi: "水", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        let first = try #require(session.currentCard)
        session.reveal(recordingWasPossible: true)
        session.moveOn(in: context)

        let second = try #require(session.currentCard)
        #expect(second.id != first.id)
        seedCleanHistory(second, count: 1)
        try context.save()

        session.applyRecognition(second.hanzi, forCardWith: second.id)

        #expect(session.proposedStatus == .secure, "the second card is offered its step")
        session.moveOn(in: context)
        let log = try #require(second.reviews.first { $0.reviewedAt == Self.reviewDate })
        #expect(log.wasManualReveal == false, "the previous card's reveal is not this card's")
    }

    @Test("The give-up marker is taken per attempt, not accumulated")
    func giveUpMarkerIsPerAttempt() throws {
        // What this guards is a **sticky** flag: someone writing
        // `recordingWasPossible = recordingWasPossible || value`, or forgetting to
        // reset it, would let one give-up on a card that could record make every
        // later give-up reinsert — including on a device where recording is
        // impossible, which is the case the third condition of §13.5 exists for.
        //
        // The first version of this test tried to prove the leak through the
        // queue and could not fail: a leaked `recordingWasPossible` still needs
        // `wasManualReveal`, which is reset separately and already pinned above.
        // A test that cannot fail is worse than no test.
        insert("Apfel", hanzi: "苹果", status: .good)
        insert("Wasser", hanzi: "水", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)

        // First card: given up on **with** recording possible, so it comes back.
        let first = try #require(session.currentCard)
        session.reveal(recordingWasPossible: true)
        session.moveOn(in: context)

        // Second card: given up on **without**, so it must not come back — even
        // though the previous attempt said the opposite.
        let second = try #require(session.currentCard)
        #expect(second.id != first.id)
        session.reveal(recordingWasPossible: false)
        session.moveOn(in: context)

        #expect(session.currentCard?.id == first.id, "the repetition of the first card")
        #expect(session.currentCard?.id != second.id, "the second one was not put back")

        // And the other way round: the „false" of the second attempt must not
        // stick either. The first card's repetition is a retry, so it earns no
        // offer — what is checked here is purely that it is still scheduled.
        session.reveal(recordingWasPossible: false)
        session.moveOn(in: context)
        #expect(reviews(of: first).count == 2, "both attempts at the first card are recorded")
        #expect(reviews(of: second).count == 1, "and only one at the second")
    }

    @Test("Speech on one card does not colour the next card's entry")
    func speechStateIsResetBetweenCards() throws {
        // Without the reset the next card's entry would claim a microphone
        // attempt that never happened, with `speechMatched` nil — a record of
        // something that did not occur.
        insert("Apfel", hanzi: "苹果", status: .good)
        insert("Wasser", hanzi: "水", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        let first = try #require(session.currentCard)
        session.applyRecognition(first.hanzi, forCardWith: first.id)
        session.moveOn(in: context)

        let second = try #require(session.currentCard)
        session.reveal(recordingWasPossible: true)
        session.moveOn(in: context)

        let log = try #require(newestReview(of: second))
        #expect(log.usedSpeech == false, "this card was never spoken")
        #expect(log.speechMatched == nil)
    }

    @Test("A retry with a matching attempt is still a retry, and offers nothing")
    func retryWithSpeechOffersNothing() throws {
        // Retry **and** speech in one attempt — the combination, end to end.
        //
        // **What this cannot show**, and the audit was right to say so: that the
        // rule sees `wasRetry` through `attemptSignal` rather than only through the
        // stored history. The give-up that creates the repetition writes the newest
        // comparable entry, and that one is not clean, so the run breaks in the
        // history whatever `current.wasRetry` says. Every *reachable* retry follows
        // a give-up in the same batch, so the field is defence in depth rather than
        // a falsifiable behaviour here. The rule-level half is pinned without a
        // store in `AssistedAssessmentTests.retryCarriesNothing` and
        // `StatusTransitionTests.onlyOneStatusChangePerBatch`.
        insert("Apfel", hanzi: "苹果", status: .good)
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)
        seedCleanHistory(card, count: 2)
        try context.save()

        session.reveal(recordingWasPossible: true)
        session.moveOn(in: context)
        #expect(session.currentCard?.id == card.id, "the give-up keeps the card in the batch")

        session.applyRecognition(card.hanzi, forCardWith: card.id)

        #expect(session.currentCard?.id == card.id)
        #expect(session.isRevealed)
        #expect(session.proposedStatus == nil, "a second attempt is not a first one")
    }

    @Test("The newest reviews are the ones that count")
    func historyIsReadNewestFirst() throws {
        // Two entries that differ: an old clean one and a **newer** mismatch.
        // Read in the wrong order the run would look unbroken and the card would
        // be offered a step; read correctly the newer slip ends it.
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
            usedSpeech: true, speechMatched: false, card: card
        ))
        try context.save()

        session.applyRecognition(card.hanzi, forCardWith: card.id)

        #expect(session.proposedStatus == nil, "the newer slip breaks the run")
        #expect(session.isRevealed)
    }

    @Test("Closing the last card of a batch starts the next one")
    func closingTheLastCardOfABatchStartsTheNextOne() throws {
        // Closing empties the queue; the session has to notice and draw a new
        // batch rather than stall on an empty one.
        for index in 0..<12 { insert("Wort \(index)", hanzi: "苹果", status: .good) }
        try context.save()

        let session = model()
        session.start(in: context)

        let size = session.currentBatchSize
        #expect(size > 1)
        for _ in 0..<(size - 1) {
            session.reveal(recordingWasPossible: true)
            session.moveOn(in: context)
        }

        let last = try #require(session.currentCard)
        seedCleanHistory(last, count: 1)
        try context.save()

        session.applyRecognition(last.hanzi, forCardWith: last.id)
        #expect(session.proposedStatus == .secure)
        session.acceptProposal(in: context)

        #expect(session.currentCard != nil, "a new batch follows without a pause")
        #expect(session.answeredCount == size)
        #expect(session.currentBatchSize == size)
        #expect(last.status == .secure, "and the accepted step was written")
    }
}
