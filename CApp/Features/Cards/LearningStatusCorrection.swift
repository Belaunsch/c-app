//
//  LearningStatusCorrection.swift
//  CApp
//

import Foundation
import SwiftData

/// Setting a card's learning status by hand.
///
/// ## Why this exists, and why it is not a learning answer
///
/// The assisted classification only ever offers a step **up**, and only with the
/// learner's consent (`docs/learning-engine.md` §13). Nothing in the app lowers a
/// status, and the exact text comparison the offers rest on has an unmeasured
/// false-accept rate — so a card carried upwards by two lucky recognitions needs
/// a way back. This is that way, and it is deliberately the *only* one.
///
/// **A correction is not an answer.** It writes no `ReviewLog`, moves no
/// `reviewCount`, moves no `correctCount`, and never puts a card back into a
/// running batch. Recording it as a review would invent a learning event that did
/// not happen, and the four self-assessments are not coming back through a side
/// door.
///
/// ## The evidence boundary is the whole difficulty
///
/// Setting the status alone is not enough, and the case that shows it is the
/// realistic one: a card goes *Mittel* → *Sicher*, the learner disagrees and
/// corrects it back to *Mittel*. Its old *Mittel*-era reviews are then comparable
/// again by the same-status rule, and the very next clean attempt would offer
/// *Mittel* → *Gut* — the promotion the learner just took away. So the correction
/// also stamps `classificationEvidenceResetAt`, and from then on only reviews
/// **after** that moment count as evidence.
///
/// The history is not deleted. The line moves; the entries stay.
///
/// ## Why it lives here rather than in the view
///
/// Same reason as `TagManagement`: it carries a rule (the no-op), it touches the
/// store irreversibly, and it has to be testable without a `body`. Deleting a
/// card, which decides nothing, stays in `CardListView`.
enum LearningStatusCorrection {

    /// Whether choosing `status` would change anything.
    ///
    /// Picking the status a card already has is a no-op: no write, no save, and
    /// above all **no new evidence boundary** — otherwise tapping the current
    /// status would silently throw away the card's eligible history while
    /// appearing to do nothing at all.
    static func changes(_ card: Card, to status: LearningStatus) -> Bool {
        card.status != status
    }

    /// Sets the status and moves the evidence boundary, in one save.
    ///
    /// - Parameter now: injected so a test can pin the boundary exactly. The
    ///   store is the only thing here that needs a clock, and `Learning/` still
    ///   has none.
    /// - Returns: whether anything was written.
    /// - Throws: `AppError.cardSaveFailed` when the store refuses the write. The
    ///   card is rolled back first, so an alert cannot claim failure while a
    ///   later save commits the change anyway — the same rule phase 2 set for
    ///   every other write on this screen.
    @discardableResult
    static func apply(
        _ status: LearningStatus,
        to card: Card,
        in context: ModelContext,
        now: () -> Date = Date.init
    ) throws -> Bool {
        guard changes(card, to: status) else { return false }

        card.status = status
        card.classificationEvidenceResetAt = now()

        // **Deliberately nothing else.** No `ReviewLog`, no `reviewCount`, no
        // `correctCount`, no `lastReviewedAt`: none of those happened.
        do {
            try context.save()
        } catch {
            context.rollback()
            throw AppError.cardSaveFailed(error)
        }
        return true
    }

    /// What VoiceOver says for one menu entry.
    ///
    /// **A checkmark is not a word.** Without this the menu reads as five
    /// interchangeable status names, one of which happens to carry an image — and
    /// which one is the card's current stand is exactly the information the marking
    /// exists to give. Same reason `RevealedDecisionBar.accessibilityLabel(from:to:)`
    /// spells out its arrow, and pulled out as a function for the same reason: a
    /// label written inline in a `body` is a promise no test can reach.
    static func accessibilityLabel(for status: LearningStatus, isCurrent: Bool) -> String {
        isCurrent ? "\(status.title), aktueller Lernstand" : status.title
    }

    /// The five statuses in the order the menu shows them.
    ///
    /// Bottom to top, matching the ladder of `docs/learning-engine.md` §6, so the
    /// menu reads the way the statuses are ordered everywhere else in the app.
    static var menuOrder: [LearningStatus] { LearningStatus.allCases }
}
