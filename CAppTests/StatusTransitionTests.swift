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

    // §10, test 17
    @Test("A second assessment in the same batch leaves the status alone")
    func onlyTheFirstAssessmentChangesTheStatus() {
        // The rule from §6.1, and the reason for it: without it "Nochmal"
        // followed by a later "Gut" would leave a card better rated than
        // before, although the learner did not know it at first.
        let card = UUID()
        var queue = SessionQueue(cardIDs: [card])

        let first = queue.assess(.again, currentStatus: .weak)
        #expect(first?.wasFirstAssessmentInBatch == true)
        #expect(first?.newStatus == .weak, "the first attempt is the indicator")

        // The case the rule exists for: knowing it later in the same batch
        // must not lift the card above what the first attempt showed. With
        // `maxReinserts` at 1 since phase 6, this repetition is the last one
        // the batch grants.
        let second = queue.assess(.good, currentStatus: .weak)
        #expect(second?.wasFirstAssessmentInBatch == false)
        #expect(second?.newStatus == nil, "a later Gut must not improve the status")
        #expect(second?.isResolved == true)

        // The counters do keep going, though (§7) — that is the difference
        // between "no status change" and "did not happen".
        #expect(first?.countsAsCorrect == false, "Nochmal is not correct")
        #expect(second?.countsAsCorrect == true, "the later Gut still counts as a review hit")
    }
}
