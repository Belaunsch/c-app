//
//  LearningStatus.swift
//  CApp
//

import Foundation

/// Der Kenntnisstand einer Karte.
///
/// Die Reihenfolge ist bedeutungstragend: Der `rawValue` ist die Stufe auf der
/// Leiter, die die Statusübergänge in `docs/learning-engine.md` §6 verwenden,
/// und `Comparable` erlaubt Vergleiche wie `status < .good`.
///
/// `nonisolated` ist hier nicht Kosmetik: Das App-Target setzt
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Ohne die Annotation wird der
/// `<`-Operator main-actor-isoliert, und genau ihn braucht `Learning/`
/// (Phase 5) aus nonisolated Code — gemessen: „call to main actor-isolated
/// operator function '<' in a synchronous nonisolated context", im
/// Swift-6-Sprachmodus ein Fehler. Siehe Q8 in `docs/apple-frameworks.md`.
///
/// Die Basisgewichtung pro Stufe gehört bewusst **nicht** hierher, sondern in
/// `Learning/CardWeighting.swift` (Phase 5) — das Gewicht ist ein abgeleiteter
/// Wert und wird nicht persistiert (`docs/architecture.md` §3).
nonisolated enum LearningStatus: Int, Codable, CaseIterable, Comparable, Sendable {
    case new = 0
    case weak = 1
    case medium = 2
    case good = 3
    case secure = 4

    static func < (lhs: LearningStatus, rhs: LearningStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
