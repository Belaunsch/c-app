//
//  CardExplanationModel.swift
//  CApp
//

import Foundation
import Observation

/// The explanation sheet's control flow, outside the `body`.
///
/// ## Why this type exists
///
/// It was added after the independent test audit, and the finding was fair: the
/// two promises this phase rests on — nothing is written, no session state moves
/// — were tested by calling three pure functions and comparing before and after.
/// That proves three pure functions are pure. It does **not** exercise the path
/// the promise is about, and an `insert` added to the sheet's generate action
/// would have left those tests green.
///
/// With the request as an injected closure, a test drives the real control flow:
/// open (no request), tap once (exactly one), tap twice quickly (still one),
/// throw (the previous text stays), close — and *then* compares the store.
///
/// **This is not a mock of the model.** The closure carries no opinion about
/// what an explanation says; it is a trigger for the app's own logic. The
/// model's output was measured on the device (`docs/apple-frameworks.md` §12)
/// and is deliberately not restaged by a fake. Precedent for the shape:
/// `LearnSessionModel(generator:now:)` injects randomness and the clock for
/// exactly the same reason.
@MainActor
@Observable
final class CardExplanationModel {

    /// Card text in, explanation out. The only thing the sheet can ask for.
    typealias Explain = (_ german: String, _ hanzi: String) async throws -> CardExplanation

    let card: ExplainedCard

    private(set) var explanation: CardExplanation?
    private(set) var failure: AppError?

    /// Blocks a second request while one is running.
    ///
    /// The strict half of „no two requests at once". The other half is
    /// structural: a `LanguageModelSession` never outlives one request (A47), so
    /// Apple's `concurrentRequests` cannot occur — and the sheet refuses to be
    /// dismissed while this is `true`, because closing and reopening would
    /// otherwise hand a fresh view a clean flag and start a second request.
    private(set) var isGenerating = false

    private let explain: Explain

    init(
        card: ExplainedCard,
        explain: Explain? = nil
    ) {
        self.card = card
        self.explain = explain ?? { german, hanzi in
            try await CardExplanationGenerator.explanation(german: german, hanzi: hanzi)
        }
    }

    /// Whether the button offers a first explanation or another one.
    var hasExplanation: Bool { explanation != nil }

    /// Asks once.
    ///
    /// Nothing calls this on appear. Measured reason: on the device only the
    /// first request of a process succeeded and the rest were rate-limited
    /// (§12.1), so an automatic request on open would spend the one that works
    /// on a sheet nobody asked to fill.
    func generate() async {
        guard isGenerating == false else { return }
        isGenerating = true
        failure = nil
        do {
            explanation = try await explain(card.german, card.hanzi)
        } catch {
            // The previous explanation stays on screen: a failed retry should
            // not take away the text the user was reading.
            failure = CardExplanationGenerator.appError(for: error)
        }
        isGenerating = false
    }
}
