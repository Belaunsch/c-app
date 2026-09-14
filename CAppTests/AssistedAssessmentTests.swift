//
//  AssistedAssessmentTests.swift
//  CAppTests
//

import Foundation
import SwiftUI
import Testing
@testable import CApp

/// The rule that decides whether the learner is asked, and what is suggested.
///
/// The point of these tests is not that the current numbers come out — it is
/// that the **boundaries** hold: automatic evidence may shorten a question, it
/// may never lower a status, a single match is worth nothing, and the learner's
/// own rating always wins. Those four survive a recalibration of the window or
/// the thresholds; the numbers may not.
struct AssistedAssessmentTests {

    // MARK: - Fixtures

    private func clean(assessment: SelfAssessment? = nil) -> ReviewSignal {
        ReviewSignal(
            direction: .germanToChinese, previousStatus: .good,
            usedSpeech: true, speechMatched: true, assessment: assessment
        )
    }

    private func mismatch() -> ReviewSignal {
        ReviewSignal(
            direction: .germanToChinese, previousStatus: .good,
            usedSpeech: true, speechMatched: false
        )
    }

    private func manual(_ assessment: SelfAssessment) -> ReviewSignal {
        ReviewSignal(
            direction: .germanToChinese, previousStatus: .good,
            assessment: assessment
        )
    }

    // MARK: - No evidence at all

