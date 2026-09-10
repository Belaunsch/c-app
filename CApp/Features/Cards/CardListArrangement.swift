//
//  CardListArrangement.swift
//  CApp
//

import Foundation

/// How the card list is ordered.
///
/// `nonisolated` like `CardType` and `CardFilterSelection`: a pure choice with
/// no behaviour beyond its own cases has no reason to require an actor.
/// The raw values are **written out** rather than left to the compiler,
/// because they are persisted in `UserDefaults`: with implicit raw values,
/// renaming a case would silently invalidate everybody's stored preference
/// and reset it to the default. Spelled out, a rename is a visible decision.
nonisolated enum CardSortOrder: String, CaseIterable, Identifiable, Sendable {
    case newestFirst = "newestFirst"
    case oldestFirst = "oldestFirst"
    case germanAscending = "germanAscending"
    case germanDescending = "germanDescending"
    case categoryAscending = "categoryAscending"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newestFirst: "Neueste zuerst"
        case .oldestFirst: "Älteste zuerst"
        case .germanAscending: "Deutsch A–Z"
        case .germanDescending: "Deutsch Z–A"
        case .categoryAscending: "Kategorie A–Z"
        }
    }

    /// Five distinct glyphs on purpose. Two opposite orders sharing one
    /// symbol reads as a duplicate entry, and `tag` is already the
    /// "manage categories" button in the same screen with a different
    /// meaning.
    var symbolName: String {
        switch self {
        case .newestFirst: "clock.arrow.circlepath"
        case .oldestFirst: "clock"
        case .germanAscending: "arrow.up"
        case .germanDescending: "arrow.down"
        case .categoryAscending: "list.bullet.indent"
        }
    }

    /// Whether this order splits the list into sections instead of one flat
    /// run of rows. Only the category order does — see
    /// ``CardListArrangement/sections(_:selectedTagKeys:)`` for why grouping
    /// needs its own rule rather than falling out of a sort.
    var isGrouped: Bool { self == .categoryAscending }

    /// The order the list had before sorting was offered, so switching the
    /// feature on changes nothing until the user asks for something else.
    /// Also what a fresh install starts with.
    static let `default` = CardSortOrder.germanAscending

    /// Where the choice is stored. A `UserDefaults` key, not a schema field:
    /// this is a local view preference with no place in the card data, and
    /// A32 said as much before it was persisted at all.
    static let storageKey = "cardList.sortOrder"

    /// Reads a stored raw value back, falling back to the default.
    ///
    /// The fallback is the point and the reason this is a function rather
    /// than a `CardSortOrder(rawValue:)` at the call site: what is in
    /// `UserDefaults` is whatever some past or future version of the app put
    /// there. A value from a case that has since been removed, a key
    /// someone edited, or nothing at all must all end in a usable list
    /// rather than a crash or an empty screen.
    static func restored(from raw: String?) -> CardSortOrder {
        guard let raw, let order = CardSortOrder(rawValue: raw) else { return .default }
        return order
    }
}

/// One group of the card list, with its heading.
///
/// Not `nonisolated`, because it holds `Card` — same reason `CardFilter` is
/// not: the model type is main-actor bound, and pretending otherwise would
/// only move the problem into a `@preconcurrency` annotation.
struct CardSection: Identifiable {
    let title: String
    let cards: [Card]

    /// The heading is the identity. Two sections with the same heading cannot
    /// exist — that is what ``CardListArrangement/sections(_:selectedTagKeys:)``
    /// guarantees by construction.
    var id: String { title }
}

/// Puts the already filtered cards in order, and — for the category order —
/// into sections.
///
/// Separate from `CardFilter` because the two answer different questions:
/// filtering decides **whether** a card is shown, arranging decides **where**.
/// Both run in plain Swift on a fetched array for the reasons `CardFilter`
/// documents, and both are directly testable without a view.
enum CardListArrangement {

    /// The heading for cards that carry no category at all. Always last.
    ///
    /// **Known collision, accepted:** a category the user names exactly
    /// "Ohne Kategorie" merges with this one and sorts to the end with it.
    /// Nothing breaks and no card duplicates — the section heading just
    /// carries two meanings. Reserving the name, or prefixing it out of
    /// reach, would cost more in explanation than the case is worth in a
    /// private app where the user names their own categories.
    static let uncategorizedTitle = "Ohne Kategorie"

    // MARK: - Sorting

