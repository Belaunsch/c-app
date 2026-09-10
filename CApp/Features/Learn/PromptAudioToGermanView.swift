//
//  PromptAudioToGermanView.swift
//  CApp
//

import SwiftUI

/// Mode B: the Chinese is heard, the learner works out what it means.
///
/// ## Three steps, and why the middle one exists
///
/// - **Audio only.** A speaker and nothing else. Not the Hanzi, not the
///   Pinyin, not the German — a listening exercise that shows the writing is
///   not a listening exercise.
/// - **Hanzi shown.** The writing appears; Pinyin and meaning stay covered.
///   This is the step that makes the mode teachable rather than
///   pass-or-fail: hearing `shuǐguǒ` and not placing it, then seeing `水果`
///   and placing it immediately, is a different kind of not-knowing than
///   having no idea at all, and the learner gets to tell the two apart
///   before rating themselves.
/// - **Revealed.** Everything, and only now can the card be rated. That last
///   state is `LearnRevealedAnswerView`, shared with mode A — the device test
///   found this arrangement the clearer of the two, so both modes end here.
///
/// The rules for what is visible when live in `AudioPrompt`, not in this
/// `body`: a `body` cannot be reached from a test, and the promise that the
/// middle step does **not** leak the meaning is the one thing about this mode
/// worth guarding.
///
/// ## No autoplay, ever
///
/// Nothing here starts sound on its own. The learner decides when to listen
/// and how often (task 8.3) — a card that talks the moment it appears takes
/// the timing away from the person practising, and would talk in a quiet room
/// without being asked.
///
/// The speaker is the phase-7 one, unchanged: it gets the card's **Hanzi**,
/// never its Pinyin (A31), and the replacement-not-queue behaviour of
/// `SpeechSynthesisService` means a second tap restarts rather than stacking
/// up.
struct PromptAudioToGermanView: View {
    let card: Card
    let stage: PromptStage

    /// A `switch` over the stage, not a boolean.
    ///
    /// The branch decides whether `LearnRevealedAnswerView` — the view that
    /// contains the German meaning — is on screen, which makes it the place
    /// where this mode's promise is actually kept. Written as
    /// `if AudioPrompt.someRule(at: stage)` it took a predicate, and swapping
    /// in a similar-sounding one (`showsHanzi` for `allowsAssessment`, say)
    /// would put the meaning into the middle step with every test still
    /// green. A `switch` has nothing to swap: each stage names its layout,
    /// and a stage added later stops compiling until someone decides where
    /// it belongs.
    var body: some View {
        switch stage {
        case .audioOnly, .hanziShown:
            covered
        case .revealed:
            LearnRevealedAnswerView(card: card)
        }
    }

    /// The two steps before the answer.
    ///
    /// **No German and no Pinyin anywhere in here** — that is what keeps the
    /// middle step a listening exercise, and it is a property of this stack
    /// rather than of a condition somebody could flip.
    ///
    /// Same container as `LearnRevealedAnswerView`: same spacing, same width,
    /// same top padding, so the Hanzi appears at the size and position it
    /// will keep. The whole block still moves up as the answer adds lines,
    /// because the session centres its content — that was true before phase 8
    /// as well and is what the device test signed off.
    private var covered: some View {
        VStack(spacing: 20) {
            LearnPromptSpeaker(card: card)

            if AudioPrompt.showsHanzi(at: stage) {
                Text(LearnAnswer.hanzi(for: card))
                    .font(.system(size: 44, weight: .medium))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}
