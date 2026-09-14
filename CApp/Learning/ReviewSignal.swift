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

    /// What the learner rated, or `nil` when the app advanced on its own.
    let assessment: SelfAssessment?

    init(
        direction: SessionDirection,
        previousStatus: LearningStatus,
        usedSpeech: Bool = false,
        speechMatched: Bool? = nil,
        wasManualReveal: Bool = false,
        wasRetry: Bool = false,
        assessment: SelfAssessment? = nil
    ) {
        self.direction = direction
        self.previousStatus = previousStatus
        self.usedSpeech = usedSpeech
        self.speechMatched = speechMatched
        self.wasManualReveal = wasManualReveal
        self.wasRetry = wasRetry
        self.assessment = assessment
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
    /// - **no assessment was given** is *not* required: a learner may confirm
    ///   a clean attempt by hand, and that stays a clean attempt.
    var isCleanAutomaticSuccess: Bool {
        usedSpeech && speechMatched == true && wasRetry == false && wasManualReveal == false
    }

    /// Whether this review contains any evidence the inference may use.
    ///
    /// A mismatch counts as usable — not as negative evidence, but as a fact
    /// that ends a streak. The distinction matters: ending a streak means
    /// "ask the learner again", never "lower the status".
    var isUsable: Bool {
        assessment != nil || usedSpeech
    }
}
