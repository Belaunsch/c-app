//
//  LearnSessionView.swift
//  CApp
//

import AVFoundation
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

    /// Whether the session starts recordings by itself, and which card has
    /// already had its attempt (phase 12).
    @State private var speechState = SessionSpeechState()

    /// Counts recordings this view has started.
    ///
    /// `SpeechRecognitionService.startRecording()` reaches `.recording` only
    /// after several `await`s, so for a moment a recording exists that nothing
    /// can cancel — `cancelRecording()` returns immediately while no engine is
    /// built yet. The review found what that costs: an abandoned recording
    /// starts anyway, belongs to no card, and its text is silently dropped.
    /// The generation is checked once the start returns, and a superseded one
    /// tidies up after itself. Same device the service uses internally.
    @State private var recordingGeneration = 0

    @Environment(\.scenePhase) private var scenePhase

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
            // **Ein** Auslöser pro Kartenübergang, und deshalb ein
            // zusammengesetzter Schlüssel: Die Karten-ID allein übersieht die
            // Wiedereinstreuung („Nochmal" auf der letzten Karte eines Batches
            // legt dieselbe Karte zurück auf Position 0), `answeredCount`
            // allein übersieht eine Karte, die mitten in der Session gelöscht
            // wurde. Zwei getrennte `onChange` wären der Doppelstart, den das
            // Review gefunden hat — ihre Reihenfolge ist nicht zugesichert.
            .onChange(of: cardCycleKey) { _, _ in
                speech.stop()
                advanceToNextAttempt()
            }
            // Die Session endet, der Ton endet. Auch der einzige Teardown, der
            // ohne Delegate-Callback auskommt.
            .onDisappear {
                speech.stop()
                handle(.sessionEnded)
            }
            // Phase 12: Nichts nimmt im Hintergrund auf. Apple dokumentiert
            // den Deaktivierungs-Übergang als die Stelle dafür — und ohne
            // `UIBackgroundModes` (die App setzt keine) würde die Aufnahme
            // ohnehin mit dem Prozess suspendiert. Der Modus geht mit aus:
            // Zurückzukommen und ein offenes Mikrofon vorzufinden wäre eine
            // Überraschung.
            .onChange(of: scenePhase) { _, phase in
                // **Nur `.background`.** `.inactive` ist ein Banner, das
                // Kontrollzentrum, der App-Umschalter — und der
                // Mikrofon-Berechtigungsdialog beim allerersten Tap. Dort die
                // Aufnahme abzubrechen hieße, den ersten Versuch überhaupt
                // wegzuwerfen. Die Roadmap sagt „App im Hintergrund", und das
                // ist `.background`.
                guard phase == .background else { return }
                handle(.appLeftForeground)
            }
            // Ein Anruf, ein Wecker, eine andere App. Apples `shouldResume`
            // ist ausdrücklich ein Hinweis für **Wiedergabe** — ein Mikrofon
            // von selbst wieder zu öffnen, steht dort nicht.
            .onReceive(NotificationCenter.default.publisher(
                for: AVAudioSession.interruptionNotification
            )) { _ in
                handle(.audioInterrupted)
            }
            // Eine bewusst gestartete Sprachausgabe beendet den Modus — die
            // Produktregel der Roadmap. Beobachtet statt am Knopf verdrahtet,
            // damit jeder Weg zur Sprachausgabe zählt und `SpeakButton` für
            // Kartenliste und Editor unverändert bleibt.
            .onChange(of: speech.isSpeaking) { _, isSpeaking in
                // In Modus B **ist** die Sprachausgabe die Frage; dort gibt es
                // keinen Sprachmodus, den sie beenden könnte.
                guard model.configuration.direction == .germanToChinese else { return }
                guard isSpeaking else { return }
                handle(.speechOutputStarted)
            }
            // Ein technischer Fehler beendet den Modus. Ein Modus, der sich
            // durch einen kaputten Audiopfad weiterversucht, ist eine
            // Schleife, kein Feature.
            .onChange(of: recognition.phase) { _, phase in
                switch phase {
                case .failed:
                    handle(.recognitionFailed)
                // Armiert bleiben und nie wieder starten können wäre eine
                // Senke: `isIdle` schließt beide Phasen dauerhaft aus.
                case .unavailable, .permissionDenied:
                    handle(.speechUnavailable)
                default:
                    break
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
        // Marked before the recording starts, not after: this is what stops a
        // second automatic attempt on the same card, and it has to hold even
        // if the start fails.
        speechState.markAttempt(on: card.id)

        recordingGeneration += 1
        let generation = recordingGeneration
        Task {
            await recognition.startRecording()
            // Something abandoned this recording while it was still starting.
            // `cancelRecording()` cannot see a half-built engine, so the
            // tidying up happens here, once there is something to tidy.
            guard generation != recordingGeneration else { return }
            await recognition.cancelRecording()
        }
    }

    // MARK: - Session speech mode (phase 12)

    /// Changes once per card transition — including the one the id misses.
    private var cardCycleKey: String {
        "\(model.currentCard?.id.uuidString ?? "-")#\(model.answeredCount)"
    }

    /// The microphone tap: starts a recording **and** arms the session.
    ///
    /// One control, two effects — deliberately. A separate switch for „record
    /// every card" would be a second thing to explain for a feature whose
    /// whole point is one tap fewer.
    private func startRecordingAndArm(for card: Card) {
        speechState.armStartingRecording(on: card.id)
        startRecording(for: card)
    }

    /// The one place a new card gets its recording.
    private func advanceToNextAttempt() {
        handle(.cardChanged)
        startRecordingIfArmed()
    }

    /// Starts the next recording if the session is in speech mode.
    ///
    /// The decision lives in `SessionSpeechState`, so the sequence can be
    /// driven without a view.
    private func startRecordingIfArmed() {
        guard let card = model.currentCard else { return }
        guard speechState.shouldStartRecording(
            for: card.id,
            direction: model.configuration.direction,
            isRevealed: model.isRevealed,
            phase: recognition.phase
        ) else { return }
        startRecording(for: card)
    }

    /// Applies one event to the speech state and the running recording.
    private func handle(_ event: SessionSpeechEvent) {
        if speechState.apply(event) {
            abandonRecording()
        }
    }

    /// Stops, and hands the result to the card it started on.
    private func stopRecording() {
        Task {
            let text = await recognition.stopAndFinalize()
            // No text is not a silent no-op: the service moves to
            // `.noSpeechDetected` and the button says so. The card stays
            // covered, because nothing was checked.
            guard let text, let id = recordingCardID else {
                // Phase 9 already moved the service to `.noSpeechDetected` and
                // the button says so. The mode stays on, but **this** card
                // gets no second automatic attempt — that would be the loop.
                handle(.nothingRecognized)
                return
            }
            model.applyRecognition(text, forCardWith: id, in: context)
            // **No start here.** Phase 11 may have advanced to the next card,
            // and if it did, the card-cycle observer starts the recording —
            // once. Starting here as well was a race with that observer: the
            // review traced it to either two microphones at the same time or a
            // recognised answer thrown away without a word.
        }
    }

    /// Throws away a running recording.
    ///
    /// Used wherever the answer stops being a question: revealing by hand,
    /// changing card, leaving the session. Nothing that was being recognised
    /// may surface afterwards.
    private func abandonRecording() {
        recordingCardID = nil
        // Moved **before** the cancel: a recording still inside its start
        // window cannot be cancelled from here, and this is what tells it to
        // clean up when it gets there.
        recordingGeneration += 1
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
            SelfAssessmentBar(
                action: { assessment in
                    // A rating can only follow a finished recording: the card
                    // is revealed here, and revealing always ends one.
                    model.submit(assessment, in: context)
                    // The card cycle moved on — `answeredCount` went up even
                    // when the same card comes straight back after „Nochmal".
                    // The observer above does the rest.
                },
                suggestion: model.suggestedAssessment
            )
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
                        start: { startRecordingAndArm(for: card) },
                        stop: stopRecording
                    )
                }

                Button("Antwort zeigen") {
                    // Revealing by hand ends a running recording rather than
                    // racing it: a result arriving afterwards would attach
                    // itself to a card the learner has already given up on.
                    // The speech mode survives — revealing one card is not a
                    // decision about the next.
                    handle(.answerRevealedByHand)
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
            Label("Keine passenden Karten", systemImage: "rectangle.stack")
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
