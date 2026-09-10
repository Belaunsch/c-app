//
//  CardListView.swift
//  CApp
//

import SwiftData
import SwiftUI

/// The card overview: words and sentences kept apart, searchable, filterable
/// by category and learning status, sortable, and folded down to one line per
/// card until the user asks for more.
///
/// The `@Query` deliberately carries no dynamic predicate. It fetches
/// everything sorted, `CardFilter` narrows it and `CardListArrangement`
/// orders and groups it — all in plain Swift, see the reasoning in
/// `CardFilter`.
///
/// ## The accordion, and why the tap targets are laid out this way
///
/// A row shows only the German text collapsed; Hanzi, Pinyin and categories
/// appear when it is expanded. At most one card is open, which
/// `CardExpansion` guarantees by answering with a single optional.
///
/// Three separate things can be tapped in one row, and phase 6 cost two
/// device-test rounds on exactly this kind of arrangement (A27). So the rule
/// applied here is the one that survived: **three sibling buttons, no
/// container gesture, no `simultaneousGesture`, no hit-test trickery.**
///
/// - the row body is a `Button` whose only job is expand and collapse
/// - the speaker is its sibling and only speaks
/// - the pencil is its sibling and only opens the editor
///
/// Their **order** matters as much as their separation — see `controls(for:)`.
///
/// A tap on the open row means collapse, nothing else. The editor is reached
/// **only** through the visible pencil — no second tap, no long press, no
/// hidden affordance.
struct CardListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Card.german)]) private var allCards: [Card]
    @Query(sort: [SortDescriptor(\Tag.name)]) private var allTags: [Tag]

    @State private var type: CardType = .word
    @State private var searchText = ""
    @State private var filter = CardFilterSelection()

    /// The sort order, kept in `UserDefaults` so it survives a tab switch,
    /// the app going to the background and a relaunch. Stored as the raw
    /// string rather than as the enum, so that an unknown or outdated value
    /// can fall back through `CardSortOrder.restored(from:)` instead of
    /// being a decoding problem — see there.
    @AppStorage(CardSortOrder.storageKey)
    private var storedSortOrder = CardSortOrder.default.rawValue

    private var sortOrder: CardSortOrder {
        CardSortOrder.restored(from: storedSortOrder)
    }

    /// The picker writes the raw value, and reads go through the same
    /// fallback as everything else.
    private var sortOrderSelection: Binding<CardSortOrder> {
        Binding(
            get: { CardSortOrder.restored(from: storedSortOrder) },
            set: { storedSortOrder = $0.rawValue }
        )
    }

    /// Which card is open, or none. Purely a view concern and deliberately
    /// not persisted: reopening the app should show a quiet list, not
    /// whatever was unfolded three days ago.
    @State private var expandedCardID: Card.ID?

    @State private var isShowingFilterSheet = false
    @State private var isShowingNewCardSheet = false
    @State private var cardBeingEdited: Card?
    @State private var cardPendingDeletion: Card?
    @State private var deleteFailure: AppError?

    /// Every card of the current type, ignoring search and filters. Used to
    /// tell "nothing created yet" apart from "filtered everything away".
    private var cardsOfCurrentType: [Card] {
        allCards.filter { $0.type == type }
    }

    private var visibleCards: [Card] {
        CardListArrangement.sort(
            CardFilter.apply(
                to: allCards,
                type: type,
                searchText: searchText,
                tagKeys: filter.tagKeys,
                status: filter.status
            ),
            by: sortOrder
        )
    }

    private var sections: [CardSection] {
        CardListArrangement.sections(visibleCards, selectedTagKeys: filter.tagKeys)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controlBar
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
                // Filter and sorting moved down to the control bar, so this
                // placement now holds one thing and the plus keeps the corner
                // it always had.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingNewCardSheet = true
                    } label: {
                        Label("Neue Karte", systemImage: "plus")
                    }
                }
            }
            // A push, as before. The pencil replaces the row tap as the way
            // in; what happens after is the editor's business and unchanged.
            .navigationDestination(item: $cardBeingEdited) { card in
                CardEditorView(card: card)
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

    // MARK: - Control bar

    /// Type on the left, filter and sorting on the right — one row, because
    /// all three answer the same question: what is in this list?
    private var controlBar: some View {
        HStack(spacing: 12) {
            Picker("Kartentyp", selection: $type) {
                ForEach(CardType.allCases, id: \.self) { candidate in
                    Text(candidate.title).tag(candidate)
                }
            }
            .pickerStyle(.segmented)

            Button {
                isShowingFilterSheet = true
            } label: {
                // The 44 pt and the shape sit **inside** the label, which is
                // what a button's tap area is made of. Wrapped around the
                // button instead, they only reserve layout space and leave
                // the touchable region at the ~22 pt glyph — the mistake
                // this used to make. These controls came from a
                // `ToolbarItemGroup`, which grants the minimum for free;
                // down here in a plain `HStack` nothing does.
                Label("Filter", systemImage: filterSymbol)
                    .labelStyle(.iconOnly)
                    // The font stays on the symbol rather than on the row:
                    // the segmented picker reads the environment font too,
                    // and `.title3` there makes "Wörter | Sätze" bigger than
                    // the navigation title.
                    .font(.title3)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(filterAccessibilityLabel)

            Menu {
                // An inline `Picker` inside a `Menu` is the platform's own
                // way to show which option is active — it draws the
                // checkmark itself, so nothing here has to track it.
                Picker("Sortieren", selection: sortOrderSelection) {
                    ForEach(CardSortOrder.allCases) { order in
                        Label(order.title, systemImage: order.symbolName)
                            .tag(order)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Sortieren", systemImage: "arrow.up.arrow.down")
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Sortieren: \(sortOrder.title)")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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

    // MARK: - The list

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
                    Text("Keine Karte passt zu Suche und Filter. Bei mehreren Kategorien genügt **eine** davon.")
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
                if sortOrder.isGrouped {
                    ForEach(sections) { section in
                        Section(section.title) {
                            ForEach(section.cards) { card in
                                row(for: card)
                            }
                        }
                    }
                } else {
                    ForEach(visibleCards) { card in
                        row(for: card)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    /// One row: the tappable body plus the controls, as siblings.
    ///
    /// The split is the point — see the type's documentation on A27.
    @ViewBuilder
    private func row(for card: Card) -> some View {
        let isExpanded = expandedCardID == card.id

        HStack(alignment: .top, spacing: 8) {
            Button {
                // **No animation, deliberately.** Two rounds on the device
                // said the same thing: the Hanzi, Pinyin and category lines
                // arrived on their own schedule and the German text above
                // them twitched as the row resized. That is not a badly
                // chosen curve — a `List` animates the new rows as
                // insertions while the height interpolates separately, and
                // the two are not one movement however short they are made.
                //
                // So there is no `.animation` on the list any more, and the
                // change is wrapped in a transaction that carries none
                // either: without it the implicit animation of the
                // surrounding context still reaches the row. Folding is
                // instant, which is what a row that folds should be. No
                // `matchedGeometryEffect`, no custom transition — the fix
                // for "the animation looks wrong" is no animation.
                withTransaction(Transaction(animation: nil)) {
                    expandedCardID = CardExpansion.toggled(expandedCardID, tapped: card.id)
                }
            } label: {
                rowBody(for: card, isExpanded: isExpanded)
            }
            // `.plain` so the text keeps looking like text and the row does
            // not turn into a tinted button. Without a button style the whole
            // list row would become the control and the siblings next to it
            // would stop receiving taps.
            .buttonStyle(.plain)
            // As a `NavigationLink` the row explained itself. As a button
            // that folds, it has to say so — otherwise VoiceOver announces
            // "Apfel, Taste" and the user has no way to know what it does.
            .accessibilityHint(isExpanded ? "Zuklappen" : "Aufklappen, zeigt Hanzi und Pinyin")

            controls(for: card, isExpanded: isExpanded)
        }
        .swipeActions(edge: .trailing) {
            Button("Löschen", role: .destructive) {
                cardPendingDeletion = card
            }
        }
    }

    /// German always; the rest only when the card is open.
    ///
    /// Collapsed the German text is held to a single line. A sentence card
    /// would otherwise make the row four lines tall, which is what made the
    /// list too tall to scan in the first place — truncating is the cheaper
    /// loss, because the full text is one tap away.
    @ViewBuilder
    private func rowBody(for card: Card, isExpanded: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(card.status.indicatorColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
                .accessibilityLabel("Lernstatus: \(card.status.title)")

            VStack(alignment: .leading, spacing: 2) {
                Text(card.german)
                    .font(.body)
                    .lineLimit(isExpanded ? nil : 1)
                    .truncationMode(.tail)

                if isExpanded {
                    Text(card.hanzi)
                        .font(.title3)

                    if card.pinyin.isEmpty == false {
                        Text(card.pinyin)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if card.tags.isEmpty == false {
                        Text(card.tags.map(\.name).sorted().joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Claims the leftover width for the tap area, so tapping the empty
            // space right of a short word folds the row too. A shape, not a
            // gesture — it changes where this button is, not who wins a tap.
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    /// Speaker always, pencil only while the row is open.
    ///
    /// The speaker stays visible collapsed, because hearing a card is the
    /// one thing worth doing without unfolding it. The pencil appears with
    /// the details: editing a card the user cannot currently see would be a
    /// guess.
    ///
    /// **The pencil goes first, the speaker last** — and that order is the
    /// whole safety of this row. Written the other way round, the speaker
    /// would sit at the trailing edge collapsed and get pushed left by about
    /// a finger's width when the row opens, while the pencil takes over the
    /// spot the speaker just occupied. Tapping where the speaker had been
    /// would then open the editor. This is the same class of mistake as A27
    /// and none of its usual remedies apply: nothing is competing for the
    /// tap, the tap simply lands on the wrong control. So the fix is
    /// layout order. The control that is always there never moves, and the
    /// one that appears does so in space that was empty.
    @ViewBuilder
    private func controls(for card: Card, isExpanded: Bool) -> some View {
        HStack(spacing: 16) {
            if isExpanded {
                Button {
                    cardBeingEdited = card
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Karte bearbeiten")
            }

            SpeakButton(hanzi: card.hanzi)
        }
        .font(.title3)
        .foregroundStyle(.tint)
        .padding(.top, 2)
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
