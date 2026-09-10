//
//  LearnRevealedAnswerView.swift
//  CApp
//

import SwiftUI

/// The fully revealed card, identical in both directions.
///
/// Mode A and mode B ask different questions and take different routes, but
/// once everything is uncovered they show the **same four things**: the
/// speaker, the Hanzi, the Pinyin and the German. The device test found the
/// mode-B arrangement clearer, so it is the one both use — and they use it by
/// sharing this view rather than by two files agreeing to look alike, which
/// is the arrangement that drifts apart on the third change.
///
/// Deliberately **only** the revealed state. The steps before it stay
/// separate, because they are genuinely different: mode A shows the German
/// and asks the learner to say the Chinese, mode B plays sound and optionally
/// shows the writing. A view that covered those too would need a parameter
/// per difference and would stop being a shared layout.
///
/// Presentation only. Nothing here decides anything — which card, which
/// stage and what happens next all stay where they were.
struct LearnRevealedAnswerView: View {
    let card: Card

    var body: some View {
        VStack(spacing: 20) {
            LearnPromptSpeaker(card: card)

            // Hanzi and Pinyin are one announcement for VoiceOver even though
            // they are two views: they are one answer, and read separately
            // the Pinyin arrives as an unexplained second item. The Pinyin is
            // hidden rather than folded into a nested stack, because nesting
            // would change the spacing and this layout has to stay exactly
            // what the device test approved.
            Text(LearnAnswer.hanzi(for: card))
                .font(.system(size: 44, weight: .medium))
                .multilineTextAlignment(.center)
                .accessibilityLabel(LearnAnswer.accessibilityLabel(for: card))

            let pinyin = LearnAnswer.pinyin(for: card)
            if pinyin.isEmpty == false {
                Text(pinyin)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityHidden(true)
            }

            Text(card.german)
                .font(.title2)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Bedeutung: \(card.german)")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

/// The large speaker at the top of a learning prompt.
///
/// Shared for the same reason as the layout around it: mode B shows it from
/// the first moment, mode A only once the answer is out, and both must show
/// the *same* control at the same size. It is the phase-7 `SpeakButton`
/// underneath — same voice, same rate, same replace-instead-of-queue — only
/// sized for this job.
///
/// When the card cannot be spoken, this says so instead of leaving a gap.
/// That matters most in mode B, where the audio is the question, and it uses
/// the wording phase 7 already owns rather than inventing a second
/// explanation or a download.
struct LearnPromptSpeaker: View {
    let card: Card

    @Environment(SpeechSynthesisService.self) private var speech

    var body: some View {
        // The same question `SpeakButton` asks itself, so the two cannot
        // disagree and leave an empty space: a voice can be installed while
        // *this* card has nothing speakable, which a mid-session edit in the
        // cards tab can produce. `SpeakButton` carries its own label.
        if SpeakButton.isVisible(isAvailable: speech.isAvailable, hanzi: LearnAnswer.hanzi(for: card)) {
            SpeakButton(hanzi: LearnAnswer.hanzi(for: card))
                .font(.system(size: 64))
                .foregroundStyle(.tint)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "speaker.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)

                Text(MissingVoiceNotice.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
