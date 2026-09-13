//
//  SettingsView.swift
//  CApp
//

import SwiftData
import SwiftUI

/// The app's settings, on a sheet behind the gear in the card list.
///
/// A `Form`, because that is what iOS settings look like and nothing here
/// needs anything else. Five sections, and deliberately not a sixth: this
/// screen exists to adjust what phases 5 to 9 built, not to grow features of
/// its own. No statistics, no charts, no export, no account.
///
/// Every control writes `UserDefaults` through `@AppStorage`, and the
/// services read the same keys when they need them. That is what makes a
/// change take effect on the next utterance or the next batch without a
/// restart and without a notification of our own — see `Preferences`.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SpeechSynthesisService.self) private var speech
    @Environment(SpeechRecognitionService.self) private var recognition

    /// Every card, to count by status. The counts have to be right after an
    /// edit, so they come from the live query rather than from a stored
    /// number that could drift.
    @Query private var allCards: [Card]

    @AppStorage(Preferences.speechRateKey) private var storedRate = SpeechRate.default.rawValue
    @AppStorage(Preferences.voiceIdentifierKey) private var storedVoice = Preferences.automaticVoice
    @AppStorage(Preferences.batchSizeKey) private var storedBatchSize = LearningParameters.batchSize

    @State private var isConfirmingModelRemoval = false

    /// The Mandarin voices on this device, read once when the sheet appears.
    ///
    /// Not computed in `body`: enumerating every installed voice — 181 of
    /// them on the test device — would happen again on every stepper tap and
    /// every picker change. The list only moves when the user installs or
    /// deletes a voice in the iOS settings, which means leaving this screen.
    @State private var voices: [VoiceCandidate] = []

    var body: some View {
        NavigationStack {
            Form {
                speechSection
                voiceSection
                learningSection
                modelSection
                statusSection
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task {
                voices = speech.offeredVoices()
                resetVoiceChoiceIfItIsGone()
                await recognition.refreshModelStatus()
            }
        }
    }

    // MARK: - Speaking rate

    private var speechSection: some View {
        Section {
            Picker("Sprechtempo", selection: rateSelection) {
                ForEach(SpeechRate.allCases) { rate in
                    Text(rate.title).tag(rate)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Sprechtempo")
        } footer: {
            // The numbers are named because they were measured, not chosen:
            // phase 7 compared exactly these three on the device.
            Text("Gilt für die Aussprache auf Knopfdruck. Wirkt ab der nächsten Wiedergabe.")
        }
    }

    private var rateSelection: Binding<SpeechRate> {
        Binding(
            get: { Preferences.speechRate(from: storedRate) },
            set: { storedRate = $0.rawValue }
        )
    }

    // MARK: - Voice

    @ViewBuilder
    private var voiceSection: some View {
        // One voice is not a choice. Showing a picker with a single entry
        // would suggest there is something to decide.
        if voices.count > 1 {
            Section {
                Picker("Stimme", selection: voiceSelection) {
                    Text("Automatisch").tag(Preferences.automaticVoice)
                    ForEach(voices, id: \.identifier) { voice in
                        Text(voice.name).tag(voice.identifier)
                    }
                }
            } header: {
                Text("Stimme")
            } footer: {
                Text(voiceFooter)
            }
        }
    }

    /// Drops a stored choice that names a voice which is no longer installed.
    ///
    /// The service already falls back to the automatic rule in that case, so
    /// the app speaks correctly either way — but the picker would find no
    /// matching tag and show **no** selection at all, which reads as if
    /// something is broken. Rather than display one thing and do another, the
    /// stale value goes.
    private func resetVoiceChoiceIfItIsGone() {
        storedVoice = SettingsView.voiceChoice(storedVoice, amongst: voices)
    }

    /// The choice that should be stored, given what is installed.
    ///
    /// Pulled out as a pure function for the same reason as `count(of:in:)`:
    /// it is the only place in this screen that **discards** something the
    /// user chose, and a rule like that should be falsifiable without a
    /// device. Returns the choice unchanged unless the voice it names is
    /// gone.
    static func voiceChoice(_ stored: String, amongst voices: [VoiceCandidate]) -> String {
        guard let chosen = Preferences.voiceIdentifier(from: stored) else {
            return Preferences.automaticVoice
        }
        guard voices.contains(where: { $0.identifier == chosen }) else {
            return Preferences.automaticVoice
        }
        // The normalised identifier, not the raw one. Returning `stored`
        // unchanged meant a value with stray whitespace passed the check and
        // was then written back untrimmed — and the picker, which matches
        // tags exactly, showed no selection at all. That is the very failure
        // this function exists to prevent.
        return chosen
    }

    private var voiceSelection: Binding<String> {
        Binding(
            get: { storedVoice },
            set: { identifier in
                storedVoice = identifier
                // The service caches the resolved voice, so it is told
                // rather than left to notice.
                speech.refreshVoice()
            }
        )
    }

    private var voiceFooter: String {
        if Preferences.voiceIdentifier(from: storedVoice) == nil {
            "Automatisch wählt die beste installierte Stimme. Wird eine gewählte Stimme "
                + "später entfernt, greift die Automatik wieder."
        } else {
            "Wird diese Stimme entfernt, greift automatisch wieder die beste installierte."
        }
    }

    // MARK: - Learning

    private var learningSection: some View {
        Section {
            Stepper(
                "Karten je Runde: \(Preferences.batchSize(from: storedBatchSize))",
                value: batchSizeSelection,
                in: Preferences.batchSizeRange
            )
        } header: {
            Text("Lernen")
        } footer: {
            Text("Gilt ab der nächsten Runde. Eine laufende Runde wird nicht umgebaut.")
        }
    }

    private var batchSizeSelection: Binding<Int> {
        Binding(
            get: { Preferences.batchSize(from: storedBatchSize) },
            set: { storedBatchSize = $0 }
        )
    }

    // MARK: - Speech model

    private var modelSection: some View {
        Section {
            LabeledContent("Spracherkennung", value: recognition.modelStatusText)

            if let progress = recognition.downloadProgress {
                ProgressView(progress)
                    .progressViewStyle(.linear)
            }

            if recognition.canPrepareModel {
                Button("Sprachmodell vorbereiten") {
                    Task { await recognition.prepare() }
                }
            }

            if recognition.canRemoveModel {
                Button("Sprachmodell entfernen", role: .destructive) {
                    isConfirmingModelRemoval = true
                }
            }

            if let message = SettingsView.modelMessage(
                modelFailure: recognition.modelFailure,
                recordingFailure: recognition.failure
            ) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Sprachmodelle")
        } footer: {
            // The honest version of what "remove" does, and the part about
            // translation that the app cannot control.
            Text(
                """
                Das Mandarin-Modell für die Spracherkennung liegt auf dem Gerät und \
                wird vom System verwaltet. Entfernen gibt die Reservierung frei; das \
                System löscht die Daten später und ein erneutes Vorbereiten braucht \
                dann wieder eine Internetverbindung. Die Modelle für Übersetzung und \
                Sprachausgabe verwaltet iOS selbst — sie lassen sich nur in den \
                iOS-Einstellungen ändern.
                """
            )
        }
        .confirmationDialog(
            "Sprachmodell entfernen?",
            isPresented: $isConfirmingModelRemoval,
            titleVisibility: .visible
        ) {
            Button("Entfernen", role: .destructive) {
                Task { await recognition.releaseModel() }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Spracherkennung funktioniert danach erst wieder nach einem erneuten Download.")
        }
    }

    // MARK: - Status counts

    private var statusSection: some View {
        Section {
            ForEach(LearningStatus.allCases, id: \.self) { status in
                LabeledContent(status.title, value: "\(count(of: status))")
            }
        } header: {
            Text("Karten je Lernstand")
        } footer: {
            Text("\(allCards.count) Karten insgesamt.")
        }
    }

    /// What this section is allowed to say about a failure.
    ///
    /// Both failures are passed in although only one is ever shown, and that
    /// is the point: the rule is „the model section shows the model failure
    /// and **never** the recording one", and a rule stated that way can be
    /// falsified. The review found the version before it — a recognition
    /// error from a learning session standing under „Sprachmodelle",
    /// explaining that the self-assessment still works.
    static func modelMessage(modelFailure: AppError?, recordingFailure: AppError?) -> String? {
        _ = recordingFailure
        return modelFailure?.message
    }

    /// Counted from the live query, not stored anywhere.
    ///
    /// A pure function over the cards so the same counting can be tested
    /// without a view — the numbers have to be right after every edit, and
    /// "right" is exactly the kind of thing that quietly stops being true
    /// when it is cached.
    private func count(of status: LearningStatus) -> Int {
        SettingsView.count(of: status, in: allCards)
    }

    static func count(of status: LearningStatus, in cards: [Card]) -> Int {
        cards.count { $0.status == status }
    }
}
