//
//  ChineseText.swift
//  CApp
//

import Foundation

/// Chinese text, marked as Chinese.
///
/// VoiceOver picks its voice from the language of a run of text, and an
/// unmarked run is read in the UI language. German speech synthesis handed
/// `苹果` produces either silence or an invented pronunciation — which is
/// worse than silence, because it sounds like an answer.
///
/// Here rather than in a feature folder because three places need it: the
/// card list, the revealed answer and mode B's middle step. The identifier is
/// a single constant for the same reason the recognition validates
/// `zh`/`Hans`/`CN` — the app should mean exactly one thing by "Chinese".
///
/// **Pinyin is deliberately not marked.** A Mandarin voice reading `píngguǒ`
/// spells the tone marks out as diacritics instead of saying the syllables,
/// so the Latin transcription stays in the UI language where it belongs.
nonisolated enum ChineseText {
    /// Simplified, Mainland — the same variant the app writes, speaks and
    /// recognises.
    static let languageIdentifier = "zh-Hans-CN"

    /// `text` as an `AttributedString` that VoiceOver reads in Chinese.
    ///
    /// Purely an accessibility and layout attribute: nothing about the
    /// visible glyphs changes.
    static func spoken(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.languageIdentifier = languageIdentifier
        return attributed
    }
}
