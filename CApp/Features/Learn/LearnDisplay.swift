//
//  LearnDisplay.swift
//  CApp
//

import Foundation

// User-facing names for the learning layer's types. They live here rather
// than in `Learning/`, which holds no presentation concerns and no German
// text — the same split `CardDisplay` makes for the models.

extension SelfAssessment {
    /// The four buttons, in the order they are shown.
    ///
    /// `allCases` already has this order, but the bar depends on it, so it is
    /// stated where the titles are rather than left to the enum's
    /// declaration order.
    static var displayOrder: [SelfAssessment] { [.again, .hard, .good, .secure] }

    var title: String {
        switch self {
        case .again: "Nochmal"
        case .hard: "Schwer"
        case .good: "Gut"
        case .secure: "Sicher"
        }
    }

    /// Spoken by VoiceOver. The plain title would be ambiguous out of
    /// context — "Gut" alone does not say what it applies to.
    var accessibilityLabel: String {
        switch self {
        case .again: "Nochmal, nicht gewusst"
        case .hard: "Schwer, mit Mühe gewusst"
        case .good: "Gut gewusst"
        case .secure: "Sicher gewusst"
        }
    }
}

extension SessionDirection {
    /// Both halves named, with the arrow doing the explaining. "Modus A" and
    /// "Modus B" would be shorter and would tell the user nothing.
    var title: String {
        switch self {
        case .germanToChinese: "Deutsch → Chinesisch"
        case .audioToGerman: "Audio → Deutsch"
        }
    }

    /// Spoken by VoiceOver, where an arrow is not a word.
    var accessibilityLabel: String {
        switch self {
        case .germanToChinese: "Deutsch nach Chinesisch"
        case .audioToGerman: "Chinesisches Audio nach Deutsch"
        }
    }
}

/// What the reveal shows for one card.
///
/// A pure function so the rule can be tested: the learning mode shows the
/// card **as stored**. A Pinyin the user corrected by hand is what they want
/// to learn, so nothing here asks `PinyinService` again — and a test with a
/// hand-corrected value would catch it if someone did.
enum LearnAnswer {
    static func hanzi(for card: Card) -> String {
        card.hanzi
    }

    static func pinyin(for card: Card) -> String {
        card.pinyin
    }

    /// Spoken as one unit, because the two halves are one answer.
    static func accessibilityLabel(for card: Card) -> String {
        let pinyin = pinyin(for: card)
        return pinyin.isEmpty
            ? "Antwort: \(hanzi(for: card))"
            : "Antwort: \(hanzi(for: card)), \(pinyin)"
    }
}
