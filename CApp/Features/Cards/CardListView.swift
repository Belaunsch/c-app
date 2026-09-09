//
//  CardListView.swift
//  CApp
//

import SwiftData
import SwiftUI

/// The card overview: words and sentences kept apart, searchable, filterable
/// by category and learning status.
///
/// The `@Query` deliberately carries no dynamic predicate. It fetches
/// everything sorted, and `CardFilter` narrows it in plain Swift — see the
/// reasoning in `CardFilter`.
struct CardListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Card.german)]) private var allCards: [Card]
    @Query(sort: [SortDescriptor(\Tag.name)]) private var allTags: [Tag]

    @State private var type: CardType = .word
    @State private var searchText = ""
    @State private var filter = CardFilterSelection()
    @State private var isShowingFilterSheet = false
    @State private var isShowingNewCardSheet = false
    @State private var cardPendingDeletion: Card?
    @State private var deleteFailure: AppError?

    /// Every card of the current type, ignoring search and filters. Used to
    /// tell "nothing created yet" apart from "filtered everything away".
    private var cardsOfCurrentType: [Card] {
        allCards.filter { $0.type == type }
    }

    private var visibleCards: [Card] {
        CardFilter.apply(
            to: allCards,
            type: type,
            searchText: searchText,
            tagKeys: filter.tagKeys,
            status: filter.status
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Kartentyp", selection: $type) {
                    ForEach(CardType.allCases, id: \.self) { candidate in
                        Text(candidate.title).tag(candidate)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                content
            }
            .navigationTitle("Karten")
            .navigationBarTitleDisplayMode(.inline)
            // Keeps the search field under the navigation bar instead of
            // letting it collapse into the toolbar, so the order on screen
            // stays: title, search, words/sentences, list.
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Deutsch, Hanzi oder Pinyin"
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        TagListView()
                    } label: {
                        Label("Kategorien verwalten", systemImage: "tag")
                    }
                    .accessibilityLabel("Kategorien verwalten")
                }
                // One group, one placement: with two items in different
                // placements the order on screen follows SwiftUI's placement
                // priority rather than the declaration.
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isShowingFilterSheet = true
                    } label: {
                        Label("Filter", systemImage: filterSymbol)
                    }
                    .accessibilityLabel(filterAccessibilityLabel)

                    Button {
                        isShowingNewCardSheet = true
                    } label: {
                        Label("Neue Karte", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingFilterSheet) {
                CardFilterSheet(allTags: allTags, selection: $filter)
            }
            .sheet(isPresented: $isShowingNewCardSheet) {
                NavigationStack {
                    CardEditorView(type: type)
                }
            }
            .confirmationDialog(
                "Karte löschen?",
                isPresented: Binding(
                    get: { cardPendingDeletion != nil },
                    set: { if $0 == false { cardPendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: cardPendingDeletion
            ) { card in
                Button("Löschen", role: .destructive) { delete(card) }
                Button("Abbrechen", role: .cancel) { cardPendingDeletion = nil }
            } message: { card in
                Text("\(card.german) wird endgültig gelöscht. Zugewiesene Kategorien bleiben erhalten.")
            }
            .alert(
                "Löschen fehlgeschlagen",
                isPresented: Binding(
                    get: { deleteFailure != nil },
                    set: { if $0 == false { deleteFailure = nil } }
                ),
                presenting: deleteFailure
            ) { _ in
                Button("OK", role: .cancel) { deleteFailure = nil }
            } message: { failure in
                Text(failure.userText)
            }
        }
    }

    /// A filled icon while anything is filtered — the native way to say
    /// "there is something behind this button" without a badge.
    private var filterSymbol: String {
        filter.hasActiveFilters
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
    }

    /// Spoken out, because the filled icon alone is invisible to VoiceOver.
    private var filterAccessibilityLabel: String {
        switch filter.activeGroupCount {
        case 0: return "Filter"
        case 1: return "Filter, 1 aktiv"
        default: return "Filter, \(filter.activeGroupCount) aktiv"
        }
    }

    @ViewBuilder
    private var content: some View {
        if cardsOfCurrentType.isEmpty {
            ContentUnavailableView {
                Label("Noch keine \(type.title)", systemImage: "rectangle.stack.badge.plus")
            } description: {
                Text("Lege deine erste Karte an, um loszulegen.")
            } actions: {
                Button("Karte anlegen") { isShowingNewCardSheet = true }
                    .buttonStyle(.borderedProminent)
            }
        } else if visibleCards.isEmpty {
            ContentUnavailableView {
                Label("Keine Treffer", systemImage: "magnifyingglass")
            } description: {
                if filter.tagKeys.count > 1 {
                    Text("Keine Karte passt zu Suche und Filter. Bei mehreren Kategorien müssen **alle** zutreffen.")
                } else {
                    Text("Keine Karte passt zu Suche und Filter.")
                }
            } actions: {
                Button("Filter zurücksetzen") {
                    searchText = ""
                    filter.reset()
                }
            }
        } else {
            List {
                ForEach(visibleCards) { card in
                    // The speaker sits **beside** the link, not inside its
                    // label. Inside, the row's navigation would take the tap
                    // and the button would never fire — the phase-6 lesson
                    // from A27, applied instead of rediscovered. Two
                    // siblings, two tap areas, no gesture of our own.
                    HStack(spacing: 8) {
                        NavigationLink {
                            CardEditorView(card: card)
                        } label: {
                            CardRow(card: card)
                        }

                        SpeakButton(hanzi: card.hanzi)
                            .font(.title3)
                            .foregroundStyle(.tint)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Löschen", role: .destructive) {
                            cardPendingDeletion = card
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func delete(_ card: Card) {
        cardPendingDeletion = nil
        context.delete(card)
        do {
            try context.save()
        } catch {
            // Undo the pending deletion, otherwise the list shows the card as
            // gone while the alert says it failed — and the next successful
            // save anywhere would commit it after all.
            context.rollback()
            deleteFailure = .cardDeleteFailed(error)
        }
    }
}

/// One row: Hanzi first, then Pinyin, then the German meaning — the same
/// reading order the learner uses on a card.
private struct CardRow: View {
    let card: Card

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(card.status.indicatorColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
                .accessibilityLabel("Lernstatus: \(card.status.title)")

            VStack(alignment: .leading, spacing: 2) {
                Text(card.hanzi)
                    .font(.title3)
                if card.pinyin.isEmpty == false {
                    Text(card.pinyin)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(card.german)
                    .font(.body)
                if card.tags.isEmpty == false {
                    Text(card.tags.map(\.name).sorted().joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
