//
//  CardType.swift
//  CApp
//

import Foundation

/// Unterscheidet Wortkarten von Satzkarten.
///
/// `nonisolated`, weil das App-Target `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
/// setzt und `Learning/` (Phase 5) diesen Typ aus nonisolated Code verwenden
/// muss. Ohne die Annotation wären die synthetisierten Konformitäten an den
/// Main-Actor gebunden. Siehe Q8 in `docs/apple-frameworks.md`.
///
/// Die Trennung ist fachlich hart: Beide Typen sind getrennt filterbar und
/// werden in einer Lernsession nie gemischt.
nonisolated enum CardType: String, Codable, CaseIterable, Sendable {
    case word
    case sentence
}
