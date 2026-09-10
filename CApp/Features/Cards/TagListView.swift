//
//  TagListView.swift
//  CApp
//

import SwiftData
import SwiftUI

/// Manages the stored categories: create, rename, delete.
///
/// Creating also happens in the card editor, where a category is needed
/// while writing a card and gets selected right away. Here it is the plain
/// case — a category without a card in mind — and it is the **primary**
/// entry: one `+` in the corner, where every iOS list puts it. The rules
/// behind both are the same and live in `TagNormalization`; only the outcome
/// differs, see `TagManagement.create`.
struct TagListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Tag.name)]) private var tags: [Tag]

    @State private var tagBeingRenamed: Tag?
    @State private var draftName = ""
    @State private var isCreating = false
    @State private var newName = ""
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newName = ""
                    isCreating = true
                } label: {
                    Label("Neue Kategorie", systemImage: "plus")
                }
            }
        }
        .alert("Neue Kategorie", isPresented: $isCreating) {
            TextField("Name", text: $newName)
            Button("Anlegen", action: commitCreate)
            Button("Abbrechen", role: .cancel) { newName = "" }
        } message: {
            Text("Groß- und Kleinschreibung erzeugt keine doppelten Kategorien.")
        }
        .overlay {
            if tags.isEmpty {
                ContentUnavailableView {
                    Label("Noch keine Kategorien", systemImage: "tag")
                } description: {
                    Text("Lege oben rechts eine an, oder sie entsteht beim Bearbeiten einer Karte.")
                } actions: {
                    Button("Kategorie anlegen") {
                        newName = ""
                        isCreating = true
                    }
                    .buttonStyle(.borderedProminent)
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

    /// Delegates to `TagManagement`, which delegates the rules to
    /// `TagNormalization` — the same chain the rename below uses, so a name
    /// this screen accepts is exactly a name the editor would accept.
    private func commitCreate() {
        do {
            try TagManagement.create(named: newName, among: tags, in: context)
            // Cleared only on success. A refused name — a duplicate, or one
            // over the limit — stays available, because the next thing the
            // user wants is to change it, not to type it again. Same
            // behaviour as `commitRename` below.
            newName = ""
        } catch let error as AppError {
            failure = error
        } catch {
            failure = .tagCreateFailed(error)
        }
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
