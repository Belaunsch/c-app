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
/// `errorCount`, `accuracy` und `isNew`.
///
/// **Die Antwort-Historie gibt es seit Phase 11.** Der Satz „ein `ReviewLog`
/// wäre additiv nachrüstbar" stand hier seit Phase 1 als Vorhersage; sie hat
/// sich gehalten — ``reviews`` ist genau diese additive Erweiterung.
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

    /// The moment the learner last set this card's status by hand — and the
    /// line from which the assisted classification may read evidence.
    ///
    /// ## Why this needs its own field
    ///
    /// Checked against every existing property before it was added, because
    /// borrowing one would have been cheaper: `lastReviewedAt` moves on **every**
    /// review, so it would also exclude the fresh attempts that are supposed to
    /// count; `createdAt` never moves; the counters are counters; the two
    /// `…WasEditedManually` flags belong to the text and bending them would be
    /// exactly the reuse this project forbids. On `ReviewLog`, `previousStatus` is
    /// the field the case **fails** on: a card set back to *Mittel* by hand has
    /// old *Mittel*-era entries, which the same-status rule then finds comparable
    /// again (`docs/learning-engine.md` §13.13).
    ///
    /// ## What it is for
    ///
    /// A card that went *Mittel* → *Sicher* and is then corrected back to
    /// *Mittel* must not immediately be offered *Mittel* → *Gut* again from the
    /// reviews it collected the first time round. The correction is a statement,
    /// and evidence older than it cannot speak for the new status.
    ///
    /// **The history itself is never deleted.** This moves a line, it does not
    /// remove anything — the entries stay readable, and a later calibration can
    /// still see them.
    ///
    /// `nil` means the learner has never corrected this card, so all of its
    /// history is eligible. That is also the value every card written before this
    /// field existed reads back as, which is the only honest one.
    var classificationEvidenceResetAt: Date?
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

    /// Die Antwort-Historie dieser Karte (Phase 11).
    ///
    /// Die Löschregel ist `.cascade`, anders als bei `tags`: Ein `ReviewLog`
    /// beschreibt einen Versuch an **dieser** Karte und hat ohne sie keine
    /// Bedeutung. Eine gelöschte Karte nimmt ihre Historie also mit.
    ///
    /// Ungeordnet, wie jede SwiftData-Beziehung — die Sortierung nach
    /// `reviewedAt` macht die Feature-Schicht, bevor sie die Signale an die
    /// Engine reicht.
    @Relationship(deleteRule: .cascade, inverse: \ReviewLog.card)
    var reviews: [ReviewLog] = []

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
