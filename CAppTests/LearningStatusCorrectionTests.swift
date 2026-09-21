//
//  LearningStatusCorrectionTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

/// The hand-picked learning status and its evidence boundary
/// (`docs/learning-engine.md` §13.13).
///
/// Two things are being protected here, and the second is the one that is easy to
/// get wrong. First: a correction is **not** a learning answer — no review entry,
/// no counters, no reinsertion. Second: it has to move the line the assisted
/// classification reads from, or a card corrected back down would be offered the
/// same promotion again on its very next clean attempt.
@MainActor
struct LearningStatusCorrectionTests {

    private static let correctedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        container = try makeInMemoryContainer()
        context = container.mainContext
    }

    @discardableResult
    private func insert(status: LearningStatus) -> Card {
        let card = Card(type: .word, german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ", status: status)
        context.insert(card)
        return card
    }

    /// Clean mode-A reviews at `status`, all written **before** `correctedAt`.
    private func seedOldCleanHistory(_ card: Card, count: Int, at status: LearningStatus) {
        for step in 0..<count {
            context.insert(ReviewLog(
                reviewedAt: Self.correctedAt.addingTimeInterval(-600 + Double(step)),
                direction: .germanToChinese,
                previousStatus: status,
                usedSpeech: true,
                speechMatched: true,
                card: card
            ))
        }
    }

    // MARK: - Setting the status

    @Test("Secure back to medium: the status is written and persisted at once")
    func correctingDownwards() throws {
        let card = insert(status: .secure)
        try context.save()

        let changed = try LearningStatusCorrection.apply(
            .medium, to: card, in: context, now: { Self.correctedAt }
        )

        #expect(changed)
        #expect(card.status == .medium, "the only way a status ever goes down")
        #expect(card.classificationEvidenceResetAt == Self.correctedAt)
        #expect(context.hasChanges == false, "written immediately, no pending save")
    }

    @Test("All five statuses can be set")
    func everyStatusIsReachable() throws {
        // One card in this suite's own container, corrected in turn to each of the
        // five. **Not one container per status in a local `let`:** that is the
        // shape that took the whole test process down earlier in this phase, and
        // even where it happens to be safe it is not a shape to leave lying about.
        let card = insert(status: .new)
        try context.save()

        for target in LearningStatus.allCases {
            let before = card.status
            let changed = try LearningStatusCorrection.apply(
                target, to: card, in: context, now: { Self.correctedAt }
            )
            #expect(changed == (before != target), "\(before) → \(target)")
            #expect(card.status == target, "\(target) has to be reachable")
        }
        #expect(card.status == .secure, "the last one in the ladder")

        // The menu offers every status the model can hold — checked against the
        // enum rather than against `menuOrder`'s own definition, which would be a
        // tautology.
        #expect(LearningStatusCorrection.menuOrder.count == LearningStatus.allCases.count)
        #expect(Set(LearningStatusCorrection.menuOrder) == Set(LearningStatus.allCases))
        #expect(LearningStatusCorrection.menuOrder.first == .new, "bottom of the ladder first")
        #expect(LearningStatusCorrection.menuOrder.last == .secure)
    }

    @Test("The marked status is spoken, not only drawn")
    func theMarkingIsSpoken() {
        // A checkmark is not a word, and which entry carries it is the whole point
        // of marking it.
        #expect(
            LearningStatusCorrection.accessibilityLabel(for: .medium, isCurrent: true)
                == "Mittel, aktueller Lernstand"
        )
        #expect(LearningStatusCorrection.accessibilityLabel(for: .medium, isCurrent: false) == "Mittel")

        for status in LearningStatus.allCases {
            let current = LearningStatusCorrection.accessibilityLabel(for: status, isCurrent: true)
            let other = LearningStatusCorrection.accessibilityLabel(for: status, isCurrent: false)
            #expect(current != other, "\(status): the two have to be distinguishable")
            #expect(current.hasPrefix(status.title), "\(status): and both name the status")
            for word in SpeechRecognitionTests.forbiddenWordings {
                #expect(current.contains(word) == false, "\(current) says \(word)")
            }
        }
    }

    @Test("Setting a card back to Neu behaves like any other correction")
    func correctingToNew() throws {
        let card = insert(status: .good)
        seedOldCleanHistory(card, count: 5, at: .good)
        try context.save()

        try LearningStatusCorrection.apply(.new, to: card, in: context, now: { Self.correctedAt })

        #expect(card.status == .new)
        #expect(card.classificationEvidenceResetAt == Self.correctedAt)
        #expect(card.reviews.count == 5, "the history is not deleted, only bounded")
        #expect(
            card.reviews.allSatisfy { LearnSessionModel.countsAsEvidence($0, for: card) == false },
            "and none of it counts any more"
        )
    }

    @Test("Choosing the status the card already has is a no-op")
    func samePickIsANoOp() throws {
        let card = insert(status: .medium)
        seedOldCleanHistory(card, count: 2, at: .medium)
        try context.save()

        #expect(LearningStatusCorrection.changes(card, to: .medium) == false)

        let changed = try LearningStatusCorrection.apply(
            .medium, to: card, in: context, now: { Self.correctedAt }
        )

        #expect(changed == false)
        #expect(card.status == .medium)
        // The one that matters: a no-op must not move the boundary either.
        // Otherwise tapping the current status would silently throw the card's
        // eligible history away while appearing to do nothing at all.
        #expect(card.classificationEvidenceResetAt == nil, "no boundary from a no-op")
        #expect(
            card.reviews.allSatisfy { LearnSessionModel.countsAsEvidence($0, for: card) },
            "and the history stays eligible"
        )
    }

    // MARK: - A correction is not a learning answer

    @Test("A correction writes no review and moves no counter")
    func correctionIsNotAnAnswer() throws {
        let card = insert(status: .secure)
        card.reviewCount = 7
        card.correctCount = 5
        let reviewedAt = Self.correctedAt.addingTimeInterval(-3600)
        card.lastReviewedAt = reviewedAt
        seedOldCleanHistory(card, count: 3, at: .secure)
        try context.save()

        try LearningStatusCorrection.apply(.weak, to: card, in: context, now: { Self.correctedAt })

        #expect(card.reviewCount == 7, "no attempt happened")
        #expect(card.correctCount == 5)
        #expect(card.lastReviewedAt == reviewedAt, "and nothing was reviewed")
        #expect(try context.fetch(FetchDescriptor<ReviewLog>()).count == 3, "no new entry")
        #expect(card.reviews.count == 3, "the existing history is untouched")
    }

    @Test("The correction survives a restart")
    func correctionIsPersisted() throws {
        let store = TemporaryStore()
        defer { store.remove() }

        do {
            let container = try store.openContainer()
            let context = container.mainContext
            let card = Card(type: .word, german: "Apfel", hanzi: "苹果", status: .secure)
            context.insert(card)
            try context.save()
            try LearningStatusCorrection.apply(
                .medium, to: card, in: context, now: { Self.correctedAt }
            )
        }

        let reopened = try store.openContainer()
        let card = try #require(try reopened.mainContext.fetch(FetchDescriptor<Card>()).first)
        #expect(card.status == .medium)
        #expect(card.classificationEvidenceResetAt == Self.correctedAt, "the boundary too")
    }

    // MARK: - The evidence boundary

    @Test("Reviews from before the correction carry no evidence")
    func oldReviewsStopCounting() throws {
        // The case the boundary exists for: Mittel → Sicher by consent, then
        // corrected back to Mittel by hand. The old Mittel-era reviews are
        // comparable again by the same-status rule, so without the boundary the
        // next clean attempt would offer Mittel → Gut straight away — exactly the
        // promotion the learner just took away.
        let card = insert(status: .medium)
        seedOldCleanHistory(card, count: 4, at: .medium)
        try context.save()

        // Counter-probe first: without a correction this history *does* carry a
        // suggestion. Otherwise the assertion below could pass for the wrong
        // reason.
        let eligibleBefore = card.reviews
            .filter { LearnSessionModel.countsAsEvidence($0, for: card) }
            .map(\.signal)
        #expect(eligibleBefore.count == 4)
        #expect(
            AssistedAssessment.decision(
                currentStatus: .medium,
                current: ReviewSignal(direction: .germanToChinese, previousStatus: .medium,
                                      usedSpeech: true, speechMatched: true),
                history: eligibleBefore
            ) == .propose(.good),
            "the seeded history really is enough for an offer"
        )

        card.status = .secure
        try context.save()
        try LearningStatusCorrection.apply(.medium, to: card, in: context, now: { Self.correctedAt })

        let eligibleAfter = card.reviews
            .filter { LearnSessionModel.countsAsEvidence($0, for: card) }
            .map(\.signal)
        #expect(eligibleAfter.isEmpty, "everything is on the far side of the line")
        #expect(card.reviews.count == 4, "and none of it was deleted")
        #expect(
            AssistedAssessment.decision(
                currentStatus: .medium,
                current: ReviewSignal(direction: .germanToChinese, previousStatus: .medium,
                                      usedSpeech: true, speechMatched: true),
                history: eligibleAfter
            ) == .continueOnly,
            "so the same attempt now earns nothing"
        )
    }

    @Test("A review written at the very moment of the correction does not count")
    func theBoundaryIsStrict() throws {
        let card = insert(status: .medium)
        context.insert(ReviewLog(
            reviewedAt: Self.correctedAt,
            direction: .germanToChinese, previousStatus: .medium,
            usedSpeech: true, speechMatched: true, card: card
        ))
        try context.save()
        try LearningStatusCorrection.apply(.weak, to: card, in: context, now: { Self.correctedAt })

        let review = try #require(card.reviews.first)
        #expect(
            LearnSessionModel.countsAsEvidence(review, for: card) == false,
            "at an equal timestamp the correction is the later statement"
        )
    }

    @Test("Reviews after the correction count normally, and two of them earn the offer again")
    func newReviewsCountAgain() throws {
        let card = insert(status: .medium)
        seedOldCleanHistory(card, count: 4, at: .medium)
        try context.save()
        // **Two corrections, and the detour is the point.** The card has to end up
        // back on *Mittel* — where its old entries are comparable again — but a
        // correction to the status it already has would be a no-op and set no
        // boundary. So it goes away and back, exactly as a learner disagreeing
        // with a promotion would.
        try LearningStatusCorrection.apply(.weak, to: card, in: context, now: { Self.correctedAt })
        try LearningStatusCorrection.apply(
            .medium, to: card, in: context, now: { Self.correctedAt.addingTimeInterval(1) }
        )
        let boundary = try #require(card.classificationEvidenceResetAt)

        func decisionNow() -> AssistedClassificationDecision {
            AssistedAssessment.decision(
                currentStatus: card.status,
                current: ReviewSignal(direction: .germanToChinese, previousStatus: card.status,
                                      usedSpeech: true, speechMatched: true),
                history: card.reviews
                    .filter { LearnSessionModel.countsAsEvidence($0, for: card) }
                    .sorted { $0.reviewedAt > $1.reviewedAt }
                    .map(\.signal)
            )
        }

        // **Two clean attempts means two, and the running one is the second.**
        // `cleanRunBeforeSuggestion` has counted the current attempt since phase
        // 11, so „nach zwei neuen sauberen Versuchen" is one recorded entry plus
        // the attempt being decided. An earlier version of this test expected a
        // third and failed — worth writing down, because off by one here would
        // either offer too early or never.
        #expect(decisionNow() == .continueOnly, "the first attempt after the line is a run of one")

        // Attempt one after the correction, recorded.
        context.insert(ReviewLog(
            reviewedAt: boundary.addingTimeInterval(60),
            direction: .germanToChinese, previousStatus: .medium,
            usedSpeech: true, speechMatched: true, card: card
        ))
        try context.save()

        // Attempt two is the one `decisionNow()` passes as `current` — so the
        // evidence has rebuilt and the offer is back. It was bounded, not switched
        // off for good.
        #expect(decisionNow() == .propose(.good), "two fresh clean attempts, and it may offer again")

        // And the old entries still play no part: dropping the boundary would have
        // produced this same answer one attempt earlier.
        #expect(
            card.reviews.filter { LearnSessionModel.countsAsEvidence($0, for: card) }.count == 1,
            "exactly the one fresh entry is eligible, not the four old ones"
        )
    }

    @Test("Neu with Neu-era history: only the boundary stops the second offer")
    func correctingBackToNewWithNewEraHistory() throws {
        // **The case Kriterium 9 is actually about**, and the audit was right that
        // it was missing. `correctingToNew` sets a *Gut* card to *Neu*, where the
        // same-status rule already excludes everything — the boundary carries no
        // load there.
        //
        // Here the history was recorded **at `.new`**: the card earned
        // `Neu → Mittel`, the learner disagreed and set it back to `.new`. Now the
        // old entries carry `previousStatus == .new`, are comparable again, and
        // **only** the boundary prevents the very same offer on the next clean
        // attempt.
        let card = insert(status: .new)
        seedOldCleanHistory(card, count: 3, at: .new)
        try context.save()

        func offerNow() -> AssistedClassificationDecision {
            AssistedAssessment.decision(
                currentStatus: card.status,
                current: ReviewSignal(direction: .germanToChinese, previousStatus: card.status,
                                      usedSpeech: true, speechMatched: true),
                history: card.reviews
                    .filter { LearnSessionModel.countsAsEvidence($0, for: card) }
                    .sorted { $0.reviewedAt > $1.reviewedAt }
                    .map(\.signal)
            )
        }

        // Counter-probe: at `.new` with `.new`-era history the offer really is on
        // the table, so what changes it below is the correction and nothing else.
        #expect(offerNow() == .propose(.medium), "Neu → Mittel, earned at Neu")

        // The learner takes the promotion and then disagrees with it.
        try LearningStatusCorrection.apply(.medium, to: card, in: context, now: { Self.correctedAt })
        try LearningStatusCorrection.apply(
            .new, to: card, in: context, now: { Self.correctedAt.addingTimeInterval(1) }
        )
        #expect(card.status == .new)

        #expect(
            offerNow() == .continueOnly,
            "the same-status rule finds the old Neu entries comparable — only the boundary stops them"
        )
        #expect(card.reviews.count == 3, "and none of them was deleted")
    }

    @Test("After a correction the session itself offers again once the evidence rebuilds")
    func theSessionOffersAgainAfterACorrection() throws {
        // **Through `LearnSessionModel`, not through a copy of its pipeline.** The
        // other boundary tests rebuild `recentSignals` locally, so a fault in the
        // real one — wrong sort direction, window before filter, a forgotten
        // current attempt — would leave them green. This one drives the session.
        let card = insert(status: .medium)
        seedOldCleanHistory(card, count: 4, at: .medium)
        try context.save()
        try LearningStatusCorrection.apply(.good, to: card, in: context, now: { Self.correctedAt })
        try LearningStatusCorrection.apply(
            .medium, to: card, in: context, now: { Self.correctedAt.addingTimeInterval(1) }
        )
        let boundary = try #require(card.classificationEvidenceResetAt)

        // One clean attempt after the line, recorded through the session itself.
        let session = LearnSessionModel(
            configuration: SessionConfiguration(cardType: .word),
            generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
            now: { boundary.addingTimeInterval(60) }
        )
        session.start(in: context)
        #expect(session.currentCard?.id == card.id)
        session.applyRecognition("苹果", forCardWith: card.id)
        #expect(session.proposedStatus == nil, "the old evidence is behind the line")
        session.moveOn(in: context)

        // The second attempt: the run is two, and the session offers again.
        let next = LearnSessionModel(
            configuration: SessionConfiguration(cardType: .word),
            generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
            now: { boundary.addingTimeInterval(120) }
        )
        next.start(in: context)
        next.applyRecognition("苹果", forCardWith: card.id)

        #expect(next.proposedStatus == .good, "the evidence rebuilt, through the real pipeline")
        next.acceptProposal(in: context)
        #expect(card.status == .good)
    }

    @Test("A correction made while a card is revealed withdraws the standing offer")
    func aCorrectionExpiresAStandingOffer() throws {
        // Found in review, and reachable: the session is a push **inside** the
        // Lernen tab, so the learner can leave a revealed card standing, switch to
        // the card list, correct that same card, and come back. Confirming then
        // would undo the correction — the one direction the app has no other way
        // of going — and the bar would read two rungs („Schwach → Gut").
        let card = insert(status: .medium)
        seedOldCleanHistory(card, count: 1, at: .medium)
        try context.save()

        let session = LearnSessionModel(
            configuration: SessionConfiguration(cardType: .word),
            generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
            now: { Self.correctedAt.addingTimeInterval(-60) }
        )
        session.start(in: context)
        session.applyRecognition("苹果", forCardWith: card.id)
        #expect(session.proposedStatus == .good, "an offer is standing")

        // The learner corrects the same card in the card list.
        try LearningStatusCorrection.apply(.weak, to: card, in: context, now: { Self.correctedAt })

        #expect(
            session.proposedStatus == nil,
            "the offer was worked out from Mittel and the card no longer stands there"
        )

        // Both closing actions refuse it, so neither can undo the correction nor
        // record a suggestion against a status it was never computed from.
        session.acceptProposal(in: context)
        #expect(card.status == .weak, "Bestätigen must not push it back up")
        session.declineProposal(in: context)
        #expect(card.reviews.allSatisfy { $0.suggestionDecision == nil }, "and nothing was recorded")

        // „Weiter" still works — the attempt is closable, just not on those terms.
        session.moveOn(in: context)
        #expect(card.status == .weak)
        let newest = try #require(card.reviews.sorted { $0.reviewedAt > $1.reviewedAt }.first)
        #expect(newest.suggestedStatus == nil)
        #expect(newest.suggestionDecision == nil)
    }

    @Test("A card that was never corrected has all of its history")
    func withoutACorrectionEverythingCounts() throws {
        let card = insert(status: .medium)
        seedOldCleanHistory(card, count: 3, at: .medium)
        try context.save()

        #expect(card.classificationEvidenceResetAt == nil)
        #expect(card.reviews.allSatisfy { LearnSessionModel.countsAsEvidence($0, for: card) })
    }

    // MARK: - End to end through a session

    @Test("A corrected card gets no offer in a running session")
    func correctedCardOffersNothingInASession() throws {
        let card = insert(status: .medium)
        seedOldCleanHistory(card, count: 4, at: .medium)
        try context.save()
        // Away and back, so the card ends on *Mittel* with a boundary behind it.
        try LearningStatusCorrection.apply(.good, to: card, in: context, now: { Self.correctedAt })
        try LearningStatusCorrection.apply(
            .medium, to: card, in: context, now: { Self.correctedAt.addingTimeInterval(1) }
        )

        let session = LearnSessionModel(
            configuration: SessionConfiguration(cardType: .word),
            generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
            now: { Self.correctedAt.addingTimeInterval(600) }
        )
        session.start(in: context)
        #expect(session.currentCard?.id == card.id)

        session.applyRecognition("苹果", forCardWith: card.id)

        #expect(session.proposedStatus == nil, "the old evidence is on the far side of the line")
        session.moveOn(in: context)
        #expect(card.status == .medium, "and nothing moved")
    }
}
