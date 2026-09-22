//
//  CardExplanationEntry.swift
//  CApp
//

import Foundation

/// Where the explanation may be offered, and under which condition.
///
/// Two callers, two different rules — and that difference is the whole reason
/// this type exists rather than a condition in each `body`:
///
/// - The **card list** offers the entry whenever the state is shown at all, so a
///   recoverable state appears greyed out with its reason.
/// - The **learning card** offers it only when it is actually usable. No dead
///   button and no explanatory text there (A51): the reason would stand under
///   *every* revealed card for the whole session — the prose phase 13 just
///   removed — and that stack has no `ScrollView`, so a sentence card with a
///   mismatch note could overflow.
///
/// Both rules live here for the reason `CardFilter` and `LearnFlow` give: a rule
/// inside a view is a promise no test can reach. The second audit found exactly
/// that — the `isEnabled` half of A51 had stayed at the call site, where
/// removing it would have broken a user-visible rule with all tests green.
nonisolated enum CardExplanationEntry {

    /// The symbol both entry points use.
    ///
    /// One constant rather than two literals, and `SystemSymbolTests` checks
    /// *this* — so a typo cannot survive at one call site while the other is
    /// fine. `SystemSymbolTests` can only verify that listed names resolve, not
    /// that the code uses listed names; sharing the constant closes that gap for
    /// this symbol instead of hoping the hand-kept list stays in step.
    static let symbolName = "text.book.closed"

    /// In the card list: shown whenever there is anything to show.
    static func isOfferedInList(_ availability: AIAvailability) -> Bool {
        availability.showsEntry
    }

    /// On the learning card: only revealed, and only when usable.
    ///
    /// `isRevealed` first on purpose — a covered card has no entry **whatever**
    /// the model says, so no availability state can ever put one there.
    static func isOfferedOnLearningCard(
        _ availability: AIAvailability,
        isRevealed: Bool
    ) -> Bool {
        isRevealed && availability.isEnabled
    }
}
