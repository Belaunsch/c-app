//
//  AssistedAssessment.swift
//  CApp
//

import Foundation

/// What the app does at the end of a review: move on, or offer a new
/// classification.
///
/// **Two cases, and there is deliberately no third.** Until phase 12 there
/// were three possible endings — ask with four buttons, ask with a highlighted
/// suggestion, or advance silently. The four buttons came *after* the answer
/// was already on screen, where the difference between „Schwer" and „Gut" is a
/// mood rather than an observation, and the silent advance moved the card on
/// with no feedback at all. Phase 13 replaces both: every card ends with one
/// tap, and the app only asks a question when it has evidence for one concrete
/// step up.
nonisolated enum AssistedClassificationDecision: Equatable, Sendable {

    /// Show a single „Weiter". The status stays **exactly** as it is.
    case continueOnly

    /// Offer the suggested status: „Neue Einstufung — Mittel → Gut", with
    /// „Ablehnen" and „Bestätigen".
    ///
    /// **A suggestion is not a result.** Nothing here changes a status; only a
    /// tap on „Bestätigen" does, and „Ablehnen" is the neutral way out.
    case propose(LearningStatus)

    /// The suggested status, or `nil` when there is nothing to offer.
    var proposedStatus: LearningStatus? {
        if case .propose(let status) = self { return status }
        return nil
    }
}

