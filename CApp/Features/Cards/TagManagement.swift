//
//  TagManagement.swift
//  CApp
//

import Foundation
import SwiftData

/// Renaming and deleting stored categories.
///
/// These two live outside the view because renaming carries real rules —
/// normalization plus a duplicate check against every other tag — and both
/// touch the store irreversibly. Deleting a card, by contrast, is a plain
/// `delete` plus `save` with nothing to decide, so it stays in `CardListView`
/// rather than gaining an abstraction it does not need.
enum TagManagement {

    /// Renames the tag **in place**.
    ///
    /// Crucially it does not create a new tag and re-assign cards: the
    /// existing entity keeps its identity, so every `Card`↔`Tag` relationship
    /// survives untouched. Cards tagged "Restaurant" simply show
    /// "Essen gehen" afterwards.
    ///
    /// - Throws: `AppError.tagNameRejected` when the name is empty, too long
    ///   or already taken by another tag; `AppError.tagRenameFailed` when the
    ///   store refuses the write.
    static func rename(
        _ tag: Tag,
        to newName: String,
        among tags: [Tag],
        in context: ModelContext
    ) throws {
        if let problem = TagNormalization.renameProblem(renaming: tag, to: newName, among: tags) {
            throw AppError.tagNameRejected(problem)
        }

        let previousName = tag.name
        tag.name = TagNormalization.displayName(for: newName)

        do {
            try context.save()
        } catch {
            // Put the old name back and drop the pending change, so the alert
            // does not claim failure while the rename lingers in the context.
            tag.name = previousName
            context.rollback()
            throw AppError.tagRenameFailed(error)
        }
    }

    /// Deletes the tag. Cards keep existing and only lose the assignment —
    /// that is the `.nullify` delete rule from phase 1 doing its job.
    ///
    /// - Throws: `AppError.tagDeleteFailed` when the store refuses the write.
    static func delete(_ tag: Tag, in context: ModelContext) throws {
        context.delete(tag)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw AppError.tagDeleteFailed(error)
        }
    }
}