    @Test("A card nobody has ever rated is rated by a person")
    func freshCardAlwaysAsks() {
        // Status `new` means no evidence exists. An exact match on such a card
        // shows the learner could say the word, not that they have learned it.
        //
        // The history is deliberately one **rated** clean review: that gives a
        // run of two without tripping the recalibration guard, so the only
        // thing that can produce a question here is the rule about `new`
        // itself. A counter-mutation found the first version of this test
        // passing for the wrong reason — recalibration caught it, and removing
        // the `new` guard changed nothing.
        let decision = AssistedAssessment.decision(
            currentStatus: .new, current: clean(), history: [clean(assessment: .good)]
        )
        // **And with no suggestion.** The reset to „Neu" is a statement by the
        // learner, and the old history is still attached to the card — without
        // this the app would highlight a promotion on exactly the card its
        // owner had just declared unlearned.
        #expect(decision == .ask(suggestion: nil))

        // The same history on a card that is **not** new does skip the
        // question, which is what makes the line above about `new` and not
        // about the history.
        #expect(AssistedAssessment.decision(
            currentStatus: .weak, current: clean(), history: [clean(assessment: .good)]
        ) == .autoAdvance)
    }

    @Test("Without any history the learner is asked")
    func noHistoryAsks() {
        let decision = AssistedAssessment.decision(
            currentStatus: .good, current: clean(), history: []
        )
        #expect(decision == .ask(suggestion: nil), "one match is not evidence")
    }

    @Test("Without speech there is nothing automatic to go on", arguments: [
        LearningStatus.weak, .medium, .good, .secure,
    ])
    func withoutSpeechAsks(status: LearningStatus) {
        // The whole feature rests on one automatic signal. A learner who never
        // taps the microphone sees exactly the app of phase 10.
        let attempt = ReviewSignal(direction: .germanToChinese, previousStatus: status)
        let decision = AssistedAssessment.decision(
            currentStatus: status, current: attempt,
            history: [clean(), clean(), clean(), clean()]
        )
        #expect(decision == .ask(suggestion: nil))
    }

    // MARK: - A single match versus a repeated one

    @Test("A single exact match carries nothing")
    func singleMatchIsNotEnough() {
        // Phase 9 measured that the exact comparison is brittle, and the
        // false-accept property was never measured at all. One match must
        // therefore neither skip the question nor highlight an answer.
        let decision = AssistedAssessment.decision(
            currentStatus: .good, current: clean(), history: [manual(.good)]
        )
        #expect(decision == .ask(suggestion: nil))
    }

    @Test("Two clean attempts in a row are enough to stop asking")
    func repeatedMatchAdvances() {
        let decision = AssistedAssessment.decision(
            currentStatus: .good, current: clean(), history: [clean(assessment: .good)]
        )
        #expect(decision == .autoAdvance)
    }

    @Test("The run has to be unbroken")
    func aMismatchBreaksTheRun() {
        // The mismatch sits between two clean attempts. It does not lower
        // anything — it means the evidence is not a run any more, so the
        // learner is asked.
        let decision = AssistedAssessment.decision(
            currentStatus: .good, current: clean(),
            history: [mismatch(), clean(), clean(), clean()]
        )
        #expect(decision == .ask(suggestion: nil))
    }

    // MARK: - What a mismatch may and may not do

    @Test("A mismatch never lowers anything and never suggests a downgrade")
    func mismatchIsNotNegativeEvidence() {
        for status in LearningStatus.allCases {
            let decision = AssistedAssessment.decision(
                currentStatus: status, current: mismatch(),
                history: [mismatch(), mismatch(), mismatch()]
            )
            // Asked, plainly — and with no suggestion at all. Any suggestion
            // here would be the app proposing a downgrade from a signal that
            // phase 9 showed cannot carry one.
            #expect(decision == .ask(suggestion: nil), "\(status) must not be talked down")
        }
    }

    @Test("Three mismatches in a row still suggest nothing")
    func repeatedMismatchIsStillNotEvidence() {
        let suggestion = AssistedAssessment.suggestedStatus(
            currentStatus: .secure, current: mismatch(),
            history: [mismatch(), mismatch()]
        )
        #expect(suggestion == nil)
    }

    // MARK: - Manual reveal and retry

    @Test("Reading the answer first is not a recall")
    func manualRevealAsks() {
        let peeked = ReviewSignal(
            direction: .germanToChinese, previousStatus: .good,
            usedSpeech: true, speechMatched: true, wasManualReveal: true
        )
        let decision = AssistedAssessment.decision(
            currentStatus: .good, current: peeked, history: [clean(), clean(), clean()]
        )
        #expect(decision == .ask(suggestion: nil))
    }

    @Test("A second attempt at the same card is not a first attempt")
    func retryAsks() {
        let retry = ReviewSignal(
            direction: .germanToChinese, previousStatus: .good,
            usedSpeech: true, speechMatched: true, wasRetry: true
        )
        let decision = AssistedAssessment.decision(
            currentStatus: .good, current: retry, history: [clean(), clean(), clean()]
        )
        #expect(decision == .ask(suggestion: nil))
    }

    // MARK: - Recalibration

    @Test("After enough automatic reviews the app asks again")
    func recalibrationAsks() {
        // Three in a row were decided by the app; the fourth goes back to the
        // learner even though the run continues. Without this a card with a
        // long streak would never be re-rated and its status would freeze.
        let skipped = Array(repeating: clean(), count: AssistedAssessment.autoAdvancesBeforeRecalibration)
        let decision = AssistedAssessment.decision(
            currentStatus: .good, current: clean(), history: skipped
        )
        #expect(decision.asksTheLearner)
        #expect(decision == .ask(suggestion: .secure), "and it says what it would pick")
    }

    @Test("A rating by the learner restarts the count")
    func ownRatingRestartsRecalibration() {
        // Same three automatic reviews, but the learner rated the newest one.
        // The count is measured from the most recent rating, so there is room
        // again.
        var history = Array(repeating: clean(), count: AssistedAssessment.autoAdvancesBeforeRecalibration)
        history[0] = clean(assessment: .good)
        let decision = AssistedAssessment.decision(
            currentStatus: .good, current: clean(), history: history
        )
        #expect(decision == .autoAdvance)
    }

    // MARK: - The suggestion itself

    @Test("The suggestion is one step up, never two and never down")
    func suggestionIsOneStep() {
        // Literal expectations, not `StatusTransition.newStatus(…)` again —
        // the first version restated the implementation and would have
        // followed it into any change. These three come from the matrix in
        // §6 by hand.
        let expected: [LearningStatus: LearningStatus] = [
            .weak: .medium, .medium: .good, .good: .secure,
        ]
        for (status, target) in expected {
            let suggestion = AssistedAssessment.suggestedStatus(
                currentStatus: status, current: clean(), history: [clean()]
            )
            #expect(suggestion == target, "from \(status)")
            #expect(suggestion.map { $0 > status } == true, "up, and only up")
        }
    }

    @Test("At the top of the ladder there is nothing to suggest")
    func noSuggestionAtTheTop() {
        // `secure` plus „Gut" is still `secure`. Highlighting a button that
        // changes nothing would be noise.
        #expect(AssistedAssessment.suggestedStatus(
            currentStatus: .secure, current: clean(), history: [clean()]
        ) == nil)
    }

    @Test("The suggested status maps back to the gentlest answer that reaches it")
    func suggestionMapsToAnAnswer() {
        for status in [LearningStatus.new, .weak, .medium, .good] {
            let target = StatusTransition.newStatus(from: status, for: .good)
            let assessment = AssistedAssessment.assessment(leadingTo: target, from: status)
            #expect(assessment == .good, "from \(status)")
        }
    }

    // MARK: - Both directions, same rule

    @Test("The rule does not care which way round the card was asked")
    func bothDirectionsBehaveAlike() {
        // Phase 8 made the direction presentation-only, and phase 11 does not
        // change that: it is recorded so that evidence can later be told
        // apart, not so that one mode learns faster than the other.
        func run(_ direction: SessionDirection) -> AssistedAssessmentDecision {
            let attempt = ReviewSignal(
                direction: direction, previousStatus: .good,
                usedSpeech: true, speechMatched: true
            )
            return AssistedAssessment.decision(
                currentStatus: .good, current: attempt,
                history: [ReviewSignal(direction: direction, previousStatus: .good,
                                       usedSpeech: true, speechMatched: true)]
            )
        }
        // The value is pinned, not just compared: the first version only
        // asserted that the two agree, so a regression to „both ask" would
        // have stayed green. The audit found it.
        #expect(run(.germanToChinese) == .autoAdvance)
        #expect(run(.audioToGerman) == .autoAdvance)
    }

    // MARK: - The parameters are named as decisions, not measurements

    @Test("The three free parameters are the documented ones")
    func parametersArePinned() {
        // Pinned so a change is a decision someone makes, not a drift. None of
        // these is measured — the roadmap left them open until real review
        // history exists, and this phase is what starts collecting it.
        #expect(AssistedAssessment.windowSize == 10)
        #expect(AssistedAssessment.cleanRunBeforeAutoAdvance == 2)
        #expect(AssistedAssessment.autoAdvancesBeforeRecalibration == 3)
    }

    @Test("Recency comes from the run breaking, not from the window")
    func recencyComesFromTheRun() {
        // The audit was right about the first version of this test: it claimed
        // to pin the window and pinned the mismatch instead. So here is what
        // actually governs the decision.
        //
        // An old clean history with **one** recent slip in front of it: the
        // run ends at the slip, and everything older cannot bring it back.
        // The newest entry is rated, so the recalibration count is zero and
        // cannot be what decides either case — the only difference between
        // the two runs below is the slip.
        let older = [clean(assessment: .good)] + [ReviewSignal](repeating: clean(), count: 5)
        #expect(AssistedAssessment.decision(
            currentStatus: .good, current: clean(), history: [mismatch()] + older
        ) == .ask(suggestion: nil))

        #expect(AssistedAssessment.decision(
            currentStatus: .good, current: clean(), history: older
        ) == .autoAdvance)
    }

    @Test("The window bounds what is read, and is honest about not deciding")
    func windowIsAnUpperBoundOnly() {
        // Documented rather than pretended: with a threshold of two, capping a
        // run at ten cannot push it below the threshold, so `windowSize`
        // cannot change a decision. It bounds how much history the feature
        // layer maps out of the store, which is a real bound on data that
        // grows for as long as the app is used.
        let long = [ReviewSignal](repeating: clean(), count: AssistedAssessment.windowSize * 3)
        #expect(AssistedAssessment.decision(
            currentStatus: .good, current: clean(assessment: .good), history: long
        ) == .ask(suggestion: .secure), "recalibration is what stops this, not the window")

        #expect(AssistedAssessment.windowSize >= AssistedAssessment.cleanRunBeforeAutoAdvance,
                "a window below the threshold would silently disable the feature")
    }

    @Test("A decision either asks or does not")
    func asksTheLearnerIsNotAlwaysTrue() {
        // `asksTheLearner` had no assertion for `false` anywhere, so making it
        // constant would have gone unnoticed.
        #expect(AssistedAssessment.decision(
            currentStatus: .good, current: clean(), history: [clean()]
        ).asksTheLearner == false)
        #expect(AssistedAssessment.decision(
            currentStatus: .good, current: mismatch(), history: [clean()]
        ).asksTheLearner)
    }

    @Test("A card the learner keeps getting wrong is simply asked about")
    func steadilyNegativeHistoryAsks() {
        // The stable negative history the roadmap lists. Nothing dramatic
        // happens — a rated history breaks the run, so the learner is asked,
        // and no suggestion appears. What must **not** happen is a downgrade
        // proposal.
        let history = [manual(.again), manual(.again), manual(.hard)]
        #expect(AssistedAssessment.decision(
            currentStatus: .weak, current: clean(), history: history
        ) == .ask(suggestion: nil))
    }

    @Test("A run is only counted from reviews that carry information")
    func unusableReviewsAreSkippedNotCounted() {
        // The definition the app cannot produce today — every stored entry has
        // an assessment or a speech attempt — kept deliberately: „no
        // information" is not the same as „a break in the run". Pinned so the
        // choice is visible if a later phase ever writes such an entry.
        let empty = ReviewSignal(direction: .germanToChinese, previousStatus: .good)
        #expect(empty.isUsable == false)
        #expect(clean().isUsable)
        #expect(mismatch().isUsable)
        #expect(manual(.again).isUsable)

        // Skipped, not counted as a success: the run is current + the one
        // clean entry behind the empty one, which is exactly two.
        #expect(AssistedAssessment.decision(
            currentStatus: .good, current: clean(), history: [empty, clean(assessment: .good)]
        ) == .autoAdvance)
        // And not counted as a run of its own either.
        #expect(AssistedAssessment.decision(
            currentStatus: .good, current: clean(), history: [empty, empty, empty]
        ) == .ask(suggestion: nil))
    }

    @Test("The highlight rule is the one the bar uses")
    func highlightRule() {
        // Pulled out of the view so it cannot be deleted with the suite
        // staying green — the phase-7 audit's lesson about conditions that
        // live only inside a `body`.
        #expect(SelfAssessmentBar.isSuggested(.good, suggestion: .good))
        #expect(SelfAssessmentBar.isSuggested(.again, suggestion: .good) == false)
        #expect(SelfAssessment.allCases.allSatisfy {
            SelfAssessmentBar.isSuggested($0, suggestion: nil) == false
        }, "no suggestion means no highlight anywhere")
    }
}
