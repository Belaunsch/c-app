//
//  CardFilter.swift
//  CApp
//

import Foundation

/// Narrows the card list down to what the user asked for.
///
/// This runs in plain Swift on an already fetched array instead of building a
/// dynamic `#Predicate`. Two reasons:
///
/// 1. Robustness. Predicates over the computed `type` / `status` properties
///    crash at fetch time with a `fatalError` rather than throwing, because
///    only `typeRaw` / `statusRaw` exist in the store. Combining four
///    independent, optional criteria into one predicate is exactly where such
///    a mistake slips in. See `docs/architecture.md` §3.
/// 2. Proportion. This is a private app with a few hundred cards at most, so
///    in-memory filtering is not a bottleneck. It is also directly testable
///    without a running view.
enum CardFilter {

    /// Applies every active criterion. All of them narrow the result.
    ///
    /// - Parameters:
    ///   - cards: the already sorted cards to narrow down.
    ///   - type: word or sentence — the two are never shown mixed.
    ///   - searchText: matched against German, Hanzi and Pinyin. Empty means
    ///     no search.
    ///   - tagKeys: normalized tag keys, see `TagNormalization`. A card must
    ///     carry **at least one** of them (OR, A32). Empty means no tag
    ///     filter.
    ///   - status: exact learning status, `nil` means every status.
    static func apply(
        to cards: [Card],
        type: CardType,
        searchText: String = "",
        tagKeys: Set<String> = [],
        status: LearningStatus? = nil
    ) -> [Card] {
        cards.filter { card in
            card.type == type
                && matchesSearch(card, searchText: searchText)
                && matchesTags(card, tagKeys: tagKeys)
                && matchesStatus(card, status: status)
        }
    }

    /// Matches German, Hanzi or Pinyin.
    ///
    /// Uses `localizedStandardContains`, which ignores case and diacritics.
    /// That is what makes searching Pinyin bearable: typing "pingguo" finds
    /// "píngguǒ" without the user hunting for tone marks.
    static func matchesSearch(_ card: Card, searchText: String) -> Bool {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.isEmpty == false else { return true }

        return card.german.localizedStandardContains(term)
            || card.hanzi.localizedStandardContains(term)
            || card.pinyin.localizedStandardContains(term)
    }

    /// A card must carry **at least one** of the selected tags.
    ///
    /// This was AND until A32, on the argument that every filter in this
    /// screen narrows (A12). Measured against use, that argument was wrong
    /// about what ticking a second category means: the answer to "show me
    /// Essen **and** Reisen" is almost never "only cards that are both", and
    /// with a handful of cards per category the intersection is usually
    /// empty. Ticking two boxes now widens, which is also what the learning
    /// session has always done — A32 replaces A12 and the card-list half of
    /// A26.
    ///
    /// The other dimensions are untouched and still narrow: type, search and
    /// status keep combining with AND, so the categories are one OR group
    /// inside an AND chain.
    static func matchesTags(_ card: Card, tagKeys: Set<String>) -> Bool {
        guard tagKeys.isEmpty == false else { return true }
        return tagKeys.isDisjoint(with: keys(of: card)) == false
    }

    /// The card's normalised category keys.
    static func keys(of card: Card) -> Set<String> {
        Set(card.tags.map { TagNormalization.key(for: $0.name) })
    }

    static func matchesStatus(_ card: Card, status: LearningStatus?) -> Bool {
        guard let status else { return true }
        return card.status == status
    }
}
