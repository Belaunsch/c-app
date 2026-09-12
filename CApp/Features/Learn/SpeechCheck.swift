//
//  SpeechCheck.swift
//  CApp
//

import Foundation

/// What came of comparing a spoken answer with the card.
///
/// ## Two outcomes, and deliberately no third
///
/// There is no score, no percentage, no confidence and no partial credit —
/// not because they would be hard, but because they would be a lie. The chain
/// is: spoken Mandarin → Apple's recognition → recognised Hanzi →
/// normalisation → comparison with the stored Hanzi. **Nothing in that chain
/// measures pronunciation.** A recogniser with a good language model guesses
/// the right sentence out of poor pronunciation all day long, so a match says
/// the recognised *text* probably matches the target text, and nothing about
/// how it was said. That is hard rule 7 in `CLAUDE.md` and it is the reason
/// this type has exactly two cases.
///
/// The self-assessment stays the judgement. A `SpeechCheck` never changes a
/// learning status — it is shown next to the revealed answer and the learner
/// still decides between Nochmal, Schwer, Gut and Sicher.
///
/// Free of Speech-framework types on purpose: by the time a value of this
/// type exists, the recognition is over and what is left is two strings.
nonisolated enum SpeechCheck: Equatable {

    /// The normalised texts are the same.
    case match(recognized: String)

    /// They differ. Both are carried so the view can show them side by side
    /// without deciding which is "right" — the expected text is what the card
    /// stores, and the card can be wrong too.
    case mismatch(recognized: String, expected: String)

    /// The only way to make one.
    ///
    /// Uses `AnswerNormalization` from the learning layer unchanged — the
    /// same structural rule the rest of the app compares with: whitespace and
    /// punctuation go, including the Chinese forms, and nothing else. No
    /// similarity measure, no Levenshtein, no synonyms, no Pinyin, no
    /// Simplified/Traditional conversion. Each of those is a product decision
    /// nobody has made, and one of them — converting scripts — would quietly
    /// undo the locale validation that keeps Traditional output away in the
    /// first place.
    static func compare(recognized: String, expected: String) -> SpeechCheck {
        AnswerNormalization.matches(recognized, expected)
            ? .match(recognized: recognized)
            : .mismatch(recognized: recognized, expected: expected)
    }

    /// Whether this is a match. A convenience for the view, and a name for
    /// the thing tests assert on.
    var isMatch: Bool {
        if case .match = self { return true }
        return false
    }
}
