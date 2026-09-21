//
//  AssistedAssessmentTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// The phase-13 classification rule: `docs/learning-engine.md` §13.7.
///
/// Pure values throughout — no store, no container, no clock. Every test here
/// states one of the rule's promises, and the ones that matter most are the
/// promises about what the rule may **not** conclude (§13.8).
struct AssistedAssessmentTests {

    // MARK: - Builders, so the tests read like the rule

    private func clean(
        at status: LearningStatus,
        direction: SessionDirection = .germanToChinese
    ) -> ReviewSignal {
        ReviewSignal(
            direction: direction,
            previousStatus: status,
            usedSpeech: true,
            speechMatched: true
        )
    }

    private func mismatch(at status: LearningStatus) -> ReviewSignal {
        ReviewSignal(
            direction: .germanToChinese,
            previousStatus: status,
            usedSpeech: true,
            speechMatched: false
        )
    }

    private func gaveUp(at status: LearningStatus) -> ReviewSignal {
        ReviewSignal(direction: .germanToChinese, previousStatus: status, wasManualReveal: true)
    }

    private func declined(_ proposal: LearningStatus, at status: LearningStatus) -> ReviewSignal {
        ReviewSignal(
            direction: .germanToChinese,
            previousStatus: status,
            usedSpeech: true,
            speechMatched: true,
            declinedSuggestion: proposal
        )
    }

    private func decision(
        at status: LearningStatus,
        current: ReviewSignal,
        history: [ReviewSignal] = []
    ) -> AssistedClassificationDecision {
        AssistedAssessment.decision(currentStatus: status, current: current, history: history)
    }

    // MARK: - The threshold

    @Test("A single exact match carries no statement")
    func singleMatchSuggestsNothing() {
        // The false-accept property of the comparison was never measured: the
        // phase-9 benchmark stopped after the positive pass, so how often a
        // match happens by accident is unknown. One match must therefore mean
        // nothing at all.
        #expect(decision(at: .medium, current: clean(at: .medium)) == .continueOnly)
    }

    @Test("Two clean attempts in a row offer exactly one step up")
    func twoCleanAttemptsProposeOneStep() {
        let result = decision(at: .medium, current: clean(at: .medium), history: [clean(at: .medium)])
        #expect(result == .propose(.good))
        #expect(result.proposedStatus == .good)
    }

