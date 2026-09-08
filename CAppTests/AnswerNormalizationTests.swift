//
//  AnswerNormalizationTests.swift
//  CAppTests
//

import Foundation
import Testing
@testable import CApp

/// Task 5.6. Not among the numbered tests of §10, but the roadmap asks for
/// the function now because it is pure and testable — and because a wrong
/// normalisation quietly produces false mismatches later.
struct AnswerNormalizationTests {

    @Test("Chinese punctuation is removed")
    func chinesePunctuationIsRemoved() {
        // The two examples from the specification.
        #expect(AnswerNormalization.matches("你好！", "你好"))
        #expect(AnswerNormalization.matches("我 想 吃 点 东西。", "我想吃点东西"))

        // Measured: `Character.isPunctuation` covers all of these.
        for mark in ["。", "，", "、", "；", "：", "？", "！", "“", "”", "‘", "’",
                     "（", "）", "《", "》", "【", "】", "…", "—", "·", "｡", "､", "﹖"] {
            #expect(AnswerNormalization.normalized("你好\(mark)") == "你好", "\(mark) should be removed")
        }
    }

    @Test("Latin punctuation and whitespace are removed")
    func latinPunctuationIsRemoved() {
        #expect(AnswerNormalization.matches("Hallo, Welt!", "HalloWelt"))
        #expect(AnswerNormalization.matches("  你好  ", "你好"))
        #expect(AnswerNormalization.matches("你\t好\n", "你好"))
        // The ideographic space, which is whitespace rather than punctuation.
        #expect(AnswerNormalization.normalized("我　想") == "我想")
    }

    @Test("Nothing but whitespace and punctuation is touched")
    func nothingElseIsChanged() {
        // No case folding, no script conversion, no synonyms — none of that
        // is specified, and each would be a product decision of its own.
        #expect(AnswerNormalization.normalized("Hallo") == "Hallo")
        #expect(AnswerNormalization.matches("hallo", "Hallo") == false, "no case folding")
        #expect(AnswerNormalization.normalized("苹果") == "苹果")
        #expect(AnswerNormalization.matches("苹果", "蘋果") == false, "no simplified/traditional conversion")
        #expect(AnswerNormalization.normalized("píngguǒ") == "píngguǒ", "tone marks survive")
        #expect(AnswerNormalization.normalized("123") == "123")
    }

    @Test("Known boundary: the fullwidth tilde survives")
    func fullwidthTildeIsNotPunctuation() {
        // Measured: U+FF5E is a math symbol in Unicode, not punctuation, so
        // it is not removed. Pinned rather than special-cased — this is
        // structural normalisation, and stripping symbols in general would
        // also take currency signs out of an answer. Revisit when the speech
        // comparison in phase 9 shows whether it matters.
        #expect(AnswerNormalization.normalized("你好～") == "你好～")
        #expect(AnswerNormalization.matches("你好～", "你好") == false)
    }

    @Test("An empty or punctuation-only text normalises to nothing")
    func emptyInput() {
        #expect(AnswerNormalization.normalized("") == "")
        #expect(AnswerNormalization.normalized("   ") == "")
        #expect(AnswerNormalization.normalized("。！？") == "")
        // Two empty answers matching is the caller's problem, not this
        // function's — it only says they are structurally equal.
        #expect(AnswerNormalization.matches("。", "！"))
    }
}
