//
//  CardExplanationSheet.swift
//  CApp
//

import SwiftUI

/// A card reduced to the four strings an explanation needs.
///
/// ## This type is the neutrality guarantee
///
/// The sheet must not change anything — not the card, not the learning status,
/// not a running session. The cheapest way to promise that is a comment; the
/// only way to **prove** it is to hand the sheet nothing it could change. So it
/// receives this value and never a `Card`, never a `ModelContext` and never the
/// session model. There is no write it could perform, and the compiler carries
/// that rather than a reviewer.
///
/// `Identifiable` because `.sheet(item:)` presents it, and because the identity
/// has to be the card's own — presenting a second card while the first sheet is
/// open should rebuild it, not keep stale text.
struct ExplainedCard: Identifiable, Equatable {
    let id: UUID
    let german: String
    let hanzi: String
    let pinyin: String

    /// Reads a card. Deliberately the only place that touches one.
    init(_ card: Card) {
        id = card.id
        german = card.german
        hanzi = card.hanzi
        pinyin = card.pinyin
    }

    /// For tests and previews.
    init(id: UUID = UUID(), german: String, hanzi: String, pinyin: String) {
        self.id = id
        self.german = german
        self.hanzi = hanzi
        self.pinyin = pinyin
    }
}

/// The explanation, for both entry points.
///
/// One sheet, two callers — the card list and the **revealed** learning card.
/// Two files that agree to look alike are the arrangement that drifts apart on
/// the third change, which is the reason `LearnRevealedAnswerView` is shared as
/// well (A34).
///
/// ## Nothing happens until asked
///
/// Opening the sheet makes **no** request. The user sees the card and the
/// notice, and taps. That is not politeness: on the device only the first
/// request of a process succeeded and every later one was rate-limited
/// (`docs/apple-frameworks.md` §12.1), so an automatic request on open would
/// spend the one that works on a sheet nobody asked to fill.
///
/// ## Nothing survives closing
///
/// The text lives in `@State`. No SwiftData, no `UserDefaults`, no cache. The
/// system model changes with OS updates, so a stored explanation would be the
/// answer of a model that no longer exists, without saying so.
struct CardExplanationSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// The control flow, in a type a test can drive — see `CardExplanationModel`.
    @State private var model: CardExplanationModel

    /// Only the card. The injection seam lives in `CardExplanationModel`, where
    /// the tests use it — a second one here would be the only way production
    /// code could bypass the generator, and no test would benefit.
    init(card: ExplainedCard) {
        _model = State(initialValue: CardExplanationModel(card: card))
    }

    var body: some View {
        NavigationStack {
            Form {
                cardSection
                noticeSection
                actionSection
                if let explanation = model.explanation {
                    resultSections(explanation)
                }
                if let failure = model.failure {
                    failureSection(failure)
                }
            }
            .navigationTitle("Erklärung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .disabled(model.isGenerating)
                }
            }
            // Both are needed, and the second one is the one that was missing.
            //
            // Closing the sheet mid-request does not stop the request — the task
            // outlives the view. Reopening then creates a **new** view identity
            // with `isGenerating == false`, which could start a second session
            // while the first is still answering. `concurrentRequests` would
            // still be impossible (A47), but the measured rate limiter is not:
            // the second request burns the one that works (§12.1).
            //
            // So the sheet stays put while it is asking. Preferred over
            // cancelling the task on disappear, because Apple does not promise
            // cancellation semantics for `respond`, and „probably stopped" is
            // not a basis for allowing a second request.
            .interactiveDismissDisabled(model.isGenerating)
        }
    }

    // MARK: The card being explained

    private var cardSection: some View {
        Section {
            Text(ChineseText.spoken(model.card.hanzi))
                .font(.title2)
            if model.card.pinyin.isEmpty == false {
                Text(model.card.pinyin)
                    .foregroundStyle(.secondary)
            }
            Text(model.card.german)
        }
    }

    // MARK: The notice, and why it is not optional

    /// Apple denies the model factual reliability outright, and the device
    /// measurement found broken German („einen Obstsorten namens Apfel") and an
    /// invented word („Gegenstandsfähigkeit") in five samples. An unlabelled
    /// explanatory text in a learning app is an authority claim nobody backed.
    private var noticeSection: some View {
        Section {
            Label(
                "Automatisch erzeugt – kann Fehler enthalten.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: The one action

    private var actionSection: some View {
        Section {
            Button {
                Task { await model.generate() }
            } label: {
                if model.isGenerating {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Wird erzeugt …")
                    }
                } else {
                    Text(model.hasExplanation ? "Neu erzeugen" : "Erklärung erzeugen")
                }
            }
            .disabled(model.isGenerating)
        } footer: {
            if model.hasExplanation {
                Text("Neu erzeugen stellt eine weitere Anfrage an das Modell.")
            }
        }
    }

    // MARK: The result

    @ViewBuilder
    private func resultSections(_ explanation: CardExplanation) -> some View {
        Section("Bedeutung") {
            Text(explanation.meaning)
        }
        Section("Gebrauch") {
            Text(explanation.usage)
        }
        if explanation.shownExamples.isEmpty == false {
            Section("Beispiele") {
                ForEach(Array(explanation.shownExamples.enumerated()), id: \.offset) { _, example in
                    VStack(alignment: .leading, spacing: 4) {
                        // Only the Chinese run is marked: a Mandarin voice
                        // reading the German translation would be as wrong as a
                        // German voice reading the Hanzi.
                        Text(ChineseText.spoken(example.chinese))
                        Text(example.german)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: The failure

    /// Stays in the sheet, keeps it usable, and never retries by itself.
    ///
    /// `AppError.userText` is what is shown — for both explanation cases that
    /// is German only, with no technical second paragraph, because the only
    /// thing a `GenerationError`'s context carries is a `debugDescription`.
    private func failureSection(_ failure: AppError) -> some View {
        Section {
            Text(failure.userText)
                .foregroundStyle(.secondary)
        } header: {
            Text("Nicht erzeugt")
        }
    }

}
