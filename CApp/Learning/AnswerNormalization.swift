//
//  AnswerNormalization.swift
//  CApp
//

import Foundation

/// Strips a text down to what a comparison should care about.
///
/// Used from phase 6 onwards to compare a typed or spoken answer against the
/// card. Written here because it is pure and testable, and because getting it
/// wrong quietly produces false mismatches.
///
/// **Structural only.** Whitespace and punctuation go, including the Chinese
/// forms — `你好！` and `你好` compare equal, and so do `我 想 吃 点 东西。`
/// and `我想吃点东西`. Nothing else: no case folding, no simplified/
/// traditional conversion, no synonyms, no Pinyin, no similarity measure.
/// Those would each be a product decision of their own.
///
/// One measured boundary: `Character.isPunctuation` covers every Chinese
/// punctuation mark tested — `。，、；：？！""''（）《》【】…—`, the fullwidth
/// forms `｡､﹖` and the middle dot `·` — but **not** the fullwidth tilde `～`
/// (U+FF5E), which Unicode classifies as a math symbol. It therefore
/// survives normalisation. Left as measured rather than special-cased: this
/// is structural normalisation, and stripping symbols in general would also
/// remove currency signs from an answer. Worth revisiting when the speech
/// comparison in phase 9 shows whether it matters.
nonisolated enum AnswerNormalization {

    static func normalized(_ text: String) -> String {
        String(text.unicodeScalars.filter { scalar in
            let character = Character(scalar)
            return character.isWhitespace == false && character.isPunctuation == false
        })
    }

    /// Whether two answers are the same once normalised.
    static func matches(_ lhs: String, _ rhs: String) -> Bool {
        normalized(lhs) == normalized(rhs)
    }
}
