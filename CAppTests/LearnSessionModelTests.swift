//
//  LearnSessionModelTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

/// Phase 6: the engine wired to SwiftData. Everything here runs against a
/// real in-memory `ModelContainer`, because the point of these tests is the
/// integration — the engine's own rules are covered in `Learning/`'s tests
/// and are deliberately not re-tested through the model.
@MainActor
struct LearnSessionModelTests {

    // MARK: - Fixtures

    /// A fixed clock, so `lastReviewedAt` can be checked exactly.
    private static let reviewDate = Date(timeIntervalSince1970: 1_700_000_000)

    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        // Held as a property: a container that goes out of scope takes its
        // objects with it, and touching them afterwards crashes the whole
        // test process — measured in phase 2, see architecture.md §8.
        container = try makeInMemoryContainer()
        context = container.mainContext
    }

    @discardableResult
    private func insert(
        _ german: String,
        hanzi: String = "苹果",
        pinyin: String = "píngguǒ",
        type: CardType = .word,
        status: LearningStatus = .weak,
        tags: [Tag] = []
    ) -> Card {
        let card = Card(type: type, german: german, hanzi: hanzi, pinyin: pinyin, status: status, tags: tags)
        context.insert(card)
        return card
    }

    /// A session with a seeded generator and the fixed clock.
    private func model(
        type: CardType = .word,
        tagKeys: Set<String> = [],
        seed: UInt64 = 1
    ) -> LearnSessionModel {
        LearnSessionModel(
            configuration: SessionConfiguration(cardType: type, tagKeys: tagKeys),
            generator: AnyRandomNumberGenerator(SeededGenerator(seed: seed)),
            now: { Self.reviewDate }
        )
    }

    // MARK: - Pool

    @Test("A word session draws only words")
    func wordPoolHasOnlyWords() throws {
        insert("Apfel", type: .word)
        insert("Wasser", hanzi: "水", pinyin: "shuǐ", type: .word)
        insert("Ich möchte etwas essen.", hanzi: "我想吃点东西", pinyin: "wǒ xiǎng chī diǎn dōngxi", type: .sentence)
        try context.save()

        let session = model(type: .word)
        session.start(in: context)

        #expect(session.pool.count == 2)
        let germans = try poolGermans(of: session)
        #expect(germans.sorted() == ["Apfel", "Wasser"])
    }

    @Test("A sentence session draws only sentences")
    func sentencePoolHasOnlySentences() throws {
        insert("Apfel", type: .word)
        insert("Guten Morgen.", hanzi: "早上好", pinyin: "zǎoshang hǎo", type: .sentence)
        insert("Ich möchte etwas essen.", hanzi: "我想吃点东西", type: .sentence)
        try context.save()

        let session = model(type: .sentence)
        session.start(in: context)

        #expect(session.pool.count == 2)
        #expect(try poolGermans(of: session).contains("Apfel") == false, "types are never mixed")
    }

    @Test("Several categories widen the session — OR, not AND")
    func tagFilterUnionsTheSelectedCategories() throws {
        // Corrected after the phase-6 device test. Picking two topics meant
        // "only the cards carrying both", which emptied the session instead
        // of widening it. The card list keeps its AND, where every filter
        // narrows — the two screens ask different questions (A26 vs A12).
        let food = Tag(name: "Essen")
        let travel = Tag(name: "Reisen")
        context.insert(food)
        context.insert(travel)
        insert("Apfel", tags: [food])
        insert("Wasser", hanzi: "水", pinyin: "shuǐ", tags: [travel])
        insert("Bahnhof", hanzi: "火车站", pinyin: "huǒchēzhàn", tags: [food, travel])
        insert("Tee", hanzi: "茶", pinyin: "chá")
        try context.save()

        // 1. Nothing selected: every card of the type.
        let all = model()
        all.start(in: context)
        #expect(try poolGermans(of: all).sorted() == ["Apfel", "Bahnhof", "Tee", "Wasser"])

        // 2. One category: its cards, including the one that has more.
        let single = model(tagKeys: [TagNormalization.key(for: "Essen")])
        single.start(in: context)
        #expect(try poolGermans(of: single).sorted() == ["Apfel", "Bahnhof"])

        // 3. Two categories: the union of both.
        let both = model(tagKeys: [
            TagNormalization.key(for: "Essen"),
            TagNormalization.key(for: "Reisen"),
        ])
        both.start(in: context)
        #expect(try poolGermans(of: both).sorted() == ["Apfel", "Bahnhof", "Wasser"])

        // 4. The card in both categories appears once, not twice.
        #expect(both.pool.count == 3)
        #expect(Set(both.pool.map(\.id)).count == both.pool.count)

        // 5. A card in neither is out.
        #expect(try poolGermans(of: both).contains("Tee") == false)
    }

    @Test("The union filter still never mixes words and sentences")
    func tagUnionKeepsTypesApart() throws {
        // 6. The type is not one of the things OR applies to.
        let food = Tag(name: "Essen")
        context.insert(food)
        insert("Apfel", tags: [food])
        insert("Ich möchte etwas essen.", hanzi: "我想吃点东西", type: .sentence, tags: [food])
        try context.save()

        let words = model(type: .word, tagKeys: [TagNormalization.key(for: "Essen")])
        words.start(in: context)
        #expect(try poolGermans(of: words) == ["Apfel"])

        let sentences = model(type: .sentence, tagKeys: [TagNormalization.key(for: "Essen")])
        sentences.start(in: context)
        #expect(try poolGermans(of: sentences) == ["Ich möchte etwas essen."])
    }

    @Test("Two categories over both types: the type still decides")
    func tagUnionAcrossTypesStaysSeparated() throws {
        // The sharp version of case 6, from the audit: with only one category
        // selected, ODER and UND cannot come apart, so the type guard was
        // formally covered but never actually measured against the union.
        let food = Tag(name: "Essen")
        let travel = Tag(name: "Reisen")
        context.insert(food)
        context.insert(travel)
        insert("Apfel", tags: [food])
        insert("Wasser", hanzi: "水", pinyin: "shuǐ", tags: [travel])
        insert("Ich möchte etwas essen.", hanzi: "我想吃点东西", type: .sentence, tags: [food])
        insert("Wo ist der Bahnhof?", hanzi: "火车站在哪里", type: .sentence, tags: [travel])
        try context.save()

        let keys: Set<String> = [
            TagNormalization.key(for: "Essen"),
            TagNormalization.key(for: "Reisen"),
        ]

        let words = model(type: .word, tagKeys: keys)
        words.start(in: context)
        #expect(try poolGermans(of: words).sorted() == ["Apfel", "Wasser"])

        let sentences = model(type: .sentence, tagKeys: keys)
        sentences.start(in: context)
        #expect(try poolGermans(of: sentences).sorted() == ["Ich möchte etwas essen.", "Wo ist der Bahnhof?"])
    }

    @Test("A deleted category stops narrowing the session")
    func selectionDropsKeysWithoutACategory() throws {
        let food = Tag(name: "Essen")
        context.insert(food)
        try context.save()

        let essen = TagNormalization.key(for: "Essen")
        let reisen = TagNormalization.key(for: "Reisen")

        // "Reisen" was deleted in the management screen while it was still
        // selected here. It must not keep filtering invisibly.
        #expect(LearnSessionModel.activeTagKeys([essen, reisen], among: [food]) == [essen])

        // Nothing left means no restriction, not an empty session: what the
        // user can see is "no category selected", and that is what they get.
        #expect(LearnSessionModel.activeTagKeys([reisen], among: [food]).isEmpty)
        #expect(LearnSessionModel.activeTagKeys([], among: [food]).isEmpty)

        // Same normalisation as everywhere else on this path.
        #expect(LearnSessionModel.activeTagKeys([TagNormalization.key(for: " eSSEn ")], among: [food]) == [essen])
    }

    @Test("Spelling does not decide membership — both sides normalise")
    func tagFilterMatchesRegardlessOfSpelling() throws {
        // The other fixtures all use the exact spelling, so the shared
        // `TagNormalization.key` on both sides was never actually measured.
        let messy = Tag(name: "  eSSEn ")
        context.insert(messy)
        insert("Apfel", tags: [messy])
        try context.save()

        let session = model(tagKeys: [TagNormalization.key(for: "Essen")])
        session.start(in: context)
        #expect(try poolGermans(of: session) == ["Apfel"])
    }

    @Test("The category rule is a pure function, and the two rules differ")
    func categoryRulesDifferBetweenContexts() throws {
        // Pinned side by side, because the whole point is that the two
        // screens answer differently and a later reader will wonder whether
        // that is a bug.
        let food = Tag(name: "Essen")
        let travel = Tag(name: "Reisen")
        context.insert(food)
        context.insert(travel)
        let onlyFood = insert("Apfel", tags: [food])
        let both = insert("Bahnhof", hanzi: "火车站", pinyin: "huǒchēzhàn", tags: [food, travel])
        try context.save()

        let keys: Set<String> = [
            TagNormalization.key(for: "Essen"),
            TagNormalization.key(for: "Reisen"),
        ]

        // Learning: at least one category is enough.
        #expect(LearnSessionModel.matchesAnyCategory(onlyFood, tagKeys: keys))
        #expect(LearnSessionModel.matchesAnyCategory(both, tagKeys: keys))
        #expect(LearnSessionModel.matchesAnyCategory(onlyFood, tagKeys: []), "no selection, no restriction")

        // Card list: every category has to apply.
        #expect(CardFilter.matchesTags(onlyFood, tagKeys: keys) == false)
        #expect(CardFilter.matchesTags(both, tagKeys: keys))
    }

    @Test("A card without Chinese text is left out of the pool")
    func cardWithoutHanziIsExcluded() throws {
        insert("Apfel")
        let empty = Card(type: .word, german: "Ohne Hanzi", hanzi: "", pinyin: "")
        context.insert(empty)
        try context.save()

        let session = model()
        session.start(in: context)

        #expect(session.pool.count == 1)
        #expect(try poolGermans(of: session) == ["Apfel"])
    }

    @Test("An empty selection ends in the empty state, not an empty screen")
    func emptyPoolYieldsEmptyState() throws {
        insert("Ein Satz", hanzi: "早上好", type: .sentence)
        try context.save()

        // Words are asked for, only a sentence exists.
        let session = model(type: .word)
        session.start(in: context)

        #expect(session.state == .empty)
        #expect(session.currentCard == nil)
        #expect(session.pool.isEmpty)
    }

    @Test("The pool rule itself: type, categories, and something Chinese")
    func poolRuleIsPinnedDirectly() throws {
        // Tested on `poolCards` directly, not through a started session.
        // Found by the audit: the type filter exists in three places — the
        // fetch predicate, `CardFilter`, and the refresh between batches —
        // and the refresh re-applies it before any test can look at the pool.
        // So the *behaviour* was covered while the pool rule itself was not.
        // This is also the function the setup screen counts with.
        let food = Tag(name: "Essen")
        context.insert(food)
        let word = insert("Apfel", tags: [food])
        let untagged = insert("Tee", hanzi: "茶", pinyin: "chá")
        let sentence = insert("Guten Morgen.", hanzi: "早上好", type: .sentence, tags: [food])
        let withoutHanzi = insert("Ohne Hanzi", hanzi: "", pinyin: "", tags: [food])
        try context.save()

        let all = try context.fetch(FetchDescriptor<Card>())

        let words = LearnSessionModel.poolCards(
            from: all,
            configuration: SessionConfiguration(cardType: .word)
        )
        #expect(words.map(\.german).sorted() == ["Apfel", "Tee"])
        #expect(words.contains { $0.id == sentence.id } == false, "a sentence is never in a word pool")
        #expect(words.contains { $0.id == withoutHanzi.id } == false, "no Chinese, nothing to learn")

        let sentences = LearnSessionModel.poolCards(
            from: all,
            configuration: SessionConfiguration(cardType: .sentence)
        )
        #expect(sentences.map(\.german) == ["Guten Morgen."])
        #expect(sentences.contains { $0.id == word.id } == false, "and a word is never in a sentence pool")

        let tagged = LearnSessionModel.poolCards(
            from: all,
            configuration: SessionConfiguration(cardType: .word, tagKeys: [TagNormalization.key(for: "Essen")])
        )
        #expect(tagged.map(\.german) == ["Apfel"])
        #expect(tagged.contains { $0.id == untagged.id } == false, "the category filter applies")
    }

    // MARK: - Asking and revealing

    @Test("The first card is shown, and the answer only after revealing")
    func firstCardIsShownUnrevealed() throws {
        insert("Apfel")
        try context.save()

        let session = model()
        session.start(in: context)

        #expect(session.state == .asking)
        #expect(session.currentCard?.german == "Apfel")
        #expect(session.isRevealed == false)

        session.reveal()
        #expect(session.isRevealed)
    }

    @Test("Revealing writes nothing")
    func revealingPersistsNothing() throws {
        let card = insert("Apfel")
        try context.save()

        let session = model()
        session.start(in: context)
        session.reveal()

        #expect(card.reviewCount == 0)
        #expect(card.correctCount == 0)
        #expect(card.lastReviewedAt == nil)
        #expect(card.status == .weak)
        #expect(context.hasChanges == false)
    }

    @Test("Assessing without revealing does nothing")
    func assessmentRequiresReveal() throws {
        let card = insert("Apfel")
        try context.save()

        let session = model()
        session.start(in: context)
        session.submit(.good, in: context)

        #expect(card.reviewCount == 0, "the four answers only exist after revealing")
        #expect(session.answeredCount == 0)
    }

    // MARK: - Counters per answer (learning-engine.md §7)

    @Test("Nochmal counts as a review but not as correct")
    func againCountsReviewOnly() throws {
        let card = insert("Apfel", status: .medium)
        try context.save()

        let session = model()
        session.start(in: context)
        session.reveal()
        session.submit(.again, in: context)

        #expect(card.reviewCount == 1)
        #expect(card.correctCount == 0, "Nochmal means not known")
        #expect(card.lastReviewedAt == Self.reviewDate)
    }

    @Test("Schwer, Gut and Sicher all count as correct")
    func resolvingAnswersCountAsCorrect() throws {
        for assessment in [SelfAssessment.hard, .good, .secure] {
            let container = try makeInMemoryContainer()
            let context = container.mainContext
            let card = Card(type: .word, german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ", status: .medium)
            context.insert(card)
            try context.save()

            let session = LearnSessionModel(
                configuration: SessionConfiguration(cardType: .word),
                generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
                now: { Self.reviewDate }
            )
            session.start(in: context)
            session.reveal()
            session.submit(assessment, in: context)

            #expect(card.reviewCount == 1, "\(assessment)")
            #expect(card.correctCount == 1, "\(assessment) means known — Schwer with effort, but known")
            #expect(card.lastReviewedAt == Self.reviewDate)
        }
    }

    @Test("The status follows the transition matrix")
    func statusFollowsTheMatrix() throws {
        // Spot-checked against the matrix in §6; the full 20 cells are tested
        // in `StatusTransitionTests`. What matters here is that the model
        // writes what the engine returns instead of computing its own.
        let cases: [(LearningStatus, SelfAssessment, LearningStatus)] = [
            (.new, .good, .medium),
            (.weak, .again, .weak),
            (.medium, .secure, .secure),
            (.good, .again, .weak),
            (.secure, .again, .medium),
        ]

        for (before, assessment, expected) in cases {
            let container = try makeInMemoryContainer()
            let context = container.mainContext
            let card = Card(type: .word, german: "Apfel", hanzi: "苹果", status: before)
            context.insert(card)
            try context.save()

            let session = LearnSessionModel(
                configuration: SessionConfiguration(cardType: .word),
                generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
                now: { Self.reviewDate }
            )
            session.start(in: context)
            session.reveal()
            session.submit(assessment, in: context)

            #expect(card.status == expected, "\(before) + \(assessment)")
        }
    }

    // MARK: - The rule this phase could most easily break

    @Test("Nochmal and later Gut: counters both times, status only from the first")
    func laterGoodDoesNotLiftTheStatus() throws {
        // The product rule from §6.1. Without it, a card the learner did not
        // know at first would end the batch rated better than it started —
        // and the feature layer is exactly where that gets lost, by asking a
        // second time instead of using what the engine reported.
        let card = insert("Apfel", status: .weak)
        try context.save()

        let session = model()
        session.start(in: context)

        session.reveal()
        session.submit(.again, in: context)
        #expect(card.status == .weak, "first assessment decides")
        #expect(card.reviewCount == 1)
        #expect(card.correctCount == 0)

        // A pool of one card means the repetition is the same card again.
        #expect(session.currentCard?.id == card.id)
        session.reveal()
        session.submit(.good, in: context)

        #expect(card.reviewCount == 2, "every assessment is a review")
        #expect(card.correctCount == 1, "the later Gut does count as correct")
        #expect(card.lastReviewedAt == Self.reviewDate)
        #expect(card.status == .weak, "but it must not improve the status in the same batch")
    }

    @Test("A two-step improvement later in the batch is also ignored")
    func laterSecureDoesNotLiftTheStatusEither() throws {
        // A second case for §6.1, because the rule hung on one assertion.
        // Two rungs of visible difference: weak + secure would be `good`, so
        // if the later answer were allowed to count, the card would end the
        // batch two steps better than the first attempt showed.
        let card = insert("Apfel", status: .weak)
        try context.save()

        let session = model()
        session.start(in: context)
        session.reveal()
        session.submit(.again, in: context)
        #expect(card.status == .weak)

        session.reveal()
        session.submit(.secure, in: context)

        #expect(card.status == .weak, "still what the first attempt showed")
        #expect(card.reviewCount == 2, "but both are reviews")
        #expect(card.correctCount == 1)
    }

    // MARK: - Double tap

    @Test("Two taps on the same revealed card count once")
    func doubleTapCountsOnce() throws {
        let card = insert("Apfel", status: .medium)
        try context.save()

        let session = model()
        session.start(in: context)
        session.reveal()

        session.submit(.good, in: context)
        session.submit(.good, in: context)

        #expect(card.reviewCount == 1, "the second tap must not be a second answer")
        #expect(card.correctCount == 1)
        #expect(session.answeredCount == 1)
        #expect(session.isRevealed == false, "and the card comes up covered again")
    }

    @Test("A fast second tap does not skip a card")
    func doubleTapDoesNotSkipTheNextCard() throws {
        insert("Apfel")
        insert("Wasser", hanzi: "水", pinyin: "shuǐ")
        try context.save()

        let session = model()
        session.start(in: context)
        let first = try #require(session.currentCard?.id)

        session.reveal()
        session.submit(.good, in: context)
        session.submit(.good, in: context)

        let second = try #require(session.currentCard?.id)
        #expect(second != first, "we moved on")
        #expect(session.answeredCount == 1, "but only by one card")
        #expect(session.isRevealed == false)
    }

    // MARK: - Persistence

    @Test("Every answer is written immediately, not at the end of the session")
    func answersAreSavedImmediately() throws {
        insert("Apfel")
        insert("Wasser", hanzi: "水", pinyin: "shuǐ")
        try context.save()

        let session = model()
        session.start(in: context)
        session.reveal()
        session.submit(.good, in: context)

        // Nothing outstanding: the session could be abandoned right here
        // without losing the answer.
        #expect(context.hasChanges == false)
    }

    @Test("Counters and status survive reopening the store")
    func valuesSurviveReopening() throws {
        let store = TemporaryStore()
        defer { store.remove() }

        do {
            let container = try store.openContainer()
            let context = container.mainContext
            let card = Card(type: .word, german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ", status: .weak)
            context.insert(card)
            try context.save()

            let session = LearnSessionModel(
                configuration: SessionConfiguration(cardType: .word),
                generator: AnyRandomNumberGenerator(SeededGenerator(seed: 1)),
                now: { Self.reviewDate }
            )
            session.start(in: context)
            session.reveal()
            session.submit(.good, in: context)
        }

        let reopened = try store.openContainer()
        let card = try #require(try reopened.mainContext.fetch(FetchDescriptor<Card>()).first)
        #expect(card.reviewCount == 1)
        #expect(card.correctCount == 1)
        #expect(card.status == .medium, "weak + good")
        #expect(card.lastReviewedAt == Self.reviewDate)
    }

    // Deliberately not tested: the failing-save path.
    //
    // It is the reason `submit` advances a *copy* of the queue and keeps it
    // only after a successful write, so it would be worth a test. Two ways
    // to provoke it, both rejected:
    //
    // A read-only store — seed a `TemporaryStore`, close it, reopen the same
    // file with `allowsSave: false` — works when the test runs alone and
    // fails inside the parallel suite, measured twice and consistently. The
    // cause is **not** established: `TemporaryStore` builds a fresh UUID
    // path, so no other test can touch that file, and
    // `valuesSurviveReopening` opens two containers on one file sequentially
    // without trouble. Most likely the read-only container sees the writer's
    // coordinator still cached for that URL — but that is a guess, and a
    // test whose failure I cannot explain is not one to keep.
    //
    // The alternative would be an injectable save closure in
    // `LearnSessionModel`, i.e. a production seam that exists solely so a
    // test can throw. That trades a real abstraction for a test, which is
    // the wrong way round.
    //
    // What holds the behaviour instead: the order in `submit` is documented
    // where it happens, and the property it rests on — advancing a copy
    // leaves the original untouched — is now pinned in
    // `SessionQueueTests.advancingACopyDoesNotAffectTheOriginal`, which the
    // audit rightly pointed out was missing. The device checklist covers the
    // visible half (the alert appears, the same card stays).

    @Test("The next batch weighs the statuses the cards have now")
    func poolStatusesAreRefreshedBetweenBatches() throws {
        // The weighting reads the status (§3.1), and statuses change while
        // the session runs. Without refreshing, a card just rated Sicher
        // would keep being drawn with the weight of a weak one for the rest
        // of the session — the opposite of §1.
        let count = LearningParameters.batchSize - 4
        for index in 0..<count {
            insert("Karte \(index)", hanzi: "苹果", pinyin: "píngguǒ", status: .weak)
        }
        try context.save()

        let session = model()
        session.start(in: context)
        #expect(session.pool.allSatisfy { $0.status == .weak })

        // Resolve the whole batch with Sicher, which lifts every card.
        for _ in 0..<count {
            session.reveal()
            session.submit(.secure, in: context)
        }

        // A new batch has been selected by now, from the refreshed pool.
        #expect(session.pool.allSatisfy { $0.status == .good }, "weak + secure = good")
        #expect(session.pool.count == count, "membership is unchanged, only the statuses")
    }

    @Test("A card whose type changed mid-session leaves the pool")
    func typeChangeRemovesCardFromPool() throws {
        insert("Apfel")
        let switched = insert("Wasser", hanzi: "水", pinyin: "shuǐ")
        try context.save()

        let session = model()
        session.start(in: context)
        #expect(session.pool.count == 2)

        // The user edits the card in the other tab while the session runs.
        switched.type = .sentence
        try context.save()

        // Answer through the batch so the next one is selected.
        // Enough answers to get past the first batch of two cards.
        while session.currentCard != nil, session.answeredCount < 2 * 2 {
            session.reveal()
            session.submit(.good, in: context)
        }

        #expect(
            session.pool.contains { $0.id == switched.id } == false,
            "words and sentences must never mix, not even through an edit"
        )
    }

    // MARK: - Cards that vanish

    @Test("A deleted card is skipped instead of crashing the session")
    func deletedCurrentCardIsSkipped() throws {
        insert("Apfel")
        let doomed = insert("Wasser", hanzi: "水", pinyin: "shuǐ")
        try context.save()

        let session = model()
        session.start(in: context)

        // Delete whichever card is not on screen, then answer through to it.
        let shown = try #require(session.currentCard?.id)
        let toDelete = shown == doomed.id
            ? try #require(try context.fetch(FetchDescriptor<Card>()).first { $0.id != shown })
            : doomed
        context.delete(toDelete)
        try context.save()

        session.reveal()
        session.submit(.good, in: context)

        // The deleted card cannot be the one now on screen, and the session
        // is still running.
        #expect(session.currentCard?.id != toDelete.id)
        #expect(session.pool.contains { $0.id == toDelete.id } == false, "and it left the pool")
    }

    @Test("Deleting every card ends the session in the empty state")
    func deletingEverythingEndsInEmptyState() throws {
        insert("Apfel")
        try context.save()

        let session = model()
        session.start(in: context)
        let card = try #require(session.currentCard)

        context.delete(card)
        try context.save()

        // The next advance cannot resolve anything any more.
        session.reveal()
        session.submit(.good, in: context)

        #expect(session.state == .empty)
        #expect(session.currentCard == nil)
    }

    // MARK: - Batches

    @Test("After the batch is resolved the next one follows without a pause")
    func nextBatchFollowsSeamlessly() throws {
        // Two batches' worth of cards. The recency damping is active at this
        // size, but this test does not observe it — that is
        // `previousBatchIDsReachTheNextBatch`.
        for index in 0..<(LearningParameters.batchSize * 2) {
            insert("Karte \(index)", hanzi: "苹果", pinyin: "píngguǒ")
        }
        try context.save()

        let session = model()
        session.start(in: context)

        var seen: [UUID] = []
        for _ in 0..<LearningParameters.batchSize {
            let id = try #require(session.currentCard?.id)
            seen.append(id)
            session.reveal()
            session.submit(.good, in: context)
        }

        #expect(Set(seen).count == LearningParameters.batchSize, "no card twice inside a batch")
        // Straight on: still asking, a card on screen, no summary state.
        #expect(session.state == .asking)
        #expect(session.currentCard != nil)
        #expect(session.answeredCount == LearningParameters.batchSize)
    }

    @Test("The next batch prefers cards that were not just practised")
    func previousBatchIDsReachTheNextBatch() throws {
        // The model has to hand the finished batch's ids to the selector,
        // otherwise the recency damping from §3.2 never applies in the app —
        // the selector's own behaviour is covered in `BatchSelectorTests`,
        // but nothing showed that the wiring exists. Measured across several
        // seeds so the assertion does not rest on one lucky draw.
        let poolSize = LearningParameters.batchSize * 2
        var repeats = 0
        let seeds: [UInt64] = [1, 2, 3, 4]

        for seed in seeds {
            let container = try makeInMemoryContainer()
            let context = container.mainContext
            for index in 0..<poolSize {
                let card = Card(type: .word, german: "Karte \(index)", hanzi: "苹果", pinyin: "píngguǒ", status: .weak)
                context.insert(card)
            }
            try context.save()

            let session = LearnSessionModel(
                configuration: SessionConfiguration(cardType: .word),
                generator: AnyRandomNumberGenerator(SeededGenerator(seed: seed)),
                now: { Self.reviewDate }
            )
            session.start(in: context)

            var firstBatch: Set<UUID> = []
            for _ in 0..<LearningParameters.batchSize {
                firstBatch.insert(try #require(session.currentCard?.id))
                session.reveal()
                session.submit(.good, in: context)
            }

            // The second batch is running now. Count how many of its cards
            // came from the first one.
            var secondBatch: Set<UUID> = []
            for _ in 0..<LearningParameters.batchSize {
                secondBatch.insert(try #require(session.currentCard?.id))
                session.reveal()
                session.submit(.good, in: context)
            }
            repeats += secondBatch.intersection(firstBatch).count
        }

        // Without the damping every card would be equally likely, so about
        // half of each second batch would repeat — 14 across four seeds. The
        // damping is a factor of five, which pushes it far below that.
        let unbiased = seeds.count * LearningParameters.batchSize / 2
        #expect(repeats < unbiased, "\(repeats) repeats across \(seeds.count) batches, unbiased would be about \(unbiased)")
    }

    @Test("A pool smaller than a batch is asked completely, then again")
    func smallPoolWorks() throws {
        let count = LearningParameters.batchSize - 4
        for index in 0..<count {
            insert("Karte \(index)", hanzi: "苹果", pinyin: "píngguǒ")
        }
        try context.save()

        let session = model()
        session.start(in: context)

        var seen: [UUID] = []
        for _ in 0..<count {
            let id = try #require(session.currentCard?.id)
            seen.append(id)
            session.reveal()
            session.submit(.good, in: context)
        }

        #expect(Set(seen).count == count, "all of them, none twice")
        #expect(session.state == .asking, "and the session continues with a new batch")
        #expect(session.currentCard != nil)
    }

    @Test("A single card keeps the session going, batch after batch")
    func singleCardSessionKeepsRunning() throws {
        // Phase 5 guarantees a *batch* terminates. A session must not: with
        // one card the user should be able to keep practising until they
        // stop, which means a new batch with the same card.
        let card = insert("Apfel", status: .weak)
        try context.save()

        let session = model()
        session.start(in: context)

        // Well past `maxReinserts + 1`, which is where a single batch ends.
        let answers = (LearningParameters.maxReinserts + 1) * 3
        for _ in 0..<answers {
            #expect(session.currentCard?.id == card.id)
            session.reveal()
            session.submit(.again, in: context)
        }

        #expect(session.state == .asking, "the session does not end on its own")
        #expect(session.currentCard?.id == card.id)
        #expect(session.answeredCount == answers)
        #expect(card.reviewCount == answers, "every single one was a review")
        #expect(card.correctCount == 0)
    }

    @Test("A repeated card comes back only after every unseen card")
    func repeatedCardComesBackAfterTheUnseenOnes() throws {
        // Updated after the phase-6 device test. The old rule put a
        // repetition a fixed three places on, which let a few failed cards
        // cycle while others were never shown. Now it goes behind everything
        // that has not had its first attempt.
        let size = LearningParameters.batchSize
        for index in 0..<size {
            insert("Karte \(index)", hanzi: "苹果", pinyin: "píngguǒ")
        }
        try context.save()

        let session = model()
        session.start(in: context)
        let repeated = try #require(session.currentCard?.id)

        session.reveal()
        session.submit(.again, in: context)
        #expect(session.currentCard?.id != repeated, "never straight away")

        // Every other card of the batch comes first, each of them for the
        // first time.
        var seen: Set<UUID> = [repeated]
        var between = 0
        while let current = session.currentCard?.id, current != repeated, between <= size {
            #expect(seen.contains(current) == false, "an unseen card, not a repetition")
            seen.insert(current)
            between += 1
            session.reveal()
            session.submit(.good, in: context)
        }

        #expect(between == size - 1, "all the others first")
        #expect(session.currentCard?.id == repeated, "and then the repetition")
    }

    // MARK: - The reveal shows what is stored

    @Test("A hand-corrected Pinyin is what gets learned")
    func revealShowsTheStoredPinyin() throws {
        // The card is the stored source of truth. 东西 is the case that makes
        // this observable: the resolver cannot settle it without context and
        // returns "dōngxī", while the user corrected the card to "dōngxi".
        // If the reveal regenerated instead of reading the card, this test
        // would show it — with matching values it would be blind.
        let card = insert("Ding", hanzi: "东西", pinyin: "dōngxi")
        try context.save()

        #expect(PinyinService.pinyin(for: card.hanzi) == "dōngxī", "what generating would give")
        #expect(LearnAnswer.pinyin(for: card) == "dōngxi", "what the user corrected it to")
        #expect(LearnAnswer.hanzi(for: card) == "东西")
        #expect(LearnAnswer.accessibilityLabel(for: card) == "Antwort: 东西, dōngxi")
    }

    @Test("A card without Pinyin reveals just the Hanzi")
    func revealWithoutPinyin() throws {
        let card = insert("Apfel", pinyin: "")
        try context.save()

        #expect(LearnAnswer.pinyin(for: card).isEmpty)
        #expect(LearnAnswer.accessibilityLabel(for: card) == "Antwort: 苹果", "no dangling comma")
    }

    // MARK: - Helpers

    /// The German texts of a session's pool, resolved through the store —
    /// the pool itself holds only ids and statuses.
    private func poolGermans(of session: LearnSessionModel) throws -> [String] {
        let cards = try context.fetch(FetchDescriptor<Card>())
        return session.pool.compactMap { snapshot in
            cards.first { $0.id == snapshot.id }?.german
        }
    }
}
