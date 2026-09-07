//
//  Card.swift
//  CApp
//

import Foundation
import SwiftData

/// Eine Lernkarte.
///
/// Persistiert werden ausschließlich die in `docs/architecture.md` §3 als
/// „persistiert" geführten Werte. Bewusst **nicht** gespeichert und deshalb
/// hier nicht vorhanden: `weight` (reine Funktion aus `status`),
/// `errorCount`, `accuracy` und `isNew`. Ebenso gibt es keine
/// Antwort-Historie — ein `ReviewLog` wäre additiv nachrüstbar.
///
/// Alle Properties haben einen Default. Das ist Konvention (Task 1.9) und hält
/// eine spätere CloudKit-Option offen, ohne heute etwas zu kosten.
@Model
final class Card {
    /// Stabile Identität zusätzlich zur `PersistentIdentifier` von SwiftData.
    /// Grund: Import und Export sollen Karten später wiedererkennen können.
    var id: UUID = UUID()

    /// Der gespeicherte RawValue von ``type``.
    ///
    /// SwiftData speichert Codable-Enums zwar korrekt, kann sie aber **nicht**
    /// in einem `#Predicate` vergleichen — ein Filter auf einen `CardType`
    /// scheitert zur Laufzeit mit
    /// `SwiftDataError.unsupportedPredicate` („Captured/constant values of
    /// type 'CardType' are not supported"). In Phase 1 gemessen, siehe
    /// `docs/architecture.md` §3.
    ///
    /// Deshalb liegt der RawValue im Store. Prädikate und `@Query` filtern auf
    /// diese Property, gelesen und geschrieben wird über ``type``.
    private(set) var typeRaw: String = CardType.word.rawValue

    /// Der gespeicherte RawValue von ``status`` — gleiche Begründung wie
    /// ``typeRaw``.
    private(set) var statusRaw: Int = LearningStatus.new.rawValue

    /// Wort oder Satz. Liegt als ``typeRaw`` im Store.
    var type: CardType {
        get {
            guard let type = CardType(rawValue: typeRaw) else {
                // Nur durch DB-Manipulation oder ein Downgrade nach einem neuen
                // Case erreichbar. Im Entwicklungsbuild soll das auffallen
                // statt still zu „Wort" zu werden.
                assertionFailure("Unbekannter CardType-RawValue: \(typeRaw)")
                return .word
            }
            return type
        }
        set { typeRaw = newValue.rawValue }
    }

    /// Der Kenntnisstand. Liegt als ``statusRaw`` im Store.
    var status: LearningStatus {
        get {
            guard let status = LearningStatus(rawValue: statusRaw) else {
                // Wie bei `type`: ein stiller Rückfall auf „neu" würde echten
                // Lernfortschritt verschlucken.
                assertionFailure("Unbekannter LearningStatus-RawValue: \(statusRaw)")
                return .new
            }
            return status
        }
        set { statusRaw = newValue.rawValue }
    }

    var german: String = ""
    var hanzi: String = ""
    var pinyin: String = ""

    var createdAt: Date = Date()
    var lastReviewedAt: Date?
    var reviewCount: Int = 0
    var correctCount: Int = 0

    /// Merker, damit die Automatik aus Phase 3 (Pinyin) und Phase 4
    /// (Übersetzung) manuell korrigierte Werte niemals überschreibt
    /// (`docs/architecture.md`, Entscheidung A8).
    var hanziWasEditedManually: Bool = false
    var pinyinWasEditedManually: Bool = false

    /// Many-to-many zu `Tag`. Die Löschregel ist `.nullify`: Eine gelöschte
    /// Karte nimmt keinen Tag mit, es verschwindet nur die Zuordnung.
    /// Die Inverse wird nur auf dieser Seite deklariert.
    @Relationship(deleteRule: .nullify, inverse: \Tag.cards)
    var tags: [Tag] = []

    init(
        id: UUID = UUID(),
        type: CardType,
        german: String,
        hanzi: String,
        pinyin: String = "",
        status: LearningStatus = .new,
        createdAt: Date = Date(),
        lastReviewedAt: Date? = nil,
        reviewCount: Int = 0,
        correctCount: Int = 0,
        hanziWasEditedManually: Bool = false,
        pinyinWasEditedManually: Bool = false,
        tags: [Tag] = []
    ) {
        self.id = id
        self.type = type
        self.german = german
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.status = status
        self.createdAt = createdAt
        self.lastReviewedAt = lastReviewedAt
        self.reviewCount = reviewCount
        self.correctCount = correctCount
        self.hanziWasEditedManually = hanziWasEditedManually
        self.pinyinWasEditedManually = pinyinWasEditedManually
        self.tags = tags
    }
}
