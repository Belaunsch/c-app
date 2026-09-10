//
//  PromptGermanToChineseView.swift
//  CApp
//

import SwiftUI

/// One card in mode A: German first, the Chinese answer only after the user
/// asked for it.
///
/// Before revealing, neither Hanzi nor Pinyin is on screen — the point of the
/// mode is that the learner produces the answer themselves. Nothing listens,
/// and nothing plays: sound before the reveal would hand over the answer, and
/// recognition is phase 9.
///
/// **The revealed state is `LearnRevealedAnswerView`, shared with mode B.**
/// Until phase 8 this view had its own arrangement — the German shrank and
/// stayed at the top, the answer appeared beneath it, and the speaker was a
/// small icon at the bottom. The device test of mode B found the other
/// arrangement clearer: a large speaker first, then Hanzi, Pinyin and the
/// meaning. Both modes show those same four things once everything is
/// uncovered, so they now show them through the same view rather than
/// through two that agree today.
///
/// The German therefore moves from the top of the screen to the bottom on
/// reveal. It is still there — it is the reference the answer belongs to and
/// having it vanish makes checking harder — but it is now the last line
/// rather than a shrunken headline.
struct PromptGermanToChineseView: View {
    let card: Card
    let isRevealed: Bool

    var body: some View {
        if isRevealed {
            LearnRevealedAnswerView(card: card)
        } else {
            question
        }
    }

    /// Unchanged: the German prominent and centred, with the instruction to
    /// say the answer out loud, and nothing of the Chinese anywhere.
    ///
    /// The font no longer switches on `isRevealed`, and neither does the
    /// animation that used to soften that switch — there is nothing left to
    /// switch, because revealing now replaces the whole layout instead of
    /// resizing this text.
    private var question: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Text(card.german)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("Sprich die chinesische Antwort laut aus.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
    }
}
