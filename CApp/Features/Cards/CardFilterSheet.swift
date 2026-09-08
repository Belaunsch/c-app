//
//  CardFilterSheet.swift
//  CApp
//

import SwiftUI

/// Status and category filters, on a sheet behind one toolbar button.
///
/// They used to sit permanently above the list as two menu chips. The list is
/// what the screen is for, so the filters gave the space back — the toolbar
/// icon says whether any of them are active.
struct CardFilterSheet: View {
    let allTags: [Tag]
    @Binding var selection: CardFilterSelection

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Lernstatus") {
                    Picker("Lernstatus", selection: $selection.status) {
                        Text("Alle").tag(LearningStatus?.none)
                        ForEach(LearningStatus.allCases, id: \.self) { candidate in
                            Text(candidate.title).tag(Optional(candidate))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if allTags.isEmpty == false {
                    Section {
                        ForEach(allTags) { tag in
                            let key = TagNormalization.key(for: tag.name)
                            Button {
                                selection.toggle(tagKey: key)
                            } label: {
                                HStack {
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selection.tagKeys.contains(key) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Kategorien")
                    } footer: {
                        if selection.tagKeys.count > 1 {
                            Text("Eine Karte muss **allen** ausgewählten Kategorien angehören.")
                        }
                    }
                }

                if selection.hasActiveFilters {
                    Section {
                        Button("Filter zurücksetzen", role: .destructive) {
                            selection.reset()
                        }
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
