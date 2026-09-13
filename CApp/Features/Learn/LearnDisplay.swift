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

extension SpeechCheck {
    /// What a match is allowed to say — and the whole sentence is the point.
    ///
    /// It used to read „Antwort wahrscheinlich korrekt". The phase-9 benchmark
    /// took that claim apart: over the first positive pass the transcriber
    /// produced a different Chinese text in 8 of 16 normally spoken target
    /// answers. A wording that says the *answer* was probably right therefore
    /// promised something the measurement does not support — it would have
    /// been a statement about the learner, made on evidence about a
    /// transcriber.
    ///
    /// „Erkannt wie erwartet" says exactly what happened and nothing more:
    /// Apple's final text, normalised, equals the stored Hanzi. It claims
    /// nothing about pronunciation, nothing about tones, nothing about
    /// linguistic correctness and nothing about what the learner knows.
    static let matchTitle = "Erkannt wie erwartet"

    /// The two labels of the mismatch view. Here rather than in the view so
    /// the forbidden-wording test can actually reach every visible string.
    static let recognizedLabel = "Erkannt"
    static let expectedLabel = "Erwartet"
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

    /// The same label, with the Chinese marked as Chinese.
    ///
    /// Without this VoiceOver reads `苹果` with the German voice, because the
    /// surrounding label is German — the characters come out as a stream of
    /// mispronounced syllables or nothing at all. Marking only the Hanzi run
    /// with `languageIdentifier` lets the system switch voices mid-sentence
    /// and read „Antwort" in German and the characters in Mandarin.
    ///
    /// The Pinyin stays unmarked: it is Latin script and a *reading aid*, and
    /// forcing it through a Mandarin voice would have VoiceOver spell out
    /// tone marks. Marking it German is equally wrong, so it is left alone —
    /// the system's own heuristic does better than either choice.
    ///
    /// `zh-Hans-CN`, the same locale the recognition validates against, so
    /// the whole app means one thing by "Chinese".
    static func accessibilityAttributedLabel(for card: Card) -> AttributedString {
        var label = AttributedString("Antwort: ")

        label.append(ChineseText.spoken(hanzi(for: card)))

        let pinyin = pinyin(for: card)
        if pinyin.isEmpty == false {
            label.append(AttributedString(", \(pinyin)"))
        }
        return label
    }

}
