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
/// That is OR: choosing two topics for a session should widen it, not reduce
/// it to the cards that carry both. The card list was the counter-example
/// when this was written (A26 versus A12) and has since adopted the same rule
/// (A32), so both screens now widen.
nonisolated struct SessionConfiguration: Equatable, Sendable {
    let cardType: CardType

    /// Normalised category keys, empty means every category.
    let tagKeys: Set<String>

    /// Which way round the card is asked.
    ///
    /// **Presentation only.** Nothing in `Learning/` reads this type at all —
    /// the feature layer builds the pool from it and hands snapshots in — so
    /// the direction cannot reach the weighting, the batch selection, the
    /// queue or the status transitions even by accident. That is the point
    /// of phase 8: a second way to ask the same question, not a second way
    /// to learn. An identical self-assessment on an identical card must
    /// produce the identical transition in both directions.
    let direction: SessionDirection

    /// `direction` defaults to ``SessionDirection/germanToChinese`` so that
    /// every caller and test written before phase 8 keeps meaning what it
    /// meant. Rewriting them to say "as before" would be churn that hides
    /// which call sites actually care.
    init(
        cardType: CardType,
        tagKeys: Set<String> = [],
        direction: SessionDirection = .germanToChinese
    ) {
        self.cardType = cardType
        self.tagKeys = tagKeys
        self.direction = direction
    }
}

/// Which way round a card is asked.
///
/// Deliberately without display names: `Learning/` holds no presentation
/// concerns and no German text. The titles live in `LearnDisplay`, the same
/// split `CardDisplay` makes for the models.
///
/// **Raw values since phase 11, and the reason is worth recording.** Until
/// then this type deliberately had none, with the note that one "would read
/// as: this gets persisted, and the direction deliberately is not". Phase 11
/// changed the premise rather than the principle: a `ReviewLog` entry records
/// which way round the card was asked, because mode A and mode B ask
/// different questions and evidence from one is not evidence about the other.
/// So the direction **is** persisted now, and the strings are written out for
/// the same reason as in `CardSortOrder` and `SpeechRate` — renaming a Swift
/// case must not silently rewrite stored history.
nonisolated enum SessionDirection: String, CaseIterable, Sendable {
    /// Mode A, since phase 6: the German is shown, the learner produces the
    /// Chinese.
    case germanToChinese = "germanToChinese"

    /// Mode B, since phase 8: the Chinese is **heard**, the learner works out
    /// the meaning. Audio to German, never audio to Hanzi — that would be a
    /// third mode and is explicitly out of scope.
    case audioToGerman = "audioToGerman"
}
