//
//  CardDisplay.swift
//  CApp
//

import SwiftUI

// User-facing names live here rather than on the models, so `Models/` stays
// free of presentation concerns. The strings are German because every
// user-facing text in this app is.

extension CardType {
    var title: String {
        switch self {
        case .word: "Wörter"
        case .sentence: "Sätze"
        }
    }

    /// Singular, for the editor and for empty states.
    var singularTitle: String {
        switch self {
        case .word: "Wort"
        case .sentence: "Satz"
        }
    }
}

extension LearningStatus {
    var title: String {
        switch self {
        case .new: "Neu"
        case .weak: "Schwach"
        case .medium: "Mittel"
        case .good: "Gut"
        case .secure: "Sicher"
        }
    }

    /// Discreet colour coding for the list. Deliberately just a small dot —
    /// the learning status should be readable at a glance without turning the
    /// list into a traffic light.
    var indicatorColor: Color {
        switch self {
        case .new: .secondary
        case .weak: .red
        case .medium: .orange
        case .good: .blue
        case .secure: .green
        }
    }
}
