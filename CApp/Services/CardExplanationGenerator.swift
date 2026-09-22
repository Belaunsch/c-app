//
//  CardExplanationGenerator.swift
//  CApp
//

import Foundation
import FoundationModels
import os

/// One example sentence: Chinese and its German translation, as **two fields**.
///
/// The two fields are a measurement result, not a preference. With
/// `examples: [String]` the device run of 2026-09-21 produced, in three of five
/// cases, the Chinese in slot 1 and the German in slot 2 — one example split
/// across two entries — and in the other two both languages crammed into one
/// string. Two named fields make the intent unambiguous for the model, and they
/// are what the interface needs anyway: only the Chinese run gets the language
/// marking (`ChineseText`).
@Generable
struct CardExplanationExample: Equatable, Sendable {
    @Guide(description: "Ein kurzer chinesischer Beispielsatz in vereinfachten Schriftzeichen.")
    var chinese: String

    @Guide(description: "Die deutsche Übersetzung genau dieses Satzes.")
    var german: String
}

/// What the model is asked to produce.
///
/// Structured rather than one block of prose, so the interface can set the
/// parts itself instead of splitting a paragraph — and so the count limit on
/// the examples lives in the **schema** rather than only in the prompt text.
///
/// **This is a value type and has no persistence path.** It is not a `@Model`,
/// it is never inserted, and the compiler carries that boundary rather than
/// discipline. The explanation lives in a view and is gone when it closes.
///
/// Properties are generated in declaration order, so meaning comes before the
/// usage that refers to it, and the examples last.
@Generable
struct CardExplanation: Equatable, Sendable {
    @Guide(description: "Die Bedeutung des Ausdrucks in ein bis zwei Sätzen, auf Deutsch.")
    var meaning: String

    @Guide(description: "Der typische Gebrauch in ein bis zwei Sätzen, auf Deutsch.")
    var usage: String

    @Guide(description: "Höchstens zwei kurze Beispiele.", .maximumCount(2))
    var examples: [CardExplanationExample]

    /// The examples the interface is allowed to show.
    ///
    /// The `@Guide` above declares the limit to the model, and on the device the
    /// model honoured it in all five measured cases. **That is not the same as a
    /// guarantee.** Apple documents constrained sampling as a promise about the
    /// *format*, not about the number of elements, and a schema-level assertion
    /// turned out not to be checkable in a test — the encoded schema does not
    /// change when the guide is removed, so a test built on it passes either way
    /// and proves nothing.
    ///
    /// So the limit is enforced here as well, where it is a plain rule a test can
    /// falsify. Model output is not trusted to keep its side of a bargain.
    var shownExamples: [CardExplanationExample] {
        Array(examples.prefix(Self.maximumExamples))
    }

    /// Two, matching the guide and the specification.
    static let maximumExamples = 2
}

/// Asks the on-device model for one explanation.
///
/// ## One session per request, and it is thrown away
///
/// Apple: „For a single-turn interaction, create a new session each time you
/// call the model." This is the opposite of `SpeechSynthesisService`, which
/// *must* hold its `AVSpeechSynthesizer` for the app's lifetime — a
/// `LanguageModelSession` must **not** be held, because everything accumulates
/// in a 4096-token context window.
///
/// ## One request per user action
///
/// Measured, not thrift: on the device only the first request of a process
/// succeeded; every later one was rate-limited, and waiting did not help
/// (`docs/apple-frameworks.md` §12.1). Nothing here retries, queues or reloads
/// on its own. A second explanation needs a second tap.
///
/// ## No tools
///
/// `tools:` is not passed and defaults to empty. A tool with store access would
/// be the one path on which model output could write by itself — which is why
/// it does not exist.
enum CardExplanationGenerator {

    /// The card's text goes in, an explanation comes out. Nothing is stored.
    ///
    /// - Throws: ``AppError/explanationRateLimited`` or
    ///   ``AppError/explanationFailed(_:)`` — never a raw `GenerationError`,
    ///   so no caller can print Apple's `debugDescription` into the interface.
    static func explanation(german: String, hanzi: String) async throws -> CardExplanation {
        let request = AIPrompts.explanationRequest(german: german, hanzi: hanzi)
        let session = LanguageModelSession(instructions: request.instructions)
        do {
            let response = try await session.respond(
                to: request.prompt,
                generating: CardExplanation.self
            )
            return response.content
        } catch {
            // The payload of `explanationFailed` is not shown — a
            // `GenerationError`'s context carries only a `debugDescription`, and
            // that must never reach the interface. Without a log the diagnosis
            // would be gone **entirely**, and a guardrail refusal, a decoding
            // failure and an exceeded context window would look identical in the
            // field. `os.Logger` is where this project already puts exactly that
            // (architecture.md §7).
            logger.error("Explanation failed: \(error.localizedDescription, privacy: .public)")
            throw appError(for: error)
        }
    }

    /// For the failure that the interface deliberately does not describe.
    private static let logger = Logger(
        subsystem: "de.belaunsch.CApp",
        category: "CardExplanation"
    )

    /// Maps what the framework throws onto what the user gets to read.
    ///
    /// Only the rate limit gets its own case, because it is the only one the
    /// user can act on — by waiting a moment and tapping again. Everything else
    /// is one message: the distinctions between a guardrail refusal, a decoding
    /// failure and an exceeded context window are real for a developer and
    /// meaningless for someone looking at a flashcard.
    static func appError(for error: any Error) -> AppError {
        if let error = error as? AppError { return error }

        // **Both error families, and that is a measured necessity.**
        //
        // `LanguageModelSession.GenerationError` is the type the deployment
        // target documents, and every one of its nine cases is deprecated in iOS
        // 27.0 with a named successor. That looked like a compile-time matter —
        // until the device measurement was re-read: on iOS 27.0 the spike's
        // `as? GenerationError` cast **never matched**, although the request had
        // clearly failed with a rate limit (`docs/apple-frameworks.md` §12.8).
        //
        // So iOS 27 throws the new family, and checking only the old one would
        // have silently dropped the single error path this phase calls „not an
        // edge case" — on exactly the OS where the rate limit is the normal case.
        // The second review caught it by reading the SDK; the measurement
        // confirms it.
        if #available(iOS 27.0, *) {
            if let error = error as? LanguageModelError, case .rateLimited = error {
                return .explanationRateLimited
            }
        }
        if let generation = error as? LanguageModelSession.GenerationError,
           case .rateLimited = generation {
            return .explanationRateLimited
        }
        return .explanationFailed(error)
    }
}
