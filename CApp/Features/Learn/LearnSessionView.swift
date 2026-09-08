//
//  LearnSessionView.swift
//  CApp
//

import SwiftData
import SwiftUI

/// One running session: a card, a way to reveal it, and four answers.
///
/// There is no progress bar and no finish line. Mini-batches are an internal
/// detail of the engine and are never shown — the session runs until the user
/// ends it, so anything that looked like "7 of 7" would be inventing a goal
/// (`docs/learning-engine.md` §1).
struct LearnSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var model: LearnSessionModel
    @State private var isShowingNewCardSheet = false

    init(configuration: SessionConfiguration) {
        _model = State(initialValue: LearnSessionModel(configuration: configuration))
    }

    var body: some View {
        content
            .navigationTitle(model.configuration.cardType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
                if model.answeredCount > 0 {
                    ToolbarItem(placement: .status) {
                        // Plain count, no target and no percentage: the
                        // session has no natural end to measure against.
                        Text("\(model.answeredCount) bearbeitet")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                model.start(in: context)
            }
            .alert(
                "Speichern fehlgeschlagen",
                isPresented: Binding(
                    get: { model.saveFailure != nil },
                    set: { if $0 == false { model.dismissSaveFailure() } }
                ),
                presenting: model.saveFailure
            ) { _ in
                Button("OK", role: .cancel) { model.dismissSaveFailure() }
            } message: { failure in
                Text(failure.userText)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let card = model.currentCard {
            VStack(spacing: 16) {
                PromptGermanToChineseView(card: card, isRevealed: model.isRevealed)

                if model.isRevealed {
                    SelfAssessmentBar { assessment in
                        model.submit(assessment, in: context)
                    }
                } else {
                    Button("Antwort zeigen") {
                        model.reveal()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        } else {
            emptyState
        }
    }

    /// Shown when the configuration has no usable card — including the case
    /// where the last one was deleted while the session was running.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("Keine passenden Karten", systemImage: "rectangle.stack.badge.questionmark")
        } description: {
            Text("Für diese Auswahl gibt es keine Karten mit chinesischem Text.")
        } actions: {
            // A direct way, as task 6.9 asks — not a pointer to another tab.
            Button("Karte anlegen") { isShowingNewCardSheet = true }
                .buttonStyle(.borderedProminent)
            Button("Zurück") { dismiss() }
        }
        .sheet(isPresented: $isShowingNewCardSheet) {
            NavigationStack {
                CardEditorView(type: model.configuration.cardType)
            }
        }
    }
}
