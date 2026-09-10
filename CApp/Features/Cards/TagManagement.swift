//
//  TagManagement.swift
//  CApp
//

import Foundation
import SwiftData

/// Creating, renaming and deleting stored categories.
///
/// These live outside the view because each carries real rules —
/// normalization plus a duplicate check against every other tag — and all
/// touch the store irreversibly. Deleting a card, by contrast, is a plain
/// `delete` plus `save` with nothing to decide, so it stays in `CardListView`
/// rather than gaining an abstraction it does not need.
enum TagManagement {

    /// Creates a category from a typed name.
    ///
    /// The rules are not restated here: normalisation, the length limit and
    /// the duplicate check all come from `TagNormalization`, the same source
    /// the rename path and the card editor use. What differs between the two
    /// creation call sites is only what happens **afterwards** — the editor
    /// selects the new category for the card being written and therefore
    /// treats an existing name as "select that one instead", while this
    /// screen creates nothing but the category and says so when the name is
    /// already taken. That is a difference in outcome, not in rules, which is
    /// why the editor's `addNewTag` keeps its own path rather than being bent
    /// into this one.
    ///
    /// - Throws: `AppError.tagNameRejected` when the name is empty, too long
    ///   or already taken; `AppError.tagCreateFailed` when the store refuses
    ///   the write.
    @discardableResult
    static func create(
        named name: String,
        among tags: [Tag],
        in context: ModelContext
    ) throws -> Tag {
        if let problem = TagNormalization.creationProblem(name: name, among: tags) {
            throw AppError.tagNameRejected(problem)
        }

        let tag = Tag(name: TagNormalization.displayName(for: name))
        context.insert(tag)
        do {
            try context.save()
        } catch {
            // Nothing half-created: without the rollback the category would
            // exist in memory, be assignable, and vanish on the next launch.
            context.rollback()
            throw AppError.tagCreateFailed(error)
        }
        return tag
    }

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
