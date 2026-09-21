//
//  StatusTransitionTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// `docs/learning-engine.md` §10, mandatory tests 15 to 17.
struct StatusTransitionTests {

    // §10, test 15
    @Test("All twenty cells of the transition matrix")
    func fullTransitionMatrix() {
        // Written out as the table from §6, cell by cell, rather than derived
        // from the same formula the implementation uses — a test that
        // recomputes `clamp(level + delta)` would agree with any off-by-one
        // in it.
        let matrix: [(LearningStatus, SelfAssessment, LearningStatus)] = [
            (.new, .again, .weak), (.new, .hard, .weak), (.new, .good, .medium), (.new, .secure, .good),
            (.weak, .again, .weak), (.weak, .hard, .weak), (.weak, .good, .medium), (.weak, .secure, .good),
            (.medium, .again, .weak), (.medium, .hard, .weak), (.medium, .good, .good), (.medium, .secure, .secure),
            (.good, .again, .weak), (.good, .hard, .medium), (.good, .good, .secure), (.good, .secure, .secure),
            (.secure, .again, .medium), (.secure, .hard, .good), (.secure, .good, .secure), (.secure, .secure, .secure),
        ]

        #expect(matrix.count == 20, "five statuses times four answers")
        for (from, assessment, expected) in matrix {
            #expect(
                StatusTransition.newStatus(from: from, for: assessment) == expected,
                "\(from) + \(assessment) should be \(expected)"
            )
        }
    }

    // §10, test 16
    @Test("The ladder never goes below weak or above secure")
    func boundsHold() {
        for status in LearningStatus.allCases {
            for assessment in SelfAssessment.allCases {
                let result = StatusTransition.newStatus(from: status, for: assessment)
                #expect(result >= .weak, "\(status) + \(assessment) fell below weak")
                #expect(result <= .secure, "\(status) + \(assessment) rose above secure")
                #expect(result != .new, "new is a starting state, never a destination")
            }
        }

        // The two ends specifically, since that is where a clamp fails.
        #expect(StatusTransition.newStatus(from: .weak, for: .again) == .weak)
        #expect(StatusTransition.newStatus(from: .new, for: .again) == .weak, "new enters as weak")
        #expect(StatusTransition.newStatus(from: .secure, for: .secure) == .secure)

        // And the deliberate asymmetry from §6: one slip on a secure card
        // costs two rungs, not everything.
        #expect(StatusTransition.newStatus(from: .secure, for: .again) == .medium)
        #expect(
            StatusTransition.newStatus(
                from: StatusTransition.newStatus(from: .secure, for: .again),
                for: .again
            ) == .weak,
            "two slips in a row do reach weak"
        )
    }

    // §10, test 17 — rewritten for phase 13.
    @Test("A card cannot change status twice in one mini-batch")
    func onlyOneStatusChangePerBatch() {
        // §6.1 used to be enforced by a counter in the queue: only the first
        // assessment of a card produced a new status. Phase 13 took the
        // assessments out of the flow, and the rule now holds **structurally** —
        // which is exactly why it needs a test rather than a comment.
        //
        // The chain: a status only moves when the learner confirms a proposal;
        // a proposal needs a clean attempt; a clean attempt is never a retry;
        // and the only way a card comes back inside one batch is a give-up,
        // which makes the next attempt a retry. So the second appearance can
        // never carry a proposal.
        let secondAppearance = ReviewSignal(
            direction: .germanToChinese,
            previousStatus: .medium,
            usedSpeech: true,
            speechMatched: true,
            wasRetry: true
        )
        let plentyOfCleanHistory = Array(
            repeating: ReviewSignal(
                direction: .germanToChinese,
                previousStatus: .medium,
                usedSpeech: true,
                speechMatched: true
            ),
            count: 5
        )

        #expect(
            AssistedAssessment.decision(
                currentStatus: .medium,
                current: secondAppearance,
                history: plentyOfCleanHistory
            ) == .continueOnly,
            "a repeat attempt must never be offered a promotion, however clean the history"
        )

        // And the give-up that produced the repeat is not positive evidence
        // either — the other half of the same chain.
        let gaveUp = ReviewSignal(
            direction: .germanToChinese,
            previousStatus: .medium,
            wasManualReveal: true
        )
        #expect(
            AssistedAssessment.decision(
                currentStatus: .medium,
                current: gaveUp,
                history: plentyOfCleanHistory
            ) == .continueOnly
        )
    }
}
