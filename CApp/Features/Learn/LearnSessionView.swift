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
    @Environment(SpeechSynthesisService.self) private var speech
    @Environment(SpeechRecognitionService.self) private var recognition
    @Environment(\.dismiss) private var dismiss

    @State private var model: LearnSessionModel
    @State private var isShowingNewCardSheet = false

    /// Which card the running recording belongs to.
    ///
    /// Captured when recording starts, not when it ends: by the time the
    /// analyzer finalises, the session may have moved on, and the id is what
    /// lets `applyRecognition` drop a result that no longer belongs
    /// anywhere.
    @State private var recordingCardID: UUID?

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
            // Die Karte wechselt, der Ton endet. In Modus A war ein Nachklang
            // aus der vorigen Karte unschön; in Modus B **ist** das Audio die
            // Frage, und ein Wort, das in die nächste Karte hineinläuft, ist
            // dann die falsche Frage — der Lernende schätzt sich zu etwas ein,
            // das er gar nicht gehört hat. Sichtbar wird es nicht: Der
            // Lautsprecher der neuen Karte bleibt ungefüllt, weil
            // `SpeakButton` den Text vergleicht.
            .onChange(of: model.currentCard?.id) { _, _ in
                speech.stop()
                abandonRecording()
            }
            // Die Session endet, der Ton endet. Auch der einzige Teardown, der
            // ohne Delegate-Callback auskommt.
            .onDisappear {
                speech.stop()
                abandonRecording()
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
                prompt(for: card)
                controls
            }
            .padding()
        } else {
            emptyState
        }
    }

    /// One direction, one prompt view.
    ///
    /// A `switch` over two small views rather than a shared superview with
    /// options: the two modes show different things in a different order,
    /// and the one thing they have in common — the self-assessment — is
    /// already its own component. An abstraction over two cases would have
    /// to be undone the moment they differ again.
    @ViewBuilder
    private func prompt(for card: Card) -> some View {
        switch model.configuration.direction {
        case .germanToChinese:
            PromptGermanToChineseView(
                card: card,
                isRevealed: model.isRevealed,
                speechCheck: model.speechCheck
            )
        case .audioToGerman:
            PromptAudioToGermanView(card: card, stage: model.promptStage)
        }
    }

    /// Starts a recording for the card currently on screen.
    ///
    /// Speech output stops first. The app never records and speaks at once —
    /// they want different audio session categories, and a card talking into
    /// its own recording would be recognised along with the learner.
    private func startRecording(for card: Card) {
        speech.stop()
        recordingCardID = card.id
        Task { await recognition.startRecording() }
    }

    /// Stops, and hands the result to the card it started on.
    private func stopRecording() {
        Task {
            let text = await recognition.stopAndFinalize()
            // No text is not a silent no-op: the service moves to
            // `.noSpeechDetected` and the button says so. The card stays
            // covered, because nothing was checked.
            guard let text, let id = recordingCardID else { return }
            model.applyRecognition(text, forCardWith: id)
        }
    }

    /// Throws away a running recording.
    ///
    /// Used wherever the answer stops being a question: revealing by hand,
    /// changing card, leaving the session. Nothing that was being recognised
    /// may surface afterwards.
    private func abandonRecording() {
        recordingCardID = nil
        Task { await recognition.cancelRecording() }
    }

    /// What can be done next.
    ///
    /// Mode A is unchanged: reveal, then rate. Mode B adds the middle step
    /// in front of it, and the rule for whether that step is still on offer
    /// lives in `AudioPrompt` with the visibility rules it belongs to.
    @ViewBuilder
    private var controls: some View {
        if AudioPrompt.allowsAssessment(at: model.promptStage) {
            SelfAssessmentBar { assessment in
                // A rating can only follow a finished recording: the card is
                // revealed here, and revealing always ends one.
                model.submit(assessment, in: context)
            }
        } else {
            VStack(spacing: 8) {
                if AudioPrompt.offersHanziStep(
                    at: model.promptStage,
                    in: model.configuration.direction
                ) {
                    Button("Hanzi anzeigen") {
                        model.showHanzi()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }

                if let card = model.currentCard,
                   RecordAnswerButton.isOffered(
                       in: model.configuration.direction,
                       revealed: model.isRevealed
                   ) {
                    RecordAnswerButton(
                        phase: recognition.phase,
                        progress: recognition.downloadProgress,
                        failure: recognition.failure,
                        start: { startRecording(for: card) },
                        stop: stopRecording
                    )
                }

                Button("Antwort zeigen") {
                    // Revealing by hand ends a running recording rather than
                    // racing it: a result arriving afterwards would attach
                    // itself to a card the learner has already given up on.
                    abandonRecording()
                    model.reveal()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
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