    @Test("The threshold is the documented two, not one and not three")
    func thresholdIsTwo() {
        // Pinned against the constant *and* against its value, because the
        // counter-mutation that matters is „2 → 1".
        #expect(AssistedAssessment.cleanRunBeforeSuggestion == 2)

        let history = Array(repeating: clean(at: .medium), count: AssistedAssessment.cleanRunBeforeSuggestion - 2)
        #expect(
            decision(at: .medium, current: clean(at: .medium), history: history) == .continueOnly,
            "one short of the threshold"
        )
        #expect(
            decision(at: .medium, current: clean(at: .medium), history: history + [clean(at: .medium)])
                == .propose(.good),
            "exactly at the threshold"
        )
    }

    // MARK: - The ladder

    @Test("The suggestion ladder is the Gut column of §6 and nothing else")
    func suggestionLadder() {
        let expected: [LearningStatus: LearningStatus?] = [
            .new: .medium,
            .weak: .medium,
            .medium: .good,
            .good: .secure,
            .secure: nil,
        ]
        for (status, proposal) in expected {
            #expect(AssistedAssessment.proposedStatus(from: status) == proposal, "\(status)")
            #expect(
                decision(at: status, current: clean(at: status), history: [clean(at: status)])
                    == (proposal.map { AssistedClassificationDecision.propose($0) } ?? .continueOnly),
                "\(status)"
            )
        }
    }

    @Test("A secure card is never offered anything")
    func topOfTheLadderOffersNothing() {
        let history = Array(repeating: clean(at: .secure), count: 9)
        #expect(decision(at: .secure, current: clean(at: .secure), history: history) == .continueOnly)
    }

    @Test("A suggestion is never more than one step and never downwards")
    func neverMoreThanOneStepAndNeverDown() {
        for status in LearningStatus.allCases {
            let history = Array(repeating: clean(at: status), count: 9)
            guard let proposal = decision(at: status, current: clean(at: status), history: history).proposedStatus
            else { continue }

            #expect(proposal > status, "\(status): a suggestion may only point up")
            // One rung on the ladder of §6, measured through the ladder itself
            // rather than through a second table.
            #expect(
                proposal == StatusTransition.newStatus(from: status, for: .good),
                "\(status): more than one step"
            )
        }
    }

    // MARK: - What the rule may not conclude (§13.8)

    @Test("A mismatch suggests nothing, lowers nothing and ends the run")
    func mismatchIsNotNegativeEvidence() {
        // Of 16 normally spoken target answers, 8 came back as a different
        // Chinese text (phase 9). A mismatch is therefore not a statement about
        // the learner — it just ends the run.
        #expect(decision(at: .medium, current: mismatch(at: .medium), history: [clean(at: .medium)]) == .continueOnly)

        // And as history it breaks a run rather than contributing to one.
        #expect(
            decision(
                at: .medium,
                current: clean(at: .medium),
                history: [mismatch(at: .medium), clean(at: .medium), clean(at: .medium)]
            ) == .continueOnly,
            "the clean attempts behind the mismatch cannot be reached"
        )

        // There is no downgrade anywhere in the rule.
        for status in LearningStatus.allCases {
            let onlyMismatches = Array(repeating: mismatch(at: status), count: 9)
            let result = decision(at: status, current: mismatch(at: status), history: onlyMismatches)
            #expect(result == .continueOnly, "\(status)")
            #expect(result.proposedStatus == nil, "\(status): no proposal at all, least of all a lower one")
        }
    }

    @Test("A retry is no positive evidence")
    func retryCarriesNothing() {
        let retry = ReviewSignal(
            direction: .germanToChinese,
            previousStatus: .medium,
            usedSpeech: true,
            speechMatched: true,
            wasRetry: true
        )
        #expect(decision(at: .medium, current: retry, history: [clean(at: .medium)]) == .continueOnly)

        // As history it ends the run too — the first attempt is the honest
        // indicator, the same principle §6.1 rests on.
        #expect(
            decision(
                at: .medium,
                current: clean(at: .medium),
                history: [retry, clean(at: .medium), clean(at: .medium)]
            ) == .continueOnly
        )
    }

    @Test("Giving up is no positive evidence, and it breaks the run without speech")
    func givingUpCarriesNothing() {
        #expect(decision(at: .medium, current: gaveUp(at: .medium), history: [clean(at: .medium)]) == .continueOnly)

        // The phase-13 trap: a give-up in the new flow carries **neither** an
        // assessment **nor** speech. Phase 11's `isUsable` would have skipped it
        // as „no information" — and „match, gave up, match" would have produced
        // a suggestion. It has to break the run.
        #expect(
            decision(
                at: .medium,
                current: clean(at: .medium),
                history: [gaveUp(at: .medium), clean(at: .medium), clean(at: .medium)]
            ) == .continueOnly,
            "a give-up must break the run, not be skipped over"
        )
    }

    @Test("An attempt without speech at all suggests nothing")
    func withoutSpeechNothingHappens() {
        let silent = ReviewSignal(direction: .germanToChinese, previousStatus: .medium)
        #expect(decision(at: .medium, current: silent, history: [clean(at: .medium)]) == .continueOnly)
    }

    @Test("Mode B is status-neutral in both roles")
    func modeBIsStatusNeutral() {
        // As the current attempt: there is no speech in mode B, so there is
        // never a clean attempt and never a suggestion.
        let modeB = ReviewSignal(direction: .audioToGerman, previousStatus: .medium, wasManualReveal: true)
        let modeBHistory = Array(repeating: modeB, count: 9)
        #expect(decision(at: .medium, current: modeB, history: modeBHistory) == .continueOnly)

        // Even an (impossible) clean mode-B attempt gets nothing out of mode-A
        // history, because the run only counts the same direction.
        let cleanModeB = clean(at: .medium, direction: .audioToGerman)
        #expect(
            decision(at: .medium, current: cleanModeB, history: [clean(at: .medium)]) == .continueOnly,
            "mode-A evidence does not carry into mode B"
        )
    }

    @Test("An attempt in the other direction does not break the run")
    func otherDirectionIsSkippedNotCounted() {
        // Skipped, not counted as a break: practising mode B must not destroy
        // mode-A evidence — and it must not create any either.
        let modeB = ReviewSignal(direction: .audioToGerman, previousStatus: .medium, wasManualReveal: true)
        #expect(
            decision(
                at: .medium,
                current: clean(at: .medium),
                history: [modeB, modeB, clean(at: .medium)]
            ) == .propose(.good),
            "the mode-B reviews in between are simply not comparable"
        )

        // And they do not stand in for a clean attempt either.
        #expect(
            decision(at: .medium, current: clean(at: .medium), history: [modeB, modeB]) == .continueOnly,
            "skipping is not counting"
        )
    }

    // MARK: - The same-status rule (§13.7, rule 2)

    @Test("Only evidence gathered at the current status counts")
    func evidenceIsBoundToTheStatusItWasGatheredAt() {
        #expect(
            decision(
                at: .medium,
                current: clean(at: .medium),
                history: [clean(at: .weak), clean(at: .weak), clean(at: .weak)]
            ) == .continueOnly,
            "evidence from another status cannot count"
        )
    }

    @Test("A card reset to Neu by hand does not use its old evidence")
    func manualResetDiscardsOldEvidence() {
        // The phase-11 review found this hole, and phase 13 closes it at the
        // right place: the card's history is real, but all of it was recorded at
        // other statuses, so none of it is comparable. The reset is a statement,
        // and „die manuelle Bewertung hat Vorrang" covers that one too.
        let oldHistory = Array(repeating: clean(at: .good), count: 9)
        #expect(decision(at: .new, current: clean(at: .new), history: oldHistory) == .continueOnly)

        // What it does *not* do is lock `.new` out for good — two clean attempts
        // at `.new` earn the first suggestion (§13.7).
        #expect(
            decision(at: .new, current: clean(at: .new), history: [clean(at: .new)] + oldHistory)
                == .propose(.medium),
            "a genuinely new card can be classified for the first time"
        )
    }

    @Test("Accepting a suggestion does not chain into the next one")
    func noChainPromotion() {
        // After a confirmed Mittel → Gut the card sits at Gut, and the entries
        // that earned it carry `previousStatus == .medium`. They cannot count
        // towards Gut → Sicher, so the next step needs two fresh clean attempts.
        let earnedAtMedium = [clean(at: .medium), clean(at: .medium)]
        #expect(
            decision(at: .good, current: clean(at: .good), history: earnedAtMedium) == .continueOnly,
            "one promotion must not immediately unlock the next"
        )
        #expect(
            decision(at: .good, current: clean(at: .good), history: [clean(at: .good)] + earnedAtMedium)
                == .propose(.secure),
            "two fresh attempts at the new status do earn it"
        )
    }

    // MARK: - The decline (§13.7, rule 4)

    @Test("A decline resets the evidence for that step to zero")
    func declineResetsTheRun() {
        // The documented sequence: match, match → suggestion → declined, then
        // one match is not enough and the second one brings it back.
        let history1 = [declined(.good, at: .medium), clean(at: .medium)]
        #expect(
            decision(at: .medium, current: clean(at: .medium), history: history1) == .continueOnly,
            "one clean attempt after the decline is not enough"
        )

        let history2 = [clean(at: .medium), declined(.good, at: .medium), clean(at: .medium)]
        #expect(
            decision(at: .medium, current: clean(at: .medium), history: history2) == .propose(.good),
            "two clean attempts after the decline bring it back"
        )
    }

    @Test("The declining attempt does not count itself")
    func theDecliningAttemptDoesNotCount() {
        // The decline sits on a review that was itself a clean attempt. If it
        // counted, „decline → one match" would already be a run of two and the
        // suggestion would come straight back — which is precisely the „no" the
        // learner just gave, ignored.
        #expect(
            decision(at: .medium, current: clean(at: .medium), history: [declined(.good, at: .medium)])
                == .continueOnly
        )
    }

    @Test("A decline only resets the step that was declined")
    func declineIsScopedToItsStep() {
        // Recorded per suggested status, so a decline of one step does not mute a
        // different one. **Production data cannot reach this today** — a comparable
        // entry has the same `previousStatus`, and the proposal follows
        // deterministically from it, so a comparable decline always names the same
        // step. It is a guard for a later rule that proposes something else, and it
        // is why the field carries the status rather than a `Bool`.
        let declinedSomethingElse = ReviewSignal(
            direction: .germanToChinese,
            previousStatus: .medium,
            usedSpeech: true,
            speechMatched: true,
            declinedSuggestion: .secure
        )
        #expect(
            decision(at: .medium, current: clean(at: .medium), history: [declinedSomethingElse])
                == .propose(.good),
            "a decline of another step is still a clean attempt"
        )
    }

    // MARK: - The window

    @Test("The window bounds how much history is read")
    func windowBoundsTheRead() {
        #expect(AssistedAssessment.windowSize == 10)

        // With the threshold at two, capping a run of *comparable* attempts cannot
        // change a decision — what it bounds there is the work.
        let ancient = Array(repeating: clean(at: .medium), count: AssistedAssessment.windowSize * 3)
        #expect(decision(at: .medium, current: clean(at: .medium), history: ancient) == .propose(.good))

        // **But there is one case where the bound really decides**, and it is the
        // consequence the type's own documentation names: the window is applied to
        // the raw history, before the direction rule skips anything. A learner who
        // does a windowful of mode-B reviews hides their older mode-A evidence
        // behind it. Without the `prefix` this would be `.propose`.
        let modeB = ReviewSignal(direction: .audioToGerman, previousStatus: .medium, wasManualReveal: true)
        let buried = Array(repeating: modeB, count: AssistedAssessment.windowSize)
            + [clean(at: .medium), clean(at: .medium)]
        #expect(
            decision(at: .medium, current: clean(at: .medium), history: buried) == .continueOnly,
            "evidence pushed out of the window cannot count"
        )
        // The counter-probe: one mode-B review fewer and the same evidence is
        // reachable again, so what carries above is the bound and not the skipping.
        let justReachable = Array(repeating: modeB, count: AssistedAssessment.windowSize - 1)
            + [clean(at: .medium), clean(at: .medium)]
        #expect(decision(at: .medium, current: clean(at: .medium), history: justReachable) == .propose(.good))
    }

    // MARK: - The decision type

    @Test("continueOnly carries no status, propose carries exactly one")
    func decisionTypeIsUnambiguous() {
        #expect(AssistedClassificationDecision.continueOnly.proposedStatus == nil)
        #expect(AssistedClassificationDecision.propose(.good).proposedStatus == .good)
    }

    // MARK: - The clean attempt itself

    @Test("A clean attempt is all four conditions together")
    func cleanAttemptNeedsAllFourConditions() {
        #expect(clean(at: .medium).isCleanAutomaticSuccess)

        let variants: [(String, ReviewSignal)] = [
            ("no speech", ReviewSignal(direction: .germanToChinese, previousStatus: .medium)),
            ("mismatch", mismatch(at: .medium)),
            ("retry", ReviewSignal(
                direction: .germanToChinese, previousStatus: .medium,
                usedSpeech: true, speechMatched: true, wasRetry: true
            )),
            ("revealed first", ReviewSignal(
                direction: .germanToChinese, previousStatus: .medium,
                usedSpeech: true, speechMatched: true, wasManualReveal: true
            )),
        ]
        for (name, signal) in variants {
            #expect(signal.isCleanAutomaticSuccess == false, "\(name)")
        }
    }

    @Test("Comparability is direction and status together")
    func comparabilityNeedsBoth() {
        let signal = clean(at: .medium)
        #expect(signal.isComparable(inDirection: .germanToChinese, at: .medium))
        #expect(signal.isComparable(inDirection: .audioToGerman, at: .medium) == false, "direction half")
        #expect(signal.isComparable(inDirection: .germanToChinese, at: .good) == false, "status half")
    }
}
