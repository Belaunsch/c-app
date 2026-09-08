//
//  PromptGermanToChineseView.swift
//  CApp
//

import SwiftUI

/// One card in mode A: German first, the Chinese answer only after the user
/// asked for it.
///
/// Before revealing, neither Hanzi nor Pinyin is on screen — the point of the
/// mode is that the learner produces the answer themselves. Afterwards the
/// German stays: it is the reference the answer belongs to, and having it
/// vanish makes checking harder.
///
/// No sound, in either direction. The prompt asks the learner to say the
/// answer out loud, and nothing listens — speaking it is for their own ear.
/// Playback comes in phase 7, recognition in phase 9.
struct PromptGermanToChineseView: View {
    let card: Card
    let isRevealed: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Text(card.german)
                    .font(isRevealed ? .title3 : .largeTitle)
                    .fontWeight(isRevealed ? .regular : .semibold)
                    .foregroundStyle(isRevealed ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .animation(.default, value: isRevealed)

                if isRevealed {
                    answer
                } else {
                    Text("Sprich die chinesische Antwort laut aus.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
    }

    /// Hanzi carries the weight, the Pinyin sits directly beneath it so the
    /// two read as one answer.
    ///
    /// Both come from the card as stored. Nothing is generated here: a Pinyin
    /// the user corrected by hand is what they want to learn, so the learning
    /// mode never asks `PinyinService` again.
    private var answer: some View {
        VStack(spacing: 6) {
            Text(LearnAnswer.hanzi(for: card))
                .font(.system(size: 44, weight: .medium))
                .multilineTextAlignment(.center)

            let pinyin = LearnAnswer.pinyin(for: card)
            if pinyin.isEmpty == false {
                Text(pinyin)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(LearnAnswer.accessibilityLabel(for: card))
    }
}