/// Whether the app may offer a higher classification, and which one.
///
/// ## The honest state of this rule
///
/// The threshold below is a **product decision, not a measurement** — the same
/// caveat phase 11 recorded, and it still holds. What phase 13 adds is the
/// first way to ever calibrate it: declined suggestions are now recorded, so
/// how often a suggestion is accepted becomes measurable. Nothing here is
/// calibrated yet, and nothing here pretends to be. The rule errs towards
/// silence, because an unnecessary question costs a tap while a wrong
/// promotion costs the learner's trust in the status.
///
/// ## What the rule may and may not conclude
///
/// - A speech **mismatch never lowers anything and never suggests anything**.
///   It ends a run, which means „no question this time" — not „marked down".
///   The exact comparison is brittle by construction: of 16 normally spoken
///   target answers, 8 came back as a different Chinese text (phase 9).
/// - A **single** exact match carries nothing. The false-accept property of
///   that comparison was never measured, so how often a match happens by
///   accident is unknown. Only a repeated run counts, and even then only as
///   permission to *offer* a step.
/// - A **retry** is not weaker positive evidence, it is none at all.
/// - **Revealing by hand — „Aufgeben" — is not positive evidence**, and it ends
///   the run.
/// - **There is no downgrade here.** Not from a mismatch, not from a run of
///   mismatches, not from anything this rule can conclude. Phase 13 removed the
///   two assessments that used to lower a status; what took their place is the
///   learner's own correction in the card list — the only way down the app has,
///   and deliberately outside this rule (`docs/learning-engine.md` §6.2, §13.13).
/// - **Nothing here says anything about pronunciation or tones** (hard rule 7).
/// - The learner decides: no status moves without a tap on „Bestätigen".
///
/// ## Where recency comes from
///
/// **From the run breaking, not from the window.** The run is counted from the
/// newest review backwards and stops at the first comparable review that was
/// not clean, so anything older than the most recent slip cannot influence
/// anything.
///
/// `windowSize` is an upper bound on how much history is *read*. One honest
/// consequence of the direction rule below: a learner who does ten mode-B
/// reviews in a row hides their older mode-A evidence behind that bound. The
/// failure direction is the safe one — the app offers nothing and asks nothing,
/// so the status simply does not move.
///
/// **And the history reaching this rule is bounded from below as well.** When the
/// learner corrects a status by hand, everything recorded before that moment stops
/// counting — otherwise a card set back down would be offered the same promotion
/// again out of the evidence it collected the first time round. That cut is made
/// where the history is handed over (`LearnSessionModel.recentSignals`), not here:
/// it needs a clock and a stored date, and this layer has neither
/// (`docs/learning-engine.md` §13.13). Reading this file alone therefore does not
/// tell the whole rule, which is why it is said here.
nonisolated enum AssistedAssessment {

    // MARK: - The free parameters

    /// How many of the most recent reviews are read at all.
    ///
    /// **Product decision.** The roadmap's starting idea was „ungefähr die
    /// letzten zehn verwertbaren Versuche", and ten is what this is. No
    /// measurement supports ten over eight or twelve. It bounds the work done
    /// on a history that grows for as long as the app is used.
    static let windowSize = 10

    /// How many consecutive clean comparable successes — counting the one just
    /// finished — are required before the app offers a higher classification.
    ///
    /// **Product decision, deliberately 2.** Repeated matches may count as
    /// *potential* positive evidence; a single one must not carry a statement.
    /// Two is the smallest number that is not one. It is not tuned upwards
    /// either: at five the feature would never fire in practice.
    ///
    /// Renamed from phase 11's `cleanRunBeforeAutoAdvance`, and the meaning
    /// moved with the name: it is the threshold for **making a suggestion**,
    /// not for skipping a question.
    static let cleanRunBeforeSuggestion = 2

    // MARK: - The decision

    /// - Parameters:
    ///   - currentStatus: the card's status right now.
    ///   - current: the review that has just happened.
    ///   - history: earlier reviews of the **same card**, newest first.
    static func decision(
        currentStatus: LearningStatus,
        current: ReviewSignal,
        history: [ReviewSignal]
    ) -> AssistedClassificationDecision {
        guard let proposal = proposedStatus(from: currentStatus) else {
            // Top of the ladder: „Gut" on a secure card changes nothing, so
            // there is nothing to offer.
            return .continueOnly
        }
        let run = cleanRun(current: current, history: history, at: currentStatus, proposal: proposal)
        guard run >= cleanRunBeforeSuggestion else { return .continueOnly }
        return .propose(proposal)
    }

    /// One step up the ladder of §6, or `nil` at the top.
    ///
    /// Up is the only direction the available evidence can point, and one step
    /// is the whole of it. Built from `StatusTransition` rather than from its
    /// own table, so there is exactly one ladder in this app: the *Gut* column
    /// of the matrix in §6, which gives `Neu → Mittel`, `Schwach → Mittel`,
    /// `Mittel → Gut`, `Gut → Sicher` and nothing for *Sicher*.
    ///
    /// `Neu → Mittel` skips *Schwach* on purpose: §6 works out *Neu* as level 1
    /// (*Schwach*), so rewarding two clean attempts with *Schwach* would read
    /// as a downgrade.
    static func proposedStatus(from status: LearningStatus) -> LearningStatus? {
        let next = StatusTransition.newStatus(from: status, for: .good)
        return next == status ? nil : next
    }

    /// How many clean comparable successes end the history, counting `current`.
    ///
    /// The walk, in the order the checks matter:
    ///
    /// 1. `current` itself must be a clean attempt — a mismatch, a retry or a
    ///    give-up ends the matter immediately, whatever came before.
    /// 2. Reviews from the other direction, or taken at another status, are
    ///    **skipped**: they are not comparable, and skipping is not the same as
    ///    counting them.
    /// 3. A review carrying a decline of *this* suggestion ends the run and is
    ///    **not counted** — the learner's „no" resets the evidence for that
    ///    step to zero.
    /// 4. Any other comparable review that is not clean ends the run.
    private static func cleanRun(
        current: ReviewSignal,
        history: [ReviewSignal],
        at status: LearningStatus,
        proposal: LearningStatus
    ) -> Int {
        guard current.isCleanAutomaticSuccess else { return 0 }

        var run = 1
        for signal in window(history) {
            guard signal.isComparable(inDirection: current.direction, at: status) else { continue }
            guard signal.declinedSuggestion != proposal else { break }
            guard signal.isCleanAutomaticSuccess else { break }
            run += 1
        }
        return run
    }

    /// The part of the history the rule is allowed to look at.
    private static func window(_ history: [ReviewSignal]) -> ArraySlice<ReviewSignal> {
        history.prefix(windowSize)
    }
}
