//
//  AppTabTests.swift
//  CAppTests
//

import Testing
import UIKit
@testable import CApp

struct AppTabTests {

    @Test("Die Bottom Navigation hat genau die Tabs Lernen und Karten")
    func bottomNavigationHasExactlyLearnAndCards() {
        #expect(AppTab.allCases == [.learn, .cards])
    }

    @Test("Die Tab-Titel sind auf Deutsch")
    func tabTitlesAreGerman() {
        #expect(AppTab.learn.title == "Lernen")
        #expect(AppTab.cards.title == "Karten")
    }

    @Test("Jeder Tab verweist auf ein existierendes SF Symbol")
    func everyTabUsesAnExistingSystemImage() {
        for tab in AppTab.allCases {
            #expect(
                UIImage(systemName: tab.systemImage) != nil,
                "Unbekanntes SF Symbol: \(tab.systemImage)"
            )
        }
    }
}
