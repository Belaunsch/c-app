//
//  AIPrompts.swift
//  CApp
//

import Foundation

/// Everything the on-device model is told, in one place, with a version.
///
/// ## Why a revision number for text that is never stored
///
/// Nothing here is persisted — the explanation lives in a view and is gone when
/// the sheet closes. The revision exists for the **measurements**: Apple names
/// three model versions with different behaviour (26.0–26.3, 26.4, 27.0), and a
/// measurement that does not say which prompt produced it is an anecdote. The
/// rule is in `docs/roadmap.md` § Phase 14: change an instruction, raise
/// ``promptRevision``, add a measurement line to `docs/apple-frameworks.md` §12.
///
/// An `Int` rather than a template system, because there is exactly **one**
/// instruction in a private app.
///
/// ## The split that matters
///
/// Apple: „The model obeys prompts at a lower priority than the instructions you
/// provide" and „don't include input from people or any unverified input in the
/// instructions." So the card's text — which the user typed — goes into the
/// **prompt**, never into the instructions. ``explanationRequest(german:hanzi:)``
/// exists so that this separation is a value a test can check, rather than a
/// habit at the call site.
///
/// Measured on the device (`docs/apple-frameworks.md` §12.6): a prompt that
/// explicitly demanded a different language could **not** override the pinned
/// one. The separation is not theory.
nonisolated enum AIPrompts {

    /// Raised whenever an instruction in this file changes. See the type note.
    static let promptRevision = 1

    /// Apple's exact wording, quoted rather than paraphrased.
    ///
    /// „This special phrase comes from the model's training, and reduces the
    /// possibility of hallucinations in multilingual situations." It is English
    /// inside a German instruction on purpose — it is a trained token sequence,
    /// not a sentence for the user.
    static let localePhrase = "The person's locale is de_DE."

    /// What the model is, and what it must never do.
    ///
    /// The prohibitions are not decoration. Hard rule 7 forbids claiming
    /// anything about pronunciation, and a model asked to explain Chinese will
    /// volunteer tone advice unless told not to.
    static let explanationInstructions = """
    Du erklärst einem deutschsprachigen Menschen, der Mandarin lernt, einen \
    chinesischen Ausdruck. Antworte ausschließlich auf Deutsch. \
    \(localePhrase) Fasse dich kurz: die Bedeutung in ein bis zwei Sätzen, der \
    typische Gebrauch in ein bis zwei Sätzen, höchstens zwei kurze Beispiele. \
    Jedes Beispiel besteht aus einem chinesischen Satz und seiner deutschen \
    Übersetzung. Erfinde keine Grammatikregeln. Sage nichts über Aussprache und \
    nichts über Töne, und beurteile nicht, wie gut jemand spricht. Gib keine \
    Bewertung, keine Punktzahl, keinen Prozentwert. Wenn du etwas nicht sicher \
    weißt, lass es weg, statt zu raten.
    """

    /// One request: the fixed instructions plus the prompt built from card data.
    struct Request: Equatable {
        let instructions: String
        let prompt: String
    }

    /// Builds the request for one card.
    ///
    /// The returned `instructions` are ``explanationInstructions`` **unchanged**
    /// — that is the property the test pins, and it is what makes „no user text
    /// in the instructions" checkable instead of merely intended.
    static func explanationRequest(german: String, hanzi: String) -> Request {
        Request(
            instructions: explanationInstructions,
            prompt: """
            Chinesischer Ausdruck: \(hanzi)
            Deutsche Bedeutung auf der Lernkarte: \(german)

            Erkläre diesen Ausdruck.
            """
        )
    }
}
