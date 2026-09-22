//
//  SystemSymbolTests.swift
//  CAppTests
//

import Testing
import UIKit
@testable import CApp

/// Every SF Symbol the app names actually exists.
///
/// A symbol name that does not resolve fails **silently**: SwiftUI renders
/// nothing and the console prints "No symbol named … found in system symbol
/// set" — which nobody reads unless they happen to be attached to a device.
/// That is exactly how `rectangle.stack.badge.questionmark` survived from
/// phase 6 to phase 9 in two empty states.
///
/// The literal list is maintained by hand, because reading it out of the
/// source at runtime would need the source. That is a real weakness — the
/// audit found it one name behind — so everything that *can* be enumerated is
/// enumerated instead: `computedSymbolsExist` walks every recording phase and
/// every sort order through the functions that produce their names, and those
/// two cannot fall behind.
@MainActor
struct SystemSymbolTests {

    static let usedSymbols = [
        // Phase 14: über die Konstante, nicht als zweites Literal — so kann ein
        // Tippfehler nicht an einer Aufrufstelle überleben, während die Liste
        // richtig bleibt.
        CardExplanationEntry.symbolName,
        // Cards
        "rectangle.stack.badge.plus", "rectangle.stack", "magnifyingglass",
        "tag", "plus", "pencil", "line.3.horizontal.decrease.circle",
        "line.3.horizontal.decrease.circle.fill", "arrow.up.arrow.down",
        "arrow.up", "arrow.down", "clock", "clock.arrow.circlepath",
        "list.bullet.indent", "gearshape", "arrow.clockwise", "graduationcap",
        // Speech
        "speaker.wave.2", "speaker.slash", "mic", "mic.slash",
        "stop.circle", "hourglass", "checkmark.circle", "checkmark",
        // Errors and empty states
        "exclamationmark.circle", "exclamationmark.triangle",
    ]

    @Test("Every named system symbol resolves")
    func everySymbolExists() {
        for name in Self.usedSymbols {
            #expect(
                UIImage(systemName: name) != nil,
                "No symbol named \(name.debugDescription) — it would render as nothing"
            )
        }
    }

    /// The names that are **not** written at a call site but computed.
    ///
    /// These matter more than the list above, not less: a hand-kept list
    /// drifts, but asking the producing function for every case cannot. Both
    /// enumerations are exhaustive over their type, so a new phase or a new
    /// sort order is checked the day it is added, without anyone remembering
    /// to come back here.
    @Test("Every computed symbol name resolves too")
    func computedSymbolsExist() {
        for phase in SpeechRecognitionService.Phase.allCases {
            let name = RecordAnswerButton.symbol(for: phase)
            #expect(UIImage(systemName: name) != nil,
                    "phase \(phase): no symbol named \(name.debugDescription)")
        }
        for order in CardSortOrder.allCases {
            #expect(UIImage(systemName: order.symbolName) != nil,
                    "sort order \(order): no symbol named \(order.symbolName.debugDescription)")
        }
    }

    @Test("The name phase 9 tripped over still does not exist")
    func theBrokenNameIsStillNotASymbol() {
        // **What this does not do:** it cannot stop anyone from writing the
        // name again — a test bundle has no access to the source. It checks
        // Apple's symbol set, not this app, and the earlier comment here
        // claimed otherwise. What it is good for is the day Apple adds the
        // symbol: this goes red, and the note in the roadmap that calls the
        // name non-existent becomes stale and has to be rewritten.
        //
        // `rectangle.stack.badge.questionmark` sat in `LearnSessionView`'s
        // empty state from phase 6 until phase 10 and rendered nothing.
        #expect(UIImage(systemName: "rectangle.stack.badge.questionmark") == nil)
    }
}
