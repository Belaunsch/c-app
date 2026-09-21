//
//  ReviewSignal.swift
//  CApp
//

import Foundation

/// One finished review, reduced to what the inference is allowed to look at.
///
/// The engine never sees a `ReviewLog` — that is a SwiftData model and belongs
/// outside this layer. The feature layer maps stored entries onto this value
/// type, exactly as it maps `Card` onto `CardSnapshot`. What is **not** here
/// is as deliberate as what is: no audio, no recogniser confidence, no
/// timing, no pronunciation or tone figure. None of those were ever measured
/// (hard rule 7), so none of them may reach a decision.
///
/// There is no timestamp either, and that is a decision rather than an
/// oversight — see `AssistedAssessment` on why recency is handled by the size
/// of the window instead of by a decay constant nobody has calibrated.
///
/// **And since phase 13 there is no `assessment` either.** The rule stopped
/// reading it when `isUsable` was replaced by the direction rule, and the store
/// remains the history — the same standard `docs/learning-engine.md` §13.10
/// applies to an *accepted* suggestion: a value the engine never reads does not
/// belong in the engine's input type. `ReviewLog.assessmentRaw` keeps it, which
/// is where a later calibration would look for it.
nonisolated struct ReviewSignal: Equatable, Sendable {

    /// Which way round the card was asked. Mode A and mode B ask different
    /// questions, so evidence from one is not automatically evidence about
    /// the other.
    let direction: SessionDirection

    /// The status the card had when the review started.
    let previousStatus: LearningStatus

    /// Whether the learner used the microphone at all.
    let usedSpeech: Bool

    /// Whether Apple's final text matched the stored Hanzi after
    /// normalisation. `nil` when no speech was used.
    ///
    /// **This is a statement about two texts and nothing else.** It says the
    /// recognised text equals the target text; it says nothing about how the
    /// words were said. The false-accept rate of that comparison is unmeasured
    /// (phase 9), which is why a single `true` carries so little weight here.
    let speechMatched: Bool?

    /// Whether the learner uncovered the answer without attempting it.
    /// Revealing is not a recall.
    let wasManualReveal: Bool

    /// Whether this was a repeat attempt at the same card inside one batch.
    let wasRetry: Bool

    /// The status the app suggested and the learner **declined** at this
    /// review, or `nil` when nothing was declined (phase 13).
    ///
    /// Derived at the mapping boundary from the two stored fields, because this
    /// is the only part of a suggestion the rule reads: an *accepted*
    /// suggestion moved the status, so its entry carries a different
    /// `previousStatus` and the same-status rule already excludes it.
    ///
    /// A declined suggestion ends the run **and does not count itself**
    /// (`docs/learning-engine.md` §13.7, rule 4): the learner said no, so the
    /// evidence for that particular step starts over.
    let declinedSuggestion: LearningStatus?

    init(
        direction: SessionDirection,
        previousStatus: LearningStatus,
        usedSpeech: Bool = false,
        speechMatched: Bool? = nil,
        wasManualReveal: Bool = false,
        wasRetry: Bool = false,
        declinedSuggestion: LearningStatus? = nil
    ) {
        self.direction = direction
        self.previousStatus = previousStatus
        self.usedSpeech = usedSpeech
        self.speechMatched = speechMatched
        self.wasManualReveal = wasManualReveal
        self.wasRetry = wasRetry
        self.declinedSuggestion = declinedSuggestion
    }

    /// A first-attempt success carried entirely by automatic evidence.
    ///
    /// All four conditions together, and each one is load-bearing:
    ///
    /// - **speech was used and matched** — the only automatic positive
    ///   evidence that exists in this app;
    /// - **not a retry** — the first attempt is the honest indicator, the
    ///   same principle §6.1 already applies to status changes;
    /// - **nothing was revealed first** — a learner who read the answer and
    ///   then said it has demonstrated reading aloud, not recall;
    /// Nothing about a rating enters this: a learner who agrees with the app's
    /// classification has still made a clean attempt, and since phase 13 the
    /// flow records no rating at all.
    var isCleanAutomaticSuccess: Bool {
        usedSpeech && speechMatched == true && wasRetry == false && wasManualReveal == false
    }

    /// Whether this review says anything about `direction` and `status`.
    ///
    /// **This replaces the phase-11 `isUsable`**, which asked whether an
    /// assessment or a microphone had been involved. That question stopped
    /// working in phase 13: a give-up without speech now carries neither, so
    /// `isUsable` would have *skipped* it — and „match, gave up, match" would
    /// have produced a suggestion. What a review is comparable to is a
    /// different question, and it has two halves:
    ///
    /// - **Same direction.** Mode B carries no correctness signal at all, so a
    ///   mode-B review is no information about recall in mode A. It is skipped
    ///   rather than treated as a break — practising the other direction must
    ///   not destroy evidence, and it must not create any either.
    /// - **Same previous status.** Only reviews taken *at* the card's current
    ///   status count, which is precisely „the evidence gathered since the
    ///   status last changed". It is also what protects a card the learner
    ///   reset to „Neu" by hand: its old history was recorded at other
    ///   statuses, so none of it can count.
    func isComparable(inDirection direction: SessionDirection, at status: LearningStatus) -> Bool {
        self.direction == direction && previousStatus == status
    }
}
