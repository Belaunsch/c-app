//
//  CardFilterSelectionTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// The state behind the filter button. Only the questions the toolbar asks —
/// the filter semantics themselves are `CardFilter`'s and tested there.
struct CardFilterSelectionTests {

    @Test("A fresh selection filters nothing")
    func emptySelectionIsNotFiltering() {
        let selection = CardFilterSelection()
        #expect(selection.hasActiveFilters == false)
        #expect(selection.activeGroupCount == 0)
    }

    @Test("A status alone counts as filtering")
    func statusCountsAsFiltering() {
        var selection = CardFilterSelection()
        selection.status = .weak
        #expect(selection.hasActiveFilters)
        #expect(selection.activeGroupCount == 1)
    }

    @Test("Categories alone count as filtering")
    func categoriesCountAsFiltering() {
        var selection = CardFilterSelection()
        selection.toggle(tagKey: "essen")
        #expect(selection.hasActiveFilters)
        #expect(selection.activeGroupCount == 1)
    }

    @Test("The count is of groups, not of chosen categories")
    func countIsPerGroup() {
        // Three categories are still one filter group. The number answers
        // "how much of the list is hidden", not "how many boxes are ticked".
        var selection = CardFilterSelection()
        selection.toggle(tagKey: "essen")
        selection.toggle(tagKey: "reisen")
        selection.toggle(tagKey: "arbeit")
        #expect(selection.activeGroupCount == 1)

        selection.status = .new
        #expect(selection.activeGroupCount == 2)
    }

    @Test("Toggling a category twice takes it back")
    func toggleIsReversible() {
        var selection = CardFilterSelection()
        selection.toggle(tagKey: "essen")
        #expect(selection.tagKeys == ["essen"])

        selection.toggle(tagKey: "essen")
        #expect(selection.tagKeys.isEmpty)
        #expect(selection.hasActiveFilters == false)
    }

    @Test("Resetting clears both groups")
    func resetClearsEverything() {
        var selection = CardFilterSelection()
        selection.status = .secure
        selection.toggle(tagKey: "essen")
        selection.toggle(tagKey: "reisen")

        selection.reset()

        #expect(selection.status == nil)
        #expect(selection.tagKeys.isEmpty)
        #expect(selection.hasActiveFilters == false)
        #expect(selection == CardFilterSelection(), "same as never having filtered")
    }
}
