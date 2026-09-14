//
//  AssistedAssessment.swift
//  CApp
//

import Foundation

/// What the app does at the end of a review: ask, or move on.
nonisolated enum AssistedAssessmentDecision: Equatable, Sendable {

    /// Show Nochmal / Schwer / Gut / Sicher. `suggestion` is the step to
    /// highlight, or `nil` when the evidence does not support highlighting
    /// anything — then all four are offered plainly.
    ///
    /// **A suggestion is a highlight, never a result.** Nothing here changes
    /// a status; only a tap does.
    case ask(suggestion: LearningStatus?)

    /// Skip the four buttons and go to the next card.
    ///
    /// The status stays **exactly as it is**. That is the whole point of the
    /// roadmap's line „keine Neubewertung nötig": the app saves the learner a
    /// tap it cannot justify asking for, it does not award a promotion nobody
    /// granted.
    case autoAdvance

    var asksTheLearner: Bool {
        if case .ask = self { return true }
        return false
    }
}

/// Whether the app may skip the manual rating, and what it would suggest.
///
/// ## The honest state of this rule
///
/// The roadmap left window size, weights, ageing and thresholds **[OPEN]**,
/// to be settled „nachdem reale Review-Historie existiert". That history is
/// what this phase starts collecting, so it does not exist yet — the numbers
/// below are therefore **product decisions, not measurements**, and each one
/// is named as such. Nothing here is calibrated, and nothing here pretends to
/// be. The rule errs towards asking, because an unnecessary question costs a
/// tap and a wrong automatic promotion costs the learner's trust in the
/// status.
///
/// ## What the rule may and may not conclude (phase 9 constraints)
///
/// - A speech **mismatch never lowers anything**. It ends a streak, which
///   means the learner is asked — not marked down. The exact comparison is
///   brittle by construction: of 16 normally spoken target answers, 8 came
///   back as a different Chinese text.
/// - A **single** exact match carries nothing. The false-accept property of
///   the comparison was never measured — the phase-9 benchmark was abandoned
///   after the positive pass — so how often a match happens by accident is
///   unknown. Only a repeated streak is treated as evidence, and even then
///   only as permission to stop asking, never as a promotion.
/// - **Nothing here says anything about pronunciation or tones** (hard rule 7).
/// - The learner's own rating always wins: it is stored as given and it
///   restarts the recalibration count.
///
/// ## Where recency actually comes from
///
/// **From the run breaking, not from the window** — and the first version of
/// this comment said otherwise, which the audit was right to call out. The
/// run is counted from the newest review backwards and stops at the first
/// usable review that was not clean, so anything older than the most recent
/// slip cannot influence anything. That is the recency.
///
/// `windowSize` is an **upper bound on how much history is read**, not a
/// mechanism that changes a decision: with a threshold of two, capping a run
/// at ten can never move it below the threshold. It earns its place in the
/// feature layer, which maps only that many entries out of the store.
///
/// Time-based ageing is deliberately absent. A half-life with no data to fit
/// it would be exactly the pattern the phase-9 benchmark avoided, and it
/// stays deferred until real history exists.
nonisolated enum AssistedAssessment {

    // MARK: - The free parameters, all three of them product decisions

    /// How many of the most recent usable reviews are considered.
    ///
    /// **Product decision.** The roadmap's starting idea was „ungefähr die
    /// letzten zehn verwertbaren Versuche", and ten is what this is. No
    /// measurement supports ten over eight or twelve.
    ///
    /// Honestly: with the current threshold it cannot change a decision — see
    /// the note above. It bounds what is read, which is a real bound on a
    /// history that grows for as long as the app is used.
    static let windowSize = 10

    /// How many consecutive clean automatic successes — counting the one just
    /// finished — are required before the app stops asking.
    ///
    /// **Product decision, chosen conservatively at 2.** The roadmap says
    /// repeated matches „können als *potenzielle* positive Evidenz" count and
    /// that a single one must not carry a strong statement. Two is the
    /// smallest number that is not one. It is deliberately not tuned upwards
    /// either: the feature exists to remove taps, and a threshold of five
    /// would remove none in practice.
    static let cleanRunBeforeAutoAdvance = 2

    /// How many reviews in a row the app may auto-advance before it asks
    /// again, even while the streak continues.
    ///
    /// **Product decision at 3.** Without it a card with a long match streak
    /// would never be re-rated and its status would freeze — evidence would
    /// accumulate and never be allowed to mean anything. Asking every third
    /// time is the recalibration the roadmap asks for, and it is the only
    /// moment a status can actually move.
    static let autoAdvancesBeforeRecalibration = 3

    // MARK: - The decision

    /// - Parameters:
    ///   - currentStatus: the card's status right now.
    ///   - current: the review that has just happened, without an assessment.
    ///   - history: earlier reviews of the **same card**, newest first.
    static func decision(
        currentStatus: LearningStatus,
        current: ReviewSignal,
        history: [ReviewSignal]
    ) -> AssistedAssessmentDecision {
        let suggestion = suggestedStatus(
            currentStatus: currentStatus, current: current, history: history
        )

        // 1. A card nobody has ever rated is rated by a person first. There is
        //    no evidence about it yet, and an exact match on a brand-new card
        //    says the learner could say the word — not that it is learned.
        //
        //    **And with no suggestion at all.** The review found the hole: a
        //    card the learner had reset to „Neu" by hand still carries its
        //    history, so an old clean run would have highlighted a promotion
        //    on exactly the card the learner had just declared unlearned. The
        //    reset is a statement, and „die manuelle Bewertung hat Vorrang"
        //    covers that one too.
        guard currentStatus != .new else { return .ask(suggestion: nil) }

        // 2. Only a clean first-attempt success can ever skip the question.
        //    Mismatch, manual reveal, retry and „no speech at all" all land
        //    here, and all of them mean the same thing: ask, plainly.
        guard current.isCleanAutomaticSuccess else { return .ask(suggestion: suggestion) }

        // 3. Repeated, not single.
        let run = cleanRun(current: current, history: history)
        guard run >= cleanRunBeforeAutoAdvance else { return .ask(suggestion: suggestion) }

        // 4. Recalibration. Counted from the most recent reviews backwards,
        //    and inside the same window as everything else: the two counts
        //    used to disagree about what „recent" meant, which only stayed
        //    harmless because the caller already trimmed the list.
        let skipped = window(history).prefix(while: { $0.assessment == nil }).count
        guard skipped < autoAdvancesBeforeRecalibration else { return .ask(suggestion: suggestion) }

        return .autoAdvance
    }

    /// The `SuggestedLearningStatus` — the step to highlight, or `nil`.
    ///
    /// One step up and never more, and never down. Up is the only direction
    /// the available evidence can point: a streak of clean attempts is a
    /// reason to offer „Gut". A downgrade would have to come from a mismatch,
    /// and a mismatch is not negative evidence.
    static func suggestedStatus(
        currentStatus: LearningStatus,
        current: ReviewSignal,
        history: [ReviewSignal]
    ) -> LearningStatus? {
        // No separate check for „was this a clean attempt": `cleanRun` returns
        // zero for anything else, so the threshold below already covers it.
        // The duplicate guard that used to stand here was provably dead — a
        // counter-mutation removed it and nothing went red, which is the
        // honest way to find out.
        let run = cleanRun(current: current, history: history)
        guard run >= cleanRunBeforeAutoAdvance else { return nil }

        let suggested = StatusTransition.newStatus(from: currentStatus, for: .good)
        // At the top of the ladder there is nothing to suggest: highlighting
        // „Gut" on a secure card would propose a step that changes nothing.
        return suggested == currentStatus ? nil : suggested
    }

    /// Which of the four answers would move `current` to `status`.
    ///
    /// The bar shows assessments, the rule produces a status; this is the one
    /// place that translates. It searches rather than hard-coding „Gut", so
    /// it stays correct if the rule above ever suggests something else — and
    /// `SelfAssessment.allCases` is ordered from the largest downward step to
    /// the largest upward one, so the first match is the gentlest answer that
    /// reaches the target.
    static func assessment(leadingTo status: LearningStatus, from current: LearningStatus) -> SelfAssessment? {
        SelfAssessment.allCases.first {
            StatusTransition.newStatus(from: current, for: $0) == status
        }
    }

    /// The part of the history the rule is allowed to look at.
    ///
    /// One definition for every count in this type. Recency is expressed
    /// here and nowhere else — see the note on why there is no decay constant.
    private static func window(_ history: [ReviewSignal]) -> ArraySlice<ReviewSignal> {
        history.prefix(windowSize)
    }

    /// How many clean automatic successes end the history, counting `current`.
    ///
    /// Unusable reviews are skipped rather than counted as breaks — a review
    /// carries no information about speech if speech was never used, and
    /// skipping it is not the same as treating it as a success: it is not
    /// counted either.
    ///
    /// **This branch cannot be reached by anything the app writes today**, and
    /// the review was right to point it out: every stored entry carries either
    /// an assessment or a speech attempt. It is kept as a deliberate
    /// definition rather than removed — should a later phase ever record a
    /// review with neither, „no information" is the honest reading, not „a
    /// break in the run".
    private static func cleanRun(current: ReviewSignal, history: [ReviewSignal]) -> Int {
        guard current.isCleanAutomaticSuccess else { return 0 }

        var run = 1
        for signal in window(history) {
            guard signal.isUsable else { continue }
            guard signal.isCleanAutomaticSuccess else { break }
            run += 1
        }
        return run
    }
}
