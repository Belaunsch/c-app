//
//  LearnCategorySelection.swift
//  CApp
//

import Foundation

/// Which categories the next session draws from.
///
/// ## One state, shown honestly
///
/// The selection is a `Set` of normalised category keys, and **empty means
/// everything** — that is what `LearnSessionModel.matchesAnyCategory` has
/// always done and nothing here changes it. What changes is that the setup
/// screen no longer leaves that meaning implicit.
///
/// An empty set used to be visible only as *nothing highlighted*, which reads
/// as "you have not chosen yet" rather than "you have chosen everything". So
/// there is an **Alle** chip, and it is selected exactly when the set is
/// empty. Tapping it empties the set; picking any category fills it and Alle
/// stops being selected on its own.
///
/// That is deliberately **not** a second piece of state. Alle is a rendering
/// of `tagKeys.isEmpty`, not a flag beside it — two sources for one meaning
/// is how "everything selected and also nothing selected" happens. The rule
/// lives here as a function so it can be falsified rather than trusted.
///
/// Selecting is all this screen does. Creating, renaming and deleting
/// categories live in the category management screen; a setup that also
/// administered its own options would put an irreversible action one
/// mis-tap away from "start practising".
nonisolated enum LearnCategorySelection {

    /// The selection that means "no restriction".
    static let everything: Set<String> = []

    /// Whether the current selection means "everything".
    ///
    /// Also what draws the Alle chip as selected — hence a function and not
    /// an `isEmpty` at the call site: if the meaning of an empty set ever
    /// changes, it changes in one place and the tests say so.
    static func isEverything(_ tagKeys: Set<String>) -> Bool {
        tagKeys.isEmpty
    }

    /// Adds or removes one category.
    ///
    /// Deselecting the last one lands back on "everything", which is the
    /// same move as tapping Alle. Two ways to reach one state is fine; two
    /// states meaning one thing would not be.
    static func toggled(_ tagKeys: Set<String>, key: String) -> Set<String> {
        var next = tagKeys
        if next.contains(key) {
            next.remove(key)
        } else {
            next.insert(key)
        }
        return next
    }
}
