//
//  LargeCollectionTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

/// Task 10.8 — does the app still feel instant with a realistic collection?
///
/// ## What this measures and what it cannot
///
/// It measures the **pure logic**: filtering, sorting, grouping, pool
/// building, batch selection — the part that runs on every keystroke in the
/// search field.
///
/// **What the bounds can and cannot catch.** Measured on the simulator on
/// 2026-09-12: four searches 9.9 ms, five sort orders plus grouping 22.5 ms,
/// three pool builds plus batch selection 6.4 ms. The bounds sit at roughly
/// eight times that, which catches an order-of-magnitude regression without
/// going red because the machine was busy. They would **not** catch a
/// quadratic loop at n = 500 — 250 000 comparisons on in-memory arrays stay
/// far below any bound that is not flaky — so nobody should read a green run
/// here as proof that the complexity is right. The first bound was 500 ms for
/// all three, which was 20 to 80 times the real value and said nothing at
/// all; the audit is what put the numbers on it.
///
/// **Under which conditions those three numbers were taken:** a single
/// isolated run (`-only-testing:CAppTests/LargeCollectionTests`) on the
/// iPhone-17 simulator. The regular suite runs **in parallel**, so the
/// assertions execute while other suites compete for the same cores — the
/// eightfold headroom absorbs that, but it is headroom against a condition
/// the baseline was not measured in. Nobody should tighten these bounds
/// without re-measuring the way the suite actually runs.
///
/// It does **not** measure SwiftUI rendering, scrolling or SwiftData's fetch
/// on a real store — those need the device, and they are on the physical
/// checklist. A test that claimed to cover them would be measuring the
/// simulator's mood.
///
/// The thresholds are deliberately loose. The point is not to pin a
/// microsecond count that breaks on a busy CI machine; it is to catch the
/// order-of-magnitude regression that turns typing into waiting. Anything
/// that passes here can still feel slow on the device, which is why the
/// device test exists — and anything that fails here is broken for certain.
///
/// **No `#Index` was added.** The roadmap says to think about one only once
/// something actually drags. Nothing here drags.
@MainActor
struct LargeCollectionTests {

    /// Roughly what a few years of daily use looks like.
    static let cardCount = 500

    let container: ModelContainer
    let cards: [Card]
    let tags: [Tag]

    init() throws {
        container = try makeInMemoryContainer()
        let context = container.mainContext

        // Deterministic fixture: the same 500 cards every run, so a timing
        // difference is a code difference and not a different data set. Built
        // straight from the index — no generator, because a random one would
        // be the very thing that makes two runs incomparable.
        let names = ["Essen", "Reisen", "Alltag", "Arbeit", "Familie"]
        tags = names.map { Tag(name: $0) }
        for tag in tags { context.insert(tag) }

        let syllables = ["苹", "果", "水", "山", "book", "明", "天", "东", "西", "学"]
        var built: [Card] = []
        for index in 0..<Self.cardCount {
            let hanzi = (0..<(2 + index % 4)).map { syllables[($0 + index) % syllables.count] }.joined()
            let card = Card(
                type: index % 3 == 0 ? .sentence : .word,
                german: "Begriff \(index)",
                hanzi: hanzi,
                pinyin: "pinyin \(index)",
                status: LearningStatus.allCases[index % LearningStatus.allCases.count],
                createdAt: Date(timeIntervalSince1970: Double(index)),
                tags: index % 7 == 0 ? [] : [tags[index % tags.count]]
            )
            context.insert(card)
            built.append(card)
        }
        cards = built
        try context.save()
    }

    /// Wall-clock for one closure, in milliseconds.
    ///
    /// Divided by `.milliseconds(1)` rather than read out of `components`.
    /// The first version of this helper returned
    /// `components.attoseconds / 1e15`, and `attoseconds` is only the
    /// **sub-second** part: 1.4 s came back as 400 ms and passed a 500 ms
    /// bound. A timing test that cannot see a whole second is worse than no
    /// timing test, because it reports a pass. Found by the audit.
    private func milliseconds(_ work: () -> Void) -> Double {
        let start = ContinuousClock.now
        work()
        return start.duration(to: .now) / .milliseconds(1)
    }

    @Test("The fixture really is large")
    func fixtureSize() {
        #expect(cards.count == Self.cardCount)
        #expect(cards.contains { $0.type == .sentence })
        #expect(cards.contains { $0.tags.isEmpty })
    }

    @Test("Searching 500 cards stays instant")
    func searchIsFast() {
        // Runs on every keystroke, over German, Hanzi and Pinyin at once.
        var hits = 0
        let elapsed = milliseconds {
            for term in ["Begriff 1", "苹", "pinyin 4", "xyz"] {
                hits += CardFilter.apply(to: cards, type: .word, searchText: term).count
            }
        }
        #expect(hits > 0, "otherwise this measured an empty loop")
        #expect(elapsed < 80, "four searches over 500 cards took \(elapsed) ms, measured 9.9")
    }

    @Test("Filtering, sorting and grouping stay instant")
    func arrangingIsFast() {
        let keys = Set(tags.prefix(2).map { TagNormalization.key(for: $0.name) })
        var produced = 0
        let elapsed = milliseconds {
            for order in CardSortOrder.allCases {
                let visible = CardListArrangement.sort(
                    CardFilter.apply(to: cards, type: .word, tagKeys: keys, status: .weak),
                    by: order
                )
                produced += visible.count
                produced += CardListArrangement.sections(visible, selectedTagKeys: keys).count
            }
        }
        #expect(produced > 0)
        #expect(elapsed < 180, "five sort orders plus grouping took \(elapsed) ms, measured 22.5")
    }

    @Test("Grouping 500 cards still places each of them exactly once")
    func groupingStaysCorrectAtScale() {
        // Correctness, not speed — and the case where a duplicate would hide:
        // many cards, many categories, one of them untagged.
        let visible = CardFilter.apply(to: cards, type: .word)
        let sections = CardListArrangement.sections(visible, selectedTagKeys: [])
        let placed = sections.flatMap(\.cards).map(\.id)

        #expect(placed.count == visible.count)
        #expect(Set(placed) == Set(visible.map(\.id)))
        #expect(sections.last?.title == CardListArrangement.uncategorizedTitle)
    }

    @Test("Building a session pool and a batch stays instant")
    func sessionStartIsFast() {
        var batchSizes: [Int] = []
        let elapsed = milliseconds {
            for size in [5, 7, 10] {
                let pool = LearnSessionModel.poolCards(
                    from: cards,
                    configuration: SessionConfiguration(cardType: .word)
                )
                let snapshots = pool.map { CardSnapshot(id: $0.id, status: $0.status) }
                var generator = AnyRandomNumberGenerator(SeededGenerator(seed: 3))
                let batch = BatchSelector.selectBatch(
                    from: snapshots, batchSize: size, using: &generator
                )
                batchSizes.append(batch.count)
            }
        }
        #expect(batchSizes == [5, 7, 10], "each size drew what it promised")
        #expect(elapsed < 60, "three pool builds plus batch selection took \(elapsed) ms, measured 6.4")
    }

    @Test("The status counts over 500 cards add up")
    func statusCountsAtScale() {
        let total = LearningStatus.allCases.reduce(0) {
            $0 + SettingsView.count(of: $1, in: cards)
        }
        #expect(total == cards.count)
    }
}
