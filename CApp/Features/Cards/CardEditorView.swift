//
//  CardEditorView.swift
//  CApp
//

import SwiftData
import SwiftUI
import Translation

/// Creates or edits one card.
///
/// The normal flow is automatic: type the German text, finish it with Return
/// or by tapping the next field, and Hanzi and Pinyin appear. The end of
/// editing is the trigger — translating on every keystroke would be wasteful
/// and would fight the user while they type. Every field stays editable, and
/// the refresh control next to Hanzi and Pinyin is the only way automation may
/// replace something typed by hand.
struct CardEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Tag.name)]) private var allTags: [Tag]

    @State private var model: CardEditorModel
    @State private var saveFailure: AppError?
    @State private var translationConfiguration: TranslationSession.Configuration?
    /// Which strategy requirement the current configuration was built for.
    /// A configuration cannot change its strategy, so a changed requirement
    /// means building a new one instead of invalidating the old.
    @State private var configuredForLowLatency: Bool?
    @FocusState private var focusedField: Field?

    private enum Field {
        case german, hanzi, pinyin
    }

    init(card: Card? = nil, type: CardType = .word) {
        _model = State(initialValue: CardEditorModel(card: card, type: type))
    }

    var body: some View {
        Form {
            Section("Kartentyp") {
                Picker("Kartentyp", selection: $model.type) {
                    ForEach(CardType.allCases, id: \.self) { candidate in
                        Text(candidate.singularTitle).tag(candidate)
                    }
                }
                .pickerStyle(.segmented)
            }

            germanSection
            chineseSection

            Section("Lernstatus") {
                Picker("Lernstatus", selection: $model.status) {
                    ForEach(LearningStatus.allCases, id: \.self) { candidate in
                        Text(candidate.title).tag(candidate)
                    }
                }
            }

            tagSection
        }
        .navigationTitle(model.isEditingExistingCard ? "Karte bearbeiten" : "Neue Karte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern", action: save)
                    .disabled(model.canSave == false)
            }
            if model.isEditingExistingCard == false {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                // The only way to finish a multi-line field, and a second one
                // for single-line fields. It drops the focus and nothing
                // else, exactly like Return does, so there is still one path
                // into `endEditing(of:)` and no way to trigger it twice.
                Button("Fertig", action: finishEditing)
                    .disabled(focusedField == nil)
            }
        }
        .task {
            model.prepareResolver()
            await model.refreshTranslationSupport()
        }
        .onChange(of: focusedField) { previous, _ in
            if let previous {
                endEditing(of: previous)
            }
        }
        .translationTask(translationConfiguration) { session in
            await model.translate(using: session)
        }
        .alert(
            "Speichern fehlgeschlagen",
            isPresented: Binding(
                get: { saveFailure != nil },
                set: { if $0 == false { saveFailure = nil } }
            ),
            presenting: saveFailure
        ) { _ in
            Button("OK", role: .cancel) { saveFailure = nil }
        } message: { failure in
            Text(failure.userText)
        }
    }

    // MARK: - Sections

    private var germanSection: some View {
        Section {
            textField("Deutscher Text", text: $model.german, field: .german)
        } header: {
            Text("Deutsch")
        } footer: {
            // Only what is true right now. The former permanent sentence
            // explaining that leaving the field generates Hanzi and Pinyin is
            // gone: after the first card the user knows, and it pushed the
            // real messages out of sight.
            if let message = model.translationMessage {
                Text(message)
            }
        }
    }

    private var chineseSection: some View {
        Section {
            HStack(spacing: 12) {
                textField("Hanzi", text: $model.hanzi, field: .hanzi)

                // While a translation runs the control is the spinner: the
                // Hanzi field is where its result lands.
                if model.isTranslating {
                    ProgressView()
                } else {
                    Button {
                        retranslate()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    // Without this the whole row would act as the button.
                    .buttonStyle(.borderless)
                    .disabled(model.canTranslate == false)
                    .accessibilityLabel("Neu übersetzen")
                }
            }

            HStack(spacing: 12) {
                textField("Pinyin (optional)", text: $model.pinyin, field: .pinyin)
                    .autocorrectionDisabled()

                Button {
                    model.regeneratePinyin()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(model.canGeneratePinyin == false)
                .accessibilityLabel("Pinyin neu erzeugen")
            }

            // Directly under the Pinyin field, and only when this particular
            // value rests on a guess. Not a warning about the field in
            // general — that text was permanent before and told nobody
            // anything about the card in front of them.
            if model.pinyinNeedsReview {
                Label(
                    "Pinyin konnte nicht eindeutig bestimmt werden. Bitte prüfen.",
                    systemImage: "exclamationmark.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("Chinesisch")
        } footer: {
            if let footer = chineseFooter {
                Text(footer)
            }
        }
    }

    /// One text field, multi-line for sentence cards.
    ///
    /// A sentence in a single line can only be read by scrolling, which makes
    /// checking a translation awkward — so sentence cards get a growing
    /// field. Word cards stay compact. Multi-line fields turn Return into a
    /// newline, so both kinds are finished from the keyboard toolbar instead;
    /// single-line fields keep their Return key as well.
    private func textField(
        _ prompt: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        let isMultiline = model.type == .sentence
        return TextField(prompt, text: text, axis: isMultiline ? .vertical : .horizontal)
            .focused($focusedField, equals: field)
            // A multi-line field inserts a newline on Return and fires no
            // submit, so labelling its Return key "Fertig" would promise
            // something it does not do. Those fields are finished from the
            // keyboard toolbar.
            .submitLabel(isMultiline ? .return : .done)
            .onSubmit(finishEditing)
    }

    /// Only situational notes, `nil` when there is nothing to say.
    ///
    /// What used to stand here permanently — which fields are required, what
    /// the refresh controls do, that Pinyin is a suggestion — is gone. A text
    /// that is always there is read once and never again, and it crowded out
    /// the notes that do concern the card at hand.
    private var chineseFooter: String? {
        var lines: [String] = []
        if let hint = model.hanziHint {
            lines.append(hint)
        }
        if model.hanziIsManual {
            lines.append("Hanzi wurde von Hand geändert und wird nicht automatisch überschrieben.")
        }
        if model.pinyinIsManual {
            lines.append("Pinyin wurde von Hand geändert und wird nicht automatisch überschrieben.")
        }
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    private var tagSection: some View {
        Section {
            ForEach(allTags) { tag in
                Button {
                    model.toggle(tag)
                } label: {
                    HStack {
                        Text(tag.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if model.isSelected(tag) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }

            // Queued names are not tags yet — they are created when the card
            // is saved, so a cancelled editor leaves nothing behind.
            ForEach(model.pendingTagNames, id: \.self) { name in
                HStack {
                    Text(name)
                    Text("neu")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    Button {
                        model.removePendingTag(name)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("Kategorie \(name) entfernen")
                }
            }

            HStack {
                TextField("Neue Kategorie", text: $model.newTagName)
                Button("Hinzufügen") {
                    model.addNewTag(existingTags: allTags)
                }
                .disabled(model.canAddNewTag == false)
            }
        } header: {
            Text("Kategorien")
        } footer: {
            Text("Eine Karte kann mehreren Kategorien angehören. Groß- und Kleinschreibung erzeugt keine doppelten Kategorien. Neue Kategorien entstehen erst beim Speichern.")
        }
    }

    // MARK: - Chain triggers

    /// Return and "Fertig" only drop the focus, which closes the keyboard.
    /// The work then happens in `endEditing(of:)` via the focus change — one
    /// path for both gestures, so a keypress cannot start two translations.
    private func finishEditing() {
        focusedField = nil
    }

    private func endEditing(of field: Field) {
        switch field {
        case .german:
            if model.germanEditingEnded() {
                triggerTranslation()
            }
        case .hanzi:
            model.hanziEditingEnded()
        case .pinyin:
            model.pinyinEditingEnded()
        }
    }

    /// The refresh control next to the Hanzi field: deliberate permission to
    /// replace a hand-edited Hanzi and rebuild the Pinyin from it.
    private func retranslate() {
        model.prepareExplicitRetranslation()
        triggerTranslation()
    }

    /// Starts a translation run.
    ///
    /// `translationTask` re-runs whenever the configuration changes, so the
    /// first run needs a configuration and every later one an `invalidate()`.
    /// That modifier is also what asks the user for the language download, so
    /// there is only one path for both cases.
    ///
    /// Whether a run is wanted at all is decided by the model — by
    /// `germanEditingEnded()` for the automatic path and by
    /// `prepareExplicitRetranslation()` for the refresh control. Asking it
    /// again here would be wrong as well as redundant: the model has already
    /// recorded the text as requested, so a second opinion would say no and
    /// nothing would ever be translated.
    private func triggerTranslation() {
        let requiresLowLatency = model.translationSupport?.requiresLowLatencyStrategy ?? false

        if translationConfiguration == nil || configuredForLowLatency != requiresLowLatency {
            configuredForLowLatency = requiresLowLatency
            translationConfiguration = TranslationService.makeConfiguration(
                requiresLowLatencyStrategy: requiresLowLatency
            )
        } else {
            translationConfiguration?.invalidate()
        }
    }

    private func save() {
        // Tapping the toolbar does not reliably move the focus, so the model
        // settles its own state before writing — see `reconcileForSave()`.
        do {
            try model.save(into: context)
            dismiss()
        } catch let error as AppError {
            saveFailure = error
        } catch {
            // Nothing may stay half-written: the alert must not claim failure
            // while a later save silently commits the change anyway.
            context.rollback()
            saveFailure = .cardSaveFailed(error)
        }
    }
}
