//
//  PromptStage.swift
//  CApp
//

import Foundation

/// How much of the card is uncovered in mode B.
///
/// Mode A has one question — revealed or not — and `isRevealed` answers it.
/// Mode B has two steps before the answer, because task 8.5 asks for a middle
/// one: hearing the Chinese, then seeing how it is written, and only then the
/// meaning. Three states, so the rule needs a name.
///
/// It lives here as a pure type rather than as conditions inside the view for
/// the reason this project pulls every decision out of `body`: a `body` is
/// not reachable from a test, so a rule that lives only there is a rule
/// nobody can falsify. The phase-7 audit made that point about four separate
/// conditions, and this one carries the load-bearing promise of the whole
/// mode — that "Hanzi anzeigen" does **not** give the answer away.
nonisolated enum PromptStage: Int, Comparable, CaseIterable, Sendable {
    /// Only the speaker. No Hanzi, no Pinyin, no German.
    case audioOnly = 0

    /// The Hanzi is visible. Pinyin and the German meaning are not — that
    /// separation is the whole point of the step.
    case hanziShown = 1

    /// Everything: Hanzi, Pinyin if there is any, and the meaning. Only from
    /// here can the card be rated.
    case revealed = 2

    static func < (lhs: PromptStage, rhs: PromptStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Derives the stage from the session model's two flags.
    ///
    /// `isRevealed` wins, and that is deliberate: it stays the single token
    /// for "this card may be rated" that mode A and `submit` have always
    /// used, so mode B adds a state without adding a second answer to an
    /// existing question. Whether the Hanzi was shown on the way there
    /// stops mattering once everything is visible.
    static func stage(isRevealed: Bool, hasShownHanzi: Bool) -> PromptStage {
        if isRevealed { return .revealed }
        return hasShownHanzi ? .hanziShown : .audioOnly
    }
}

/// What the covered stages of mode B put on screen, and what may be done.
///
/// **Only rules that something actually asks.** There used to be one function
/// per visible element — Hanzi, Pinyin, German, speaker — and the comment
/// here called them four questions that could each be falsified. That stopped
/// being true when the fully revealed card became a shared view: Pinyin, the
/// German meaning and the speaker are rendered unconditionally in
/// `LearnRevealedAnswerView`, so three of the four had no caller left. A rule
/// nothing asks is not a guarantee, and a test on it reads like coverage
/// while guarding nothing — so they are gone rather than kept as decoration.
///
/// What keeps the meaning out of the middle step now is **structure**: the
/// covered layout in `PromptAudioToGermanView` contains no German and no
/// Pinyin at all, and the `switch` that chooses it cannot be given the wrong
/// predicate. That is a stronger guarantee than the deleted functions
/// offered, and an honest one — no unit test reaches a `body`, and this file
/// no longer pretends otherwise. The device checklist covers the rest.
nonisolated enum AudioPrompt {

    /// Whether the writing is on screen. The one visibility rule with a
    /// caller: the covered layout renders the Hanzi behind it.
    static func showsHanzi(at stage: PromptStage) -> Bool {
        stage >= .hanziShown
    }

    /// Whether the middle step is on offer.
    ///
    /// Two conditions, and both belong here rather than in a `body`. Mode A
    /// has no middle step at all — showing the button there would set a flag
    /// its prompt view does not read, so it would sit on screen doing
    /// nothing visible. And within mode B it is only worth offering in
    /// ``PromptStage/audioOnly``: calling ``LearnSessionModel/showHanzi()``
    /// again is harmless, but a button that changes nothing is worse than no
    /// button.
    ///
    /// The direction is a parameter for the reason the phase-7 audit gave
    /// about `SpeakButton.isVisible`: as a condition split between a view
    /// and a function, either half can be deleted with the whole suite
    /// staying green.
    static func offersHanziStep(at stage: PromptStage, in direction: SessionDirection) -> Bool {
        direction == .audioToGerman && stage == .audioOnly
    }

    /// Rating is possible only once everything is visible.
    ///
    /// The same rule `LearnSessionModel.submit` enforces through
    /// `isRevealed` — stated here as well because this is the form the view
    /// asks it in, and the two must not be able to disagree.
    static func allowsAssessment(at stage: PromptStage) -> Bool {
        stage == .revealed
    }
}
