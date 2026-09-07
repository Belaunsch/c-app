//
//  CardEditorView.swift
//  CApp
//

import SwiftData
import SwiftUI

/// Creates or edits one card. Everything is typed by hand — the automatic
/// translation and Pinyin generation arrive in phases 3 and 4.
struct CardEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Tag.name)]) private var allTags: [Tag]

    @State private var model: CardEditorModel
    @State private var saveFailure: AppError?

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

            Section("Deutsch") {
                TextField("Deutscher Text", text: $model.german, axis: .vertical)
            }

            Section {
                TextField("Hanzi", text: $model.hanzi, axis: .vertical)
                TextField("Pinyin (optional)", text: $model.pinyin, axis: .vertical)
                    .autocorrectionDisabled()
            } header: {
                Text("Chinesisch")
            } footer: {
                Text("Deutsch und Hanzi sind erforderlich. Pinyin kann leer bleiben.")
            }

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

    private func save() {
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