    /// Sorts deterministically: the result never depends on the order the
    /// cards came in.
    ///
    /// Every comparison falls back to the card's stable `id` when the primary
    /// key ties. Without that, two cards with the same German text — or the
    /// same creation instant, which sample data and a fast import both
    /// produce — would land in whatever order `sorted(by:)` happened to
    /// leave them, and the list would reshuffle on every redraw.
    static func sort(_ cards: [Card], by order: CardSortOrder) -> [Card] {
        switch order {
        case .germanAscending:
            cards.sorted { byGerman($0, $1) }
        case .germanDescending:
            cards.sorted { byGerman($1, $0) }
        case .newestFirst:
            cards.sorted { byCreation($0, $1, newestFirst: true) }
        case .oldestFirst:
            cards.sorted { byCreation($0, $1, newestFirst: false) }
        case .categoryAscending:
            // Inside a section the rule is German A–Z (see `sections`). Sorting
            // the flat array the same way keeps this function total: a caller
            // that asks for the category order without sections still gets
            // something ordered rather than the fetch order.
            cards.sorted { byGerman($0, $1) }
        }
    }

    /// Compares the way a reader expects: `localizedStandardCompare` puts
    /// `Äpfel` next to `Apfel` instead of behind `Zebra`, which a raw
    /// `String` comparison on Unicode scalars would do.
    private static func byGerman(_ lhs: Card, _ rhs: Card) -> Bool {
        let result = lhs.german.localizedStandardCompare(rhs.german)
        guard result == .orderedSame else { return result == .orderedAscending }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func byCreation(_ lhs: Card, _ rhs: Card, newestFirst: Bool) -> Bool {
        guard lhs.createdAt != rhs.createdAt else {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return newestFirst
            ? lhs.createdAt > rhs.createdAt
            : lhs.createdAt < rhs.createdAt
    }

    // MARK: - Grouping

    /// Which section a card belongs to — **exactly one**, always.
    ///
    /// This is the rule that keeps a card from appearing twice in a list
    /// grouped by category, and it is a function rather than a loop in the
    /// view precisely so it can be falsified. A card with several categories
    /// has several plausible homes, so the choice is stated instead of
    /// emerging:
    ///
    /// - **With a category filter active:** the alphabetically first of the
    ///   card's categories **that the user selected**. Anything else would
    ///   file a card under a heading the user just filtered away.
    /// - **Without a filter:** the alphabetically first of its categories.
    /// - **No category at all:** ``uncategorizedTitle``.
    ///
    /// Since the category filter combines with OR (A32), a card that is
    /// visible while a filter is active always carries at least one selected
    /// category, so the first branch always finds one. A card that matches
    /// nothing would fall through to ``uncategorizedTitle`` — it cannot be on
    /// screen, and answering with a heading beats trapping.
    static func sectionTitle(for card: Card, selectedTagKeys: Set<String>) -> String {
        let names = card.tags.map(\.name)
        let candidates = selectedTagKeys.isEmpty
            ? names
            : names.filter { selectedTagKeys.contains(TagNormalization.key(for: $0)) }

        let first = candidates.min {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
        return first ?? uncategorizedTitle
    }

    /// Groups the cards into sections: headings alphabetical, cards inside a
    /// section by German A–Z, and `Ohne Kategorie` last.
    ///
    /// Each card is placed once, because ``sectionTitle(for:selectedTagKeys:)``
    /// answers with a single heading. That is the whole reason the grouping
    /// runs over cards rather than over categories: iterating categories and
    /// collecting their cards is the natural way to write this, and it is
    /// exactly what duplicates a card carrying two of them.
    static func sections(_ cards: [Card], selectedTagKeys: Set<String>) -> [CardSection] {
        var grouped: [String: [Card]] = [:]
        for card in cards {
            let title = sectionTitle(for: card, selectedTagKeys: selectedTagKeys)
            grouped[title, default: []].append(card)
        }

        return grouped
            .map { CardSection(title: $0.key, cards: sort($0.value, by: .germanAscending)) }
            // Called through a closure, not passed as a method reference:
            // a non-escaping closure inherits this function's isolation,
            // while a bare `byHeading` would be a nonisolated closure value
            // calling a main-actor method.
            .sorted { byHeading($0, $1) }
    }

    /// Alphabetical, except that `Ohne Kategorie` is always last — it is not a
    /// category name competing with the others but the absence of one, and
    /// sorting it as text would drop it somewhere in the middle of the
    /// alphabet.
    private static func byHeading(_ lhs: CardSection, _ rhs: CardSection) -> Bool {
        if lhs.title == uncategorizedTitle { return false }
        if rhs.title == uncategorizedTitle { return true }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}

/// The accordion rule of the card list: at most one card open at a time.
///
/// A function rather than an `if` in the tap handler, for the reason this
/// project pulls every decision out of its view: a `body` cannot be reached
/// from a test, so a rule that lives only there is a rule nobody can
/// falsify — the phase-7 audit made that point about four separate
/// conditions.
nonisolated enum CardExpansion {

    /// The new expansion after tapping `tapped`.
    ///
    /// Tapping the open card closes it; tapping any other card opens that one
    /// **and** closes whatever was open, because the answer is a single
    /// optional and not a set. The one-at-a-time guarantee is therefore
    /// structural rather than enforced.
    static func toggled(_ expanded: Card.ID?, tapped: Card.ID) -> Card.ID? {
        expanded == tapped ? nil : tapped
    }
}
