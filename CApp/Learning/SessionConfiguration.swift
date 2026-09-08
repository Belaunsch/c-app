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
/// optionally a set of category keys that a card must **all** belong to, the
/// same AND semantics the card list already uses (`docs/architecture.md`
/// A12).
nonisolated struct SessionConfiguration: Equatable, Sendable {
    let cardType: CardType

    /// Normalised category keys, empty means every category.
    let tagKeys: Set<String>

    init(cardType: CardType, tagKeys: Set<String> = []) {
        self.cardType = cardType
        self.tagKeys = tagKeys
    }
}
