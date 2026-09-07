//
//  CardEditorModel.swift
//  CApp
//

import Foundation
import SwiftData

/// Editing state for a single card, plus the rules that are worth testing on
/// their own: validation, tag deduplication and the manual-edit flags.
///
/// The view stays free of these decisions; it only binds to the properties.
@Observable
final class CardEditorModel {
    var type: CardType
    var german: String
    var hanzi: String
    var pinyin: String
    var status: LearningStatus
    var selectedTags: [Tag]

    /// Text of the "new tag" field. Not part of the card.
    var newTagName: String = ""

    /// Names the user typed that do not exist as a tag yet.
    ///
    /// They are deliberately **not** inserted into the context while editing.
    /// Otherwise a cancelled editor would leave the tag behind: the main
    /// context autosaves, and the app offers no way to delete a tag again, so
    /// a typo would become a permanent category.
    private(set) var pendingTagNames: [String] = []

    /// The card being edited, or `nil` when creating a new one.
    private let existingCard: Card?

    /// - Parameters:
    ///   - card: the card to edit, or `nil` to create a new one.
    ///   - type: preselected type for a new card, so the editor opens on
    ///     whatever the list is currently showing.
    init(card: Card? = nil, type: CardType = .word) {
        existingCard = card
        self.type = card?.type ?? type
        german = card?.german ?? ""
        hanzi = card?.hanzi ?? ""
        pinyin = card?.pinyin ?? ""
        status = card?.status ?? .new
        selectedTags = card?.tags ?? []
    }

    var isEditingExistingCard: Bool { existingCard != nil }

    // MARK: - Validation

    /// German and Hanzi are required, Pinyin is not. Whitespace does not count
    /// as content.
    var canSave: Bool {
        trimmedGerman.isEmpty == false && trimmedHanzi.isEmpty == false
    }

    var trimmedGerman: String { Self.trimmed(german) }
    var trimmedHanzi: String { Self.trimmed(hanzi) }
    var trimmedPinyin: String { Self.trimmed(pinyin) }

    // MARK: - Tags

    func isSelected(_ tag: Tag) -> Bool {
        selectedTags.contains { $0 === tag }
    }

    func toggle(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0 === tag }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }

    var canAddNewTag: Bool { TagNormalization.isValid(newTagName) }

    /// Takes the name from `newTagName`.
    ///
    /// An existing tag is selected instead of queueing a duplicate — that is
    /// what keeps "essen" from becoming a second "Essen". A genuinely new name
    /// is only remembered; it becomes a `Tag` when the card is saved.
    func addNewTag(existingTags: [Tag]) {
        let name = TagNormalization.displayName(for: newTagName)
        guard TagNormalization.isValid(name) else { return }

        if let match = TagNormalization.existingTag(matching: name, in: existingTags) {
            if isSelected(match) == false {
                selectedTags.append(match)
            }
        } else if isPending(name) == false {
            pendingTagNames.append(name)
        }
        newTagName = ""
    }

    func isPending(_ name: String) -> Bool {
        let key = TagNormalization.key(for: name)
        return pendingTagNames.contains { TagNormalization.key(for: $0) == key }
    }

    func removePendingTag(_ name: String) {
        pendingTagNames.removeAll { $0 == name }
    }

    /// Turns the queued names into tags, reusing anything that exists by now.
    private func resolveTags(in context: ModelContext) throws -> [Tag] {
        guard pendingTagNames.isEmpty == false else { return selectedTags }

        let storedTags = try context.fetch(FetchDescriptor<Tag>())
        var resolved = selectedTags

        for name in pendingTagNames {
            if let existing = TagNormalization.existingTag(matching: name, in: storedTags + resolved) {
                if resolved.contains(where: { $0 === existing }) == false {
                    resolved.append(existing)
                }
            } else {
                let tag = Tag(name: name)
                context.insert(tag)
                resolved.append(tag)
            }
        }
        return resolved
    }

    // MARK: - Saving

    /// Writes the card.
    ///
    /// Throws `AppError.cardIncomplete` rather than returning silently, so a
    /// mis-wired caller cannot mistake "nothing happened" for success.
    func save(into context: ModelContext) throws {
        guard canSave else { throw AppError.cardIncomplete }
        let tags = try resolveTags(in: context)

        if let card = existingCard {
            // The flags must be decided before the new values overwrite the
            // stored ones — they compare against what is currently saved.
            card.hanziWasEditedManually = Self.manualEditFlag(
                previous: card.hanzi,
                new: trimmedHanzi,
                wasManual: card.hanziWasEditedManually
            )
            card.pinyinWasEditedManually = Self.manualEditFlag(
                previous: card.pinyin,
                new: trimmedPinyin,
                wasManual: card.pinyinWasEditedManually
            )

            card.type = type
            card.german = trimmedGerman
            card.hanzi = trimmedHanzi
            card.pinyin = trimmedPinyin
            card.status = status
            card.tags = tags
        } else {
            let card = Card(
                type: type,
                german: trimmedGerman,
                hanzi: trimmedHanzi,
                pinyin: trimmedPinyin,
                status: status,
                hanziWasEditedManually: Self.manualEditFlag(
                    previous: "",
                    new: trimmedHanzi,
                    wasManual: false
                ),
                pinyinWasEditedManually: Self.manualEditFlag(
                    previous: "",
                    new: trimmedPinyin,
                    wasManual: false
                ),
                tags: tags
            )
            context.insert(card)
        }

        try context.save()
    }

    // MARK: - Manual-edit flags

    /// Decides whether a field counts as manually edited.
    ///
    /// The flag exists so the automation coming in phases 3 and 4 never
    /// overwrites something the user typed (`docs/architecture.md`, decision
    /// A8). Hence:
    ///
    /// - an empty new value clears the flag — there is nothing to protect, and
    ///   the automation may fill the field;
    /// - a changed, non-empty value sets it — the user just typed this;
    /// - an unchanged value leaves it alone, so merely reopening and saving a
    ///   card does not silently mark it as hand-edited.
    ///
    /// For a new card `previous` is empty, which makes any typed value count
    /// as manual — correct, because in phase 2 there is no automation that
    /// could have produced it.
    static func manualEditFlag(previous: String, new: String, wasManual: Bool) -> Bool {
        if new.isEmpty { return false }
        if new != previous { return true }
        return wasManual
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
