//
//  ReviewLog.swift
//  CApp
//

import Foundation
import SwiftData

/// Ein abgeschlossener Versuch an einer Karte.
///
/// Seit Phase 1 stand im Datenmodell, es gebe **keine** Antwort-Historie und
/// ein `ReviewLog` wäre additiv nachrüstbar. Phase 11 ist der Punkt, an dem
/// er gebraucht wird: Ohne Historie gibt es keine Evidenz, und ohne Evidenz
/// keinen Vorschlag.
///
/// ## Was hier steht und was ausdrücklich nicht
///
/// Gespeichert wird genau das, was die Roadmap für die Rekonstruktion einer
/// Lernentscheidung verlangt — nicht mehr. Zwei dieser Felder liest die
/// heutige Regel **nicht**: `direction` und `previousStatus` werden
/// aufgezeichnet, weil Modus A und B verschiedene Fragen stellen und weil die
/// Ausgangslage eines Versuchs später gebraucht wird, sobald die Formel an
/// echter Historie kalibriert wird. Sie stehen hier als Anforderung der
/// Roadmap, nicht als Vorrat. Nicht gespeichert
/// werden **Rohaudio, Erkennungs-Konfidenz, Zeitdauern, Aussprache- oder
/// Tonwerte**. Keiner dieser Werte wurde je gemessen (harte Regel 7), und ein
/// Feld, das es gibt, wird irgendwann benutzt.
///
/// Auch der erkannte Text selbst liegt hier nicht: Für die Entscheidung zählt
/// allein, ob er nach der Normalisierung mit dem Hanzi übereinstimmte. Den
/// Wortlaut zu behalten wäre eine Sammlung gesprochener Äußerungen ohne
/// Zweck.
///
/// Alle Properties haben einen Default — Konvention aus Task 1.9 und
/// Voraussetzung der leichtgewichtigen Migration.
@Model
final class ReviewLog {

    /// Stabile Identität zusätzlich zur `PersistentIdentifier`, wie bei
    /// `Card` und aus demselben Grund.
    var id: UUID = UUID()

    /// Wann der Versuch abgeschlossen wurde. Die zeitliche Ordnung der
    /// Evidenz hängt daran.
    var reviewedAt: Date = Date()

    /// RawValue von ``direction`` — dieselbe Begründung wie bei `Card.typeRaw`:
    /// SwiftData kann Codable-Enums nicht in einem `#Predicate` vergleichen.
    private(set) var directionRaw: String = SessionDirection.germanToChinese.rawValue

    /// RawValue von ``previousStatus``.
    private(set) var previousStatusRaw: Int = LearningStatus.new.rawValue

    /// RawValue von ``assessment``. `nil` heißt: Die App ist von selbst
    /// weitergegangen, es gab keine Bewertung.
    private(set) var assessmentRaw: String?

    /// Ob das Mikrofon überhaupt benutzt wurde.
    var usedSpeech: Bool = false

    /// Ob Apples finaler Text nach der Normalisierung dem gespeicherten Hanzi
    /// entsprach. `nil`, wenn nicht gesprochen wurde.
    ///
    /// **Eine Aussage über zwei Texte.** Nicht über die Aussprache, nicht
    /// über Töne, nicht über Richtigkeit der Antwort.
    var speechMatched: Bool?

    /// Ob die Antwort ohne Versuch aufgedeckt wurde.
    var wasManualReveal: Bool = false

    /// Ob es ein Wiederholungsversuch an derselben Karte innerhalb eines
    /// Mini-Batches war.
    var wasRetry: Bool = false

    /// Die Karte. Die Gegenrichtung steht auf `Card.reviews` mit
    /// `.cascade`: Eine gelöschte Karte nimmt ihre Historie mit, denn ohne
    /// die Karte beschreibt sie nichts mehr.
    var card: Card?

    /// Die Abfragerichtung. Liegt als ``directionRaw`` im Store.
    var direction: SessionDirection {
        get {
            guard let direction = SessionDirection(rawValue: directionRaw) else {
                assertionFailure("Unbekannter SessionDirection-RawValue: \(directionRaw)")
                return .germanToChinese
            }
            return direction
        }
        set { directionRaw = newValue.rawValue }
    }

    /// Der Status **vor** diesem Versuch. Liegt als ``previousStatusRaw`` im
    /// Store.
    var previousStatus: LearningStatus {
        get {
            guard let status = LearningStatus(rawValue: previousStatusRaw) else {
                assertionFailure("Unbekannter LearningStatus-RawValue: \(previousStatusRaw)")
                return .new
            }
            return status
        }
        set { previousStatusRaw = newValue.rawValue }
    }

    /// Die abgegebene Selbsteinschätzung, oder `nil` bei einem automatisch
    /// weitergereichten Versuch.
    var assessment: SelfAssessment? {
        get {
            guard let assessmentRaw else { return nil }
            guard let assessment = SelfAssessment(rawValue: assessmentRaw) else {
                assertionFailure("Unbekannter SelfAssessment-RawValue: \(assessmentRaw)")
                return nil
            }
            return assessment
        }
        set { assessmentRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        reviewedAt: Date = Date(),
        direction: SessionDirection = .germanToChinese,
        previousStatus: LearningStatus = .new,
        usedSpeech: Bool = false,
        speechMatched: Bool? = nil,
        wasManualReveal: Bool = false,
        wasRetry: Bool = false,
        assessment: SelfAssessment? = nil,
        card: Card? = nil
    ) {
        self.id = id
        self.reviewedAt = reviewedAt
        self.direction = direction
        self.previousStatus = previousStatus
        self.usedSpeech = usedSpeech
        self.speechMatched = speechMatched
        self.wasManualReveal = wasManualReveal
        self.wasRetry = wasRetry
        self.assessment = assessment
        self.card = card
    }

    /// Der Eintrag als reiner Wert für die Engine.
    ///
    /// `Learning/` sieht niemals ein `@Model` — dieselbe Trennung wie
    /// `Card` → `CardSnapshot`.
    var signal: ReviewSignal {
        ReviewSignal(
            direction: direction,
            previousStatus: previousStatus,
            usedSpeech: usedSpeech,
            speechMatched: speechMatched,
            wasManualReveal: wasManualReveal,
            wasRetry: wasRetry,
            assessment: assessment
        )
    }
}
