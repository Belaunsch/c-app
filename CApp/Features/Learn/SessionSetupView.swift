//
//  SessionSetupView.swift
//  CApp
//

import SwiftData
import SwiftUI

/// What to practise: words or sentences, and which categories.
///
/// ## Why the categories are on the screen and not behind a filter button
///
/// They used to sit in a toolbar sheet labelled "Filter", the same control
/// the card list has. That framing was wrong in a way that showed on the
/// device: in the card list a filter is administrative — it hides rows from
/// a list that exists either way. Here the categories **are** the choice.
/// "Was übe ich jetzt?" is the entire question this screen asks, and the
/// answer belonged behind a funnel icon that says "something is hidden".
///
/// So the order on screen is now the order of the decision: card type,
/// categories, start. Nothing is behind a sheet, because there are only two
/// things to decide.
///
/// Deliberately **not** here: creating, renaming or deleting a category, and
/// any filter on learning status. The first belongs to the category
/// management screen — see `LearnCategorySelection` for why. The second would
/// let the user pick cards by how well they already know them, which is the
/// weighting's job (`docs/learning-engine.md` §3).
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
    @State private var tagKeys = LearnCategorySelection.everything

    /// A plain flag rather than `navigationDestination(item:)`, which would
    /// require `SessionConfiguration` to be `Hashable`. Adding a conformance
    /// to `Learning/` for a navigation detail is the wrong direction: the
    /// engine layer should not grow because of the UI. The setup is not
    /// visible while the session is pushed, so the configuration cannot
    /// change underneath it.
    @State private var isSessionRunning = false
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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Kartentyp", selection: $cardType) {
                        ForEach(CardType.allCases, id: \.self) { candidate in
                            Text(candidate.title).tag(candidate)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    categories
                }
                .padding()
            }
            // Pinned, so the start button stays reachable however many
            // categories there are — the grid scrolls, the decision does not
            // move.
            .safeAreaInset(edge: .bottom) { footer }
            .navigationTitle("Lernen")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $isSessionRunning) {
                LearnSessionView(configuration: configuration)
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

    // MARK: - Categories

    @ViewBuilder
    private var categories: some View {
        if allTags.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                Text("Kategorien")
                    .font(.headline)

                // An adaptive grid rather than a list: the names are short,
                // a list of them would fill the screen for a choice made in
                // two taps, and the grid keeps many categories readable by
                // wrapping instead of by scrolling past the start button.
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    // Every chip reads `activeTagKeys`, not `tagKeys`, and
                    // that difference is the whole point. `tagKeys` can hold
                    // a category the user deleted in the management screen
                    // while this screen kept its `@State` across a tab
                    // switch. The pool and the footer already ignore such a
                    // key; asking the chips about the raw set instead would
                    // light **nothing** — no Alle, and no chip for a
                    // category that no longer exists — while the session
                    // starts unrestricted. That is exactly the second
                    // "nothing is chosen" state this design exists to
                    // prevent, arriving through the view rather than the
                    // model. One screen, one set.
                    chip(
                        title: "Alle",
                        isSelected: LearnCategorySelection.isEverything(activeTagKeys)
                    ) {
                        tagKeys = LearnCategorySelection.everything
                    }

                    ForEach(allTags) { tag in
                        let key = TagNormalization.key(for: tag.name)
                        chip(title: tag.name, isSelected: activeTagKeys.contains(key)) {
                            tagKeys = LearnCategorySelection.toggled(activeTagKeys, key: key)
                        }
                    }
                }

                Text(selectionExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// One category, selected or not.
    ///
    /// The two states are two button styles rather than a tint or a
    /// checkmark: `.borderedProminent` against `.bordered` is the platform's
    /// own "this one is chosen", it survives dark mode and Dynamic Type
    /// without anything to maintain, and it stays visible at a glance across
    /// a grid — which a checkmark at the trailing edge does not.
    @ViewBuilder
    private func chip(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        // Two lines, not one: `TagNormalization.maximumLength` allows 40
        // characters and a 104 pt column fits about ten, so "Redewendungen
        // Essen" and "Redewendungen Reisen" would both read "Redewendun…" —
        // two chips nobody can tell apart, one of them lit. The grid row
        // grows instead.
        let label = Text(title)
            .lineLimit(2)
            .frame(maxWidth: .infinity)

        if isSelected {
            Button(action: action) { label }
                .buttonStyle(.borderedProminent)
                .accessibilityAddTraits(.isSelected)
        } else {
            Button(action: action) { label }
                .buttonStyle(.bordered)
        }
    }

    /// Says what the current selection means, so the union is never
    /// something the user has to infer from a card count.
    ///
    /// The plural case used to read "Geübt wird alles aus **einer** der
    /// ausgewählten Kategorien" — accurate about the rule and misleading
    /// about the outcome, because it sounds like only one of the ticked
    /// categories is used. It is the union: every card from every selected
    /// category, and a card in two of them still appears once.
    private var selectionExplanation: String {
        switch activeTagKeys.count {
        case 0: "Alle Karten des gewählten Typs."
        case 1: "Geübt wird alles aus dieser Kategorie."
        default: "Geübt werden alle Karten aus den ausgewählten Kategorien."
        }
    }

    // MARK: - Start

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 8) {
            if availableCount == 0 {
                Text(emptyExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Karte anlegen") { isShowingNewCardSheet = true }
                    .buttonStyle(.borderedProminent)
            } else {
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
        .padding()
        .background(.bar)
    }

    /// Blaming the categories is only honest if changing them would help.
    /// With sentences only and "Wörter" chosen, they are not the reason, and
    /// saying so would send the user looking in the wrong place.
    private var emptyExplanation: String {
        isEmptyBecauseOfCategories
            ? "Keine Karte gehört zu einer der gewählten Kategorien."
            : "Zum Lernen braucht eine Karte deutschen und chinesischen Text."
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
}
