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
/// stage and what happens next all stay where they were. Since phase 13 what
/// hangs underneath is `RevealedDecisionBar`: *Weiter*, or „Neue Einstufung"
/// with *Ablehnen* and *Bestätigen*. The four self-assessments are gone from the
/// flow, and no status moves without a tap on *Bestätigen*.
struct LearnRevealedAnswerView: View {
    let card: Card

    /// What the spoken answer came to, if the learner used the microphone.
    ///
    /// Defaults to `nil`, which is what mode B always passes — there is no
    /// recording there, and this parameter exists so the two modes can keep
    /// sharing one revealed state instead of growing a second one.
    var speechCheck: SpeechCheck? = nil

    /// The Hanzi size, and the reason it is not a plain `44`.
    ///
    /// `Font.system(size:)` ignores Dynamic Type entirely. Everything else on
    /// this card uses a text style and grows with the setting, so a fixed
    /// number would leave the **characters** — the one thing that has to be
    /// legible — as the only part that stays small. `@ScaledMetric` returns
    /// exactly 44 at the default size, so the layout the device test approved
    /// is unchanged; it only moves when the user asks for larger text.
    @ScaledMetric(relativeTo: .largeTitle) private var hanziSize: CGFloat = 44

    /// The explanation sheet, presented from the revealed card.
    ///
    /// Lives here and **not** in `LearnSessionModel`: the model owns what the
    /// session is, and looking a word up is not part of that. Keeping the state
    /// out of the model is what makes „the sheet changes no session state" a
    /// structural fact instead of a claim.
    @State private var explainedCard: ExplainedCard?

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
                .font(.system(size: hanziSize, weight: .medium))
                .multilineTextAlignment(.center)
                // Marked as Chinese so VoiceOver switches voices for the
                // characters instead of reading them in German.
                .accessibilityLabel(Text(LearnAnswer.accessibilityAttributedLabel(for: card)))

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

            if let speechCheck {
                SpeechCheckNote(check: speechCheck)
            }

            explanationEntry
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        // Presented from here, with `ExplainedCard` — plain strings, no `Card`,
        // no `ModelContext`, no session model. The sheet therefore *cannot*
        // touch the session state, rather than being trusted not to.
        .sheet(item: $explainedCard) { explained in
            CardExplanationSheet(card: explained)
        }
    }

    /// The way into the explanation, on the revealed card only.
    ///
    /// „Revealed only" is not enforced by a condition here — it is enforced by
    /// **where this view is used**: both modes reach `LearnRevealedAnswerView`
    /// exclusively from their revealed branch. The rule is still asked, so that
    /// availability governs it and the call site says out loud what it relies
    /// on.
    ///
    /// Resolved on every render rather than stored: the system can switch Apple
    /// Intelligence off while the app runs.
    ///
    /// **The learning screen shows the entry only when it is usable** — no
    /// greyed-out button and no explanatory text here. Everywhere else the
    /// recoverable states are shown with a reason, and this screen is the one
    /// exception, for two reasons the review made concrete: the text would stand
    /// under *every* revealed card for the whole session, which is the prose
    /// phase 13 just removed; and this stack has no `ScrollView`, so a sentence
    /// card with a mismatch note plus a three-line reason can overflow. The
    /// reason stays reachable in the card list's menu and in the settings, so
    /// nothing becomes unexplainable — only quieter where the learner is working.
    @ViewBuilder
    private var explanationEntry: some View {
        // The whole rule is in the function — including „only when usable" (A51),
        // which used to sit here as a second condition. A rule at a call site is
        // a rule no test can reach, and the second audit found exactly that.
        if CardExplanationEntry.isOfferedOnLearningCard(AIAvailability.current(), isRevealed: true) {
            Button {
                explainedCard = ExplainedCard(card)
            } label: {
                Label("Erklärung anzeigen", systemImage: CardExplanationEntry.symbolName)
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
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

    /// Same reasoning as the Hanzi above, with a second effect that matters
    /// more here: this symbol *is* the button, so its tap target grows with
    /// the type size instead of staying a fixed square.
    @ScaledMetric(relativeTo: .largeTitle) private var speakerSize: CGFloat = 64
    @ScaledMetric(relativeTo: .largeTitle) private var mutedSize: CGFloat = 44

    var body: some View {
        // The same question `SpeakButton` asks itself, so the two cannot
        // disagree and leave an empty space: a voice can be installed while
        // *this* card has nothing speakable, which a mid-session edit in the
        // cards tab can produce. `SpeakButton` carries its own label.
        if SpeakButton.isVisible(isAvailable: speech.isAvailable, hanzi: LearnAnswer.hanzi(for: card)) {
            SpeakButton(hanzi: LearnAnswer.hanzi(for: card))
                .font(.system(size: speakerSize))
                .foregroundStyle(.tint)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "speaker.slash")
                    .font(.system(size: mutedSize))
                    .foregroundStyle(.secondary)

                Text(MissingVoiceNotice.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// What the recognition found, stated as carefully as it deserves.
///
/// ## The wording is the feature
///
/// A match says **„Erkannt wie erwartet"** — a statement about two texts, not
/// about the person who spoke. The chain that produced it is: spoken Mandarin
/// → Apple's recognition → recognised Hanzi → normalisation → string
/// comparison. Nothing in it measured pronunciation, and a recogniser with a
/// good language model guesses the right sentence out of poor pronunciation
/// routinely. Claiming otherwise is the one thing `CLAUDE.md` forbids
/// outright (rule 7).
///
/// It used to say „Antwort wahrscheinlich korrekt", which was a claim about
/// the **answer**. The phase-9 benchmark withdrew the ground under it: in the
/// first positive pass the transcriber returned a different Chinese text for
/// 8 of 16 normally spoken target answers. The response was not to loosen the
/// measurement but to narrow the claim — see `SpeechCheck.matchTitle`.
///
/// A mismatch shows both texts and passes no verdict. Deliberately not red
/// and not marked wrong: the recognition can be wrong, the card can be wrong,
/// and the learner is the one who knows which. What stands below it is
/// untouched by this note — since phase 13 that is *Weiter*, because a mismatch
/// earns no offer (`docs/learning-engine.md` §13.8).
private struct SpeechCheckNote: View {
    let check: SpeechCheck

    var body: some View {
        VStack(spacing: 6) {
            switch check {
            case .match:
                Label(SpeechCheck.matchTitle, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

            case .mismatch(let recognized, let expected):
                VStack(spacing: 10) {
                    line(SpeechCheck.recognizedLabel, recognized)
                    line(SpeechCheck.expectedLabel, expected)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    /// One labelled line, centred like everything else on this screen.
    ///
    /// It used to be a label column and a left-aligned value, which read as a
    /// form pasted into a centred layout — the device test called it out. The
    /// label now sits above its text, both centred, so a long sentence wraps
    /// under its own heading instead of pushing the row wide.
    private func line(_ label: String, _ text: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(text)")
    }
}
