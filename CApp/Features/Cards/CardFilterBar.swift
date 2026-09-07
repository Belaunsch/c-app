//
//  CardFilterBar.swift
//  CApp
//

import SwiftUI

/// Status and category filters for the card list.
///
/// Two menus rather than always-visible controls: the filters are used
/// occasionally, the list is used constantly, so the list gets the space.
struct CardFilterBar: View {
    let allTags: [Tag]
    @Binding var status: LearningStatus?
    @Binding var selectedTagKeys: Set<String>

    private var isFiltering: Bool {
        status != nil || selectedTagKeys.isEmpty == false
    }

    var body: some View {
        HStack(spacing: 12) {
            statusMenu
            if allTags.isEmpty == false {
                tagMenu
            }
            Spacer()
            if isFiltering {
                Button("Zurücksetzen") {
                    status = nil
                    selectedTagKeys = []
                }
                .font(.footnote)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var statusMenu: some View {
        Menu {
            Button {
                status = nil
            } label: {
                menuLabel("Alle", isChosen: status == nil)
            }
            Divider()
            ForEach(LearningStatus.allCases, id: \.self) { candidate in
                Button {
                    status = candidate
                } label: {
                    menuLabel(candidate.title, isChosen: status == candidate)
                }
            }
        } label: {
            filterLabel(
                title: status?.title ?? "Lernstatus",
                isActive: status != nil
            )
        }
    }

    private var tagMenu: some View {
        Menu {
            if selectedTagKeys.isEmpty == false {
                Button("Auswahl aufheben") { selectedTagKeys = [] }
                Divider()
            }
            ForEach(allTags) { tag in
                let key = TagNormalization.key(for: tag.name)
                Button {
                    if selectedTagKeys.contains(key) {
                        selectedTagKeys.remove(key)
                    } else {
                        selectedTagKeys.insert(key)
                    }
                } label: {
                    menuLabel(tag.name, isChosen: selectedTagKeys.contains(key))
                }
            }
        } label: {
            filterLabel(title: tagMenuTitle, isActive: selectedTagKeys.isEmpty == false)
        }
    }

    /// Names the selected categories while they still fit, so the user does
    /// not have to open the menu to see what is active.
    private var tagMenuTitle: String {
        let selected = allTags
            .filter { selectedTagKeys.contains(TagNormalization.key(for: $0.name)) }
            .map(\.name)

        switch selected.count {
        case 0: return "Kategorien"
        case 1: return selected[0]
        case 2: return selected.joined(separator: " + ")
        default: return "\(selected.count) Kategorien"
        }
    }

    /// A checkmark only when chosen. Passing an empty `systemImage` would ask
    /// for a non-existent SF Symbol.
    @ViewBuilder
    private func menuLabel(_ title: String, isChosen: Bool) -> some View {
        if isChosen {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private func filterLabel(title: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(isActive ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
        )
        .foregroundStyle(isActive ? Color.accentColor : Color.primary)
    }
}
