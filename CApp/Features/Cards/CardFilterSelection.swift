//
//  CardFilterSelection.swift
//  CApp
//

import Foundation

/// What the user has narrowed the card list down to.
///
/// A value type rather than three `@State` properties in the view, so the
/// questions the toolbar asks — is anything filtered, how much — are
/// answerable and testable without a view. The filter *semantics* live in
/// `CardFilter` and are unchanged: one status, and categories combined with
/// AND.
///
/// `nonisolated` like `CardType` and `LearningStatus`: the target defaults to
/// main-actor isolation, and a value type with no behaviour beyond its own
/// fields has no reason to require an actor. Without it even comparing two
/// of them in a test is main-actor work.
nonisolated struct CardFilterSelection: Equatable {

    /// `nil` means every status.
    var status: LearningStatus?

    /// Normalised category keys, see `TagNormalization`.
    var tagKeys: Set<String> = []

    /// Whether the list is showing less than everything.
    var hasActiveFilters: Bool {
        status != nil || tagKeys.isEmpty == false
    }

    /// How many of the two filter groups are in use. Shown as a number next
    /// to the toolbar icon — deliberately the number of groups, not of
    /// selected categories: it answers "how much of the list is hidden", not
    /// "how many boxes did I tick".
    var activeGroupCount: Int {
        (status == nil ? 0 : 1) + (tagKeys.isEmpty ? 0 : 1)
    }

    mutating func toggle(tagKey: String) {
        if tagKeys.contains(tagKey) {
            tagKeys.remove(tagKey)
        } else {
            tagKeys.insert(tagKey)
        }
    }

    mutating func reset() {
        status = nil
        tagKeys = []
    }
}
