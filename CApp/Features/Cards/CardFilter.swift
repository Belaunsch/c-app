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
    ///     carry **all** of them (AND). Empty means no tag filter.
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

    /// A card must carry every selected tag, not just one of them.
    ///
    /// AND was chosen over OR so that every filter in **this** screen behaves
    /// the same way: adding one narrows the result. Type, search and status
    /// all narrow, so tags do too (A12).
    ///
    /// The learning session deliberately does **not** use this: there several
    /// categories mean "practise any of these", see
    /// `LearnSessionModel.poolCards` and A26. The two contexts ask different
    /// questions, so they get different answers rather than one compromise.
    static func matchesTags(_ card: Card, tagKeys: Set<String>) -> Bool {
        guard tagKeys.isEmpty == false else { return true }
        return tagKeys.isSubset(of: keys(of: card))
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
