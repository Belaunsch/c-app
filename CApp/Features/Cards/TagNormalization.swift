//
//  TagNormalization.swift
//  CApp
//

import Foundation

/// Keeps tag names free of accidental duplicates.
///
/// "Essen", "essen", "ESSEN" and " Essen " must all refer to the same tag.
/// Matching happens on a normalized key, while the tag keeps the spelling it
/// was first created with. There is deliberately no stored `normalizedName`
/// on the model: the number of tags is small, so comparing in memory is
/// simpler than a schema change plus migration.
enum TagNormalization {

    /// The key two tag names are compared by. Never shown to the user.
    static func key(for name: String) -> String {
        displayName(for: name).lowercased()
    }

    /// Longest accepted tag name.
    ///
    /// Without a limit a pasted paragraph becomes a category and wrecks
    /// every list it appears in. Written in phase 2, when deleting a tag was
    /// impossible and the damage would have been permanent; `TagManagement`
    /// can delete one since, so the limit is now about legibility rather
    /// than about being stuck with it.
    static let maximumLength = 40

    /// Characters that take up no space but are not whitespace either. Left
    /// in, they produce a category that looks empty and can never be
    /// identified again.
    private static let invisibles = CharacterSet(
        charactersIn: "\u{200B}\u{200C}\u{200D}\u{2060}\u{FEFF}"
    )

    /// The spelling stored on a newly created tag: invisible characters
    /// removed, trimmed, runs of whitespace collapsed into a single space.
    /// Casing is preserved so the user sees what they typed.
    static func displayName(for name: String) -> String {
        let visible = String(name.unicodeScalars.filter { invisibles.contains($0) == false })
        return visible
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Whether a name would produce a usable tag at all.
    static func isValid(_ name: String) -> Bool {
        let display = displayName(for: name)
        return display.isEmpty == false && display.count <= maximumLength
    }

    /// Why a rename was refused.
    enum RenameProblem: Equatable {
        /// Empty, whitespace only, or nothing but invisible characters.
        case invalid
        case tooLong
        /// Another tag already uses this name; the display name is carried
        /// along so the message can name it.
        case duplicate(existing: String)
    }

    /// Checks a rename before it happens. `nil` means it is allowed.
    ///
    /// Renaming a tag to a different spelling of *its own* name is fine —
    /// "Essen" to "essen" is the same tag re-spelled. Only a **different**
    /// tag holding that name blocks it, and it blocks rather than merges:
    /// merging tags is out of scope for phase 2, and silently folding two
    /// categories into one would rewrite the user's data behind their back.
    static func renameProblem(
        renaming tag: Tag,
        to newName: String,
        among tags: [Tag]
    ) -> RenameProblem? {
        let display = displayName(for: newName)
        guard display.isEmpty == false else { return .invalid }
        guard display.count <= maximumLength else { return .tooLong }

        let wanted = key(for: display)
        if let clash = tags.first(where: { $0 !== tag && key(for: $0.name) == wanted }) {
            return .duplicate(existing: clash.name)
        }
        return nil
    }

    /// Checks a name before any tag exists. `nil` means it is allowed.
    ///
    /// The same three rules as ``renameProblem(renaming:to:among:)`` —
    /// non-empty after normalisation, at most ``maximumLength``, and no
    /// other tag holding the key — minus the exemption that lets a tag keep
    /// its own name, which only means something once the tag exists. The
    /// problem type is shared with renaming rather than duplicated: the
    /// three ways a name can be refused are the same, and so are the
    /// sentences the user reads.
    static func creationProblem(name: String, among tags: [Tag]) -> RenameProblem? {
        let display = displayName(for: name)
        guard display.isEmpty == false else { return .invalid }
        guard display.count <= maximumLength else { return .tooLong }
        if let clash = existingTag(matching: display, in: tags) {
            return .duplicate(existing: clash.name)
        }
        return nil
    }

    /// Finds an existing tag with the same key, ignoring case and stray
    /// whitespace. Returns `nil` if the name is new.
    static func existingTag(matching name: String, in tags: [Tag]) -> Tag? {
        let wanted = key(for: name)
        guard wanted.isEmpty == false else { return nil }
        return tags.first { key(for: $0.name) == wanted }
    }
}
