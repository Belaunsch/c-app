//
//  SessionSetupView.swift
//  CApp
//

import SwiftData
import SwiftUI

/// What to practise: words or sentences, and optionally only certain
/// categories.
///
/// Deliberately the same shape as the card list — a compact centred title
/// with the controls in the toolbar — so the two tabs do not look like two
/// different apps. The categories moved into that toolbar filter as well;
/// they were a permanently visible list for a choice that is made rarely.
///
/// There is no direction control. Mode A, German to Chinese, is the only one
/// that exists, and a picker with one option is a promise with nothing behind
/// it. Phase 8 brings the second direction, and with it a reason for a
/// picker.
struct SessionSetupView: View {
    @Query(sort: [SortDescriptor(\Tag.name)]) private var allTags: [Tag]

    /// Observed rather than fetched on demand. A `context.fetch` inside
    /// `body` is a read SwiftUI does not know about, so adding the first card
    /// elsewhere would not re-evaluate this view and the start button would
    /// stay disabled — exactly the first-use path. Filtering happens in
    /// Swift, the way the card list does it (A11).
    @Query(sort: [SortDescriptor(\Card.german)]) private var allCards: [Card]

    @State private var cardType: CardType = .word
    @State private var tagKeys: Set<String> = []

    /// A plain flag rather than `navigationDestination(item:)`, which would
    /// require `SessionConfiguration` to be `Hashable`. Adding a conformance
    /// to `Learning/` for a navigation detail is the wrong direction: the
    /// engine layer should not grow because of the UI. The setup is not
    /// visible while the session is pushed, so the configuration cannot
    /// change underneath it.
    @State private var isSessionRunning = false
    @State private var isShowingFilterSheet = false
    @State private var isShowingNewCardSheet = false

    private var configuration: SessionConfiguration {
        SessionConfiguration(cardType: cardType, tagKeys: activeTagKeys)
    }

    /// The selected keys that still have a category behind them — the rule
    /// itself sits in `LearnSessionModel`, where it can be tested. Found by
    /// the review; it predates the ODER change, which only made it less
    /// painful.
    private var activeTagKeys: Set<String> {
        LearnSessionModel.activeTagKeys(tagKeys, among: allTags)
    }

    /// How many cards the current selection would practise.
    ///
    /// The same rule the session itself uses — `LearnSessionModel.poolCards`
    /// — so the count and the pool can never disagree.
    private var availableCount: Int {
        LearnSessionModel.poolCards(from: allCards, configuration: configuration).count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Picker("Kartentyp", selection: $cardType) {
                    ForEach(CardType.allCases, id: \.self) { candidate in
                        Text(candidate.title).tag(candidate)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if availableCount == 0 {
                    emptyState
                } else {
                    start
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Lernen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingFilterSheet = true
                    } label: {
                        Label("Filter", systemImage: filterSymbol)
                    }
                    .accessibilityLabel(filterAccessibilityLabel)
                }
            }
            .navigationDestination(isPresented: $isSessionRunning) {
                LearnSessionView(configuration: configuration)
            }
            .sheet(isPresented: $isShowingFilterSheet) {
                SessionFilterSheet(allTags: allTags, tagKeys: $tagKeys)
            }
            .sheet(isPresented: $isShowingNewCardSheet) {
                NavigationStack {
                    // The card type the user just chose, so the new card
                    // lands in the pool they were about to practise.
                    CardEditorView(type: cardType)
                }
            }
        }
    }

    private var start: some View {
        VStack(spacing: 8) {
            Button("Session starten") { isSessionRunning = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

            Text(
                availableCount == 1
                    ? "Eine Karte steht zur Auswahl. Die Session läuft, bis du sie beendest."
                    : "\(availableCount) Karten stehen zur Auswahl. Die Session läuft, bis du sie beendest."
            )
            .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Keine passenden Karten", systemImage: "rectangle.stack.badge.questionmark")
        } description: {
            // Blaming the filter is only honest if lifting it would help.
            // With sentences only and "Wörter" chosen, the categories are
            // not the reason and saying so would send the user looking in
            // the wrong place.
            Text(
                isEmptyBecauseOfCategories
                    ? "Keine Karte gehört zu einer der gewählten Kategorien."
                    : "Zum Lernen braucht eine Karte deutschen und chinesischen Text."
            )
        } actions: {
            Button("Karte anlegen") { isShowingNewCardSheet = true }
                .buttonStyle(.borderedProminent)
        }
    }

    /// Whether the categories are what emptied the pool — as opposed to
    /// there being nothing of this type to learn in the first place.
    private var isEmptyBecauseOfCategories: Bool {
        guard activeTagKeys.isEmpty == false else { return false }
        return LearnSessionModel.poolCards(
            from: allCards,
            configuration: SessionConfiguration(cardType: cardType)
        ).isEmpty == false
    }

    /// A filled icon while a category filter is active, the same signal the
    /// card list uses.
    private var filterSymbol: String {
        activeTagKeys.isEmpty
            ? "line.3.horizontal.decrease.circle"
            : "line.3.horizontal.decrease.circle.fill"
    }

    private var filterAccessibilityLabel: String {
        switch activeTagKeys.count {
        case 0: "Filter"
        case 1: "Filter, eine Kategorie aktiv"
        case let count: "Filter, \(count) Kategorien aktiv"
        }
    }
}

/// The categories to practise, on a sheet behind the toolbar button.
///
/// Only categories: a learning-status filter would let the user pick which
/// cards to see by how well they know them, and choosing what to practise is
/// the weighting's job (`docs/learning-engine.md` §3).
///
/// A tap toggles, and that is the only interaction. There is no "clear
/// selection" button — with one filter group, deselecting the last category
/// *is* clearing it, and a second control for the same thing only raises the
/// question of how the two differ.
private struct SessionFilterSheet: View {
    let allTags: [Tag]
    @Binding var tagKeys: Set<String>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if allTags.isEmpty {
                    ContentUnavailableView(
                        "Keine Kategorien",
                        systemImage: "tag",
                        description: Text("Kategorien entstehen beim Anlegen einer Karte.")
                    )
                } else {
                    Section {
                        ForEach(allTags) { tag in
                            let key = TagNormalization.key(for: tag.name)
                            Button {
                                if tagKeys.contains(key) {
                                    tagKeys.remove(key)
                                } else {
                                    tagKeys.insert(key)
                                }
                            } label: {
                                HStack {
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if tagKeys.contains(key) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Kategorien")
                    } footer: {
                        if tagKeys.count > 1 {
                            Text("Geübt wird alles aus **einer** der ausgewählten Kategorien.")
                        } else if tagKeys.isEmpty {
                            Text("Ohne Auswahl werden alle Karten des gewählten Typs geübt.")
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
