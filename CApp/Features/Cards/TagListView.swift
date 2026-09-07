//
//  TagListView.swift
//  CApp
//

import SwiftData
import SwiftUI

/// Manages the stored categories: rename and delete, nothing more.
///
/// Creating a category still happens where it is needed — in the card editor.
/// This screen exists because without it a typo would be permanent.
struct TagListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Tag.name)]) private var tags: [Tag]

    @State private var tagBeingRenamed: Tag?
    @State private var draftName = ""
    @State private var tagPendingDeletion: Tag?
    @State private var failure: AppError?

    var body: some View {
        List {
            ForEach(tags) { tag in
                Button {
                    tagBeingRenamed = tag
                    draftName = tag.name
                } label: {
                    HStack {
                        Text(tag.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(usageText(for: tag))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button("Löschen", role: .destructive) {
                        tagPendingDeletion = tag
                    }
                }
            }
        }
        .navigationTitle("Kategorien")
        .overlay {
            if tags.isEmpty {
                ContentUnavailableView {
                    Label("Noch keine Kategorien", systemImage: "tag")
                } description: {
                    Text("Kategorien entstehen beim Anlegen oder Bearbeiten einer Karte.")
                }
            }
        }
        .alert("Kategorie umbenennen", isPresented: isRenaming) {
            TextField("Name", text: $draftName)
            Button("Speichern", action: commitRename)
            Button("Abbrechen", role: .cancel) { tagBeingRenamed = nil }
        } message: {
            Text("Alle zugeordneten Karten übernehmen den neuen Namen.")
        }
        .confirmationDialog(
            "Kategorie löschen?",
            isPresented: isDeleting,
            titleVisibility: .visible,
            presenting: tagPendingDeletion
        ) { tag in
            Button("Löschen", role: .destructive) { confirmDelete(tag) }
            Button("Abbrechen", role: .cancel) { tagPendingDeletion = nil }
        } message: { tag in
            Text("„\(tag.name)“ wird von \(usageText(for: tag)) verwendet. Die Karten bleiben erhalten und verlieren nur diese Kategorie.")
        }
        .alert(
            "Kategorie",
            isPresented: Binding(
                get: { failure != nil },
                set: { if $0 == false { failure = nil } }
            ),
            presenting: failure
        ) { _ in
            Button("OK", role: .cancel) { failure = nil }
        } message: { failure in
            Text(failure.userText)
        }
    }

    private var isRenaming: Binding<Bool> {
        Binding(
            get: { tagBeingRenamed != nil },
            set: { if $0 == false { tagBeingRenamed = nil } }
        )
    }

    private var isDeleting: Binding<Bool> {
        Binding(
            get: { tagPendingDeletion != nil },
            set: { if $0 == false { tagPendingDeletion = nil } }
        )
    }

    private func usageText(for tag: Tag) -> String {
        let count = tag.cards.count
        return count == 1 ? "1 Karte" : "\(count) Karten"
    }

    private func commitRename() {
        guard let tag = tagBeingRenamed else { return }
        tagBeingRenamed = nil
        do {
            try TagManagement.rename(tag, to: draftName, among: tags, in: context)
        } catch let error as AppError {
            failure = error
        } catch {
            failure = .tagRenameFailed(error)
        }
    }

    private func confirmDelete(_ tag: Tag) {
        tagPendingDeletion = nil
        do {
            try TagManagement.delete(tag, in: context)
        } catch let error as AppError {
            failure = error
        } catch {
            failure = .tagDeleteFailed(error)
        }
    }
}
