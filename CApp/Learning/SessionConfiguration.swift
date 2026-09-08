//
//  SessionConfiguration.swift
//  CApp
//

import Foundation

/// Which cards a session draws from.
///
/// The engine does not build the pool — it cannot, since that means querying
/// the store. This type is what the feature layer filters by before handing
/// the resulting snapshots in: one card type, never mixed (`CardType`), and
/// optionally a set of category keys of which a card needs **at least one**.
///
/// That is OR, deliberately unlike the card list's AND: choosing two topics
/// for a session should widen it, not reduce it to the cards that carry both
/// (`docs/architecture.md` A26 versus A12).
nonisolated struct SessionConfiguration: Equatable, Sendable {
    let cardType: CardType

    /// Normalised category keys, empty means every category.
    let tagKeys: Set<String>

    init(cardType: CardType, tagKeys: Set<String> = []) {
        self.cardType = cardType
        self.tagKeys = tagKeys
    }
}
