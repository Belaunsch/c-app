//
//  CardSnapshot.swift
//  CApp
//

import Foundation

/// What the engine needs to know about a card — and nothing else.
///
/// The engine never sees a `Card`. The feature layer maps its SwiftData
/// objects onto snapshots, hands them in, and writes the results back; that
/// mapping is not part of this layer. Two fields are enough, because
/// weighting depends on the status and everything after selection works on
/// the id alone.
///
/// Deliberately without the card's text: the queue holds ids, so a card
/// edited during a session shows its new content the next time it appears
/// (`docs/learning-engine.md` §9) without the engine knowing anything about
/// it.
nonisolated struct CardSnapshot: Equatable, Hashable, Sendable {
    let id: UUID
    let status: LearningStatus

    init(id: UUID, status: LearningStatus) {
        self.id = id
        self.status = status
    }
}
