//
//  AppError.swift
//  CApp
//

import Foundation

/// Errors the user gets to see.
///
/// Required by `CLAUDE.md` and `docs/architecture.md` §7: user-facing failures
/// go through this type rather than surfacing a raw `localizedDescription`,
/// which would be technical and, worse, English.
///
/// The technical text is not thrown away — it is appended as a second
/// paragraph, so a real defect stays diagnosable without a debugger.
enum AppError: Error {
    /// The editor was asked to save a card without German or Hanzi.
    case cardIncomplete
    case cardSaveFailed(any Error)
    case cardDeleteFailed(any Error)
    /// A tag rename was refused before it was attempted.
    case tagNameRejected(TagNormalization.RenameProblem)
    case tagCreateFailed(any Error)
    case tagRenameFailed(any Error)
    case tagDeleteFailed(any Error)

    /// Die Audio-Session ließ sich nicht starten. Blockiert nie etwas: Eine
    /// Karte bleibt ohne Ton lernbar.
    case speechUnavailable(any Error)

    /// Die Sprachmodelle sind nach dem Versuch immer noch nicht installiert.
    ///
    /// Trägt den gemessenen Status mit, weil „kein Wurf" bei Apples
    /// Asset-API nicht bedeutet, dass etwas installiert wurde — der Status
    /// ist die Quelle der Wahrheit, nicht das Ausbleiben eines Fehlers.
    case speechAssetsUnavailable(String)

    /// Reservierung oder Download sind fehlgeschlagen.
    case speechAssetsFailed(any Error)

    /// Aufnahme oder Erkennung sind fehlgeschlagen. Die Selbsteinschätzung
    /// bleibt davon unberührt benutzbar.
    case speechRecognitionFailed(any Error)

    /// Short, German, aimed at the user.
    var message: String {
        switch self {
        case .cardIncomplete:
            "Deutsch muss ausgefüllt sein, und das Hanzi-Feld braucht mindestens ein chinesisches Zeichen."
        case .cardSaveFailed:
            "Die Karte konnte nicht gespeichert werden. Es wurde nichts geändert."
        case .cardDeleteFailed:
            "Die Karte konnte nicht gelöscht werden. Sie ist weiterhin vorhanden."
        case .tagNameRejected(.invalid):
            "Der Name darf nicht leer sein."
        case .tagNameRejected(.tooLong):
            "Der Name ist zu lang. Erlaubt sind höchstens \(TagNormalization.maximumLength) Zeichen."
        case .tagNameRejected(.duplicate(let existing)):
            "Es gibt bereits die Kategorie „\(existing)“. Kategorien werden in dieser Version nicht zusammengeführt."
        case .tagCreateFailed:
            "Die Kategorie konnte nicht angelegt werden."
        case .tagRenameFailed:
            "Die Kategorie konnte nicht umbenannt werden. Der alte Name bleibt bestehen."
        case .speechUnavailable:
            "Die Aussprache konnte nicht abgespielt werden."
        case .speechAssetsUnavailable:
            "Das Sprachmodell für Chinesisch steht noch nicht bereit. Du kannst es später erneut versuchen."
        case .speechAssetsFailed:
            "Das Sprachmodell für Chinesisch konnte nicht geladen werden."
        case .speechRecognitionFailed:
            "Die Spracherkennung hat nicht funktioniert. Die Selbsteinschätzung geht weiterhin."
        case .tagDeleteFailed:
            "Die Kategorie konnte nicht gelöscht werden. Sie ist weiterhin vorhanden."
        }
    }

    /// The underlying system message, if there is one.
    var technicalDetail: String? {
        switch self {
        case .cardIncomplete, .tagNameRejected:
            nil
        case .speechAssetsUnavailable(let status):
            // Kein Fehlerobjekt, sondern der gemessene Zustand — und genau
            // der ist hier die nützliche technische Angabe. Als String
            // übergeben, damit `Support/` nicht das Speech-Framework in jede
            // Datei zieht, die einen Fehler anzeigt.
            "AssetInventory.status: \(status)"
        case .cardSaveFailed(let error),
             .cardDeleteFailed(let error),
             .tagCreateFailed(let error),
             .tagRenameFailed(let error),
             .tagDeleteFailed(let error),
             .speechUnavailable(let error),
             .speechAssetsFailed(let error),
             .speechRecognitionFailed(let error):
            error.localizedDescription
        }
    }

    /// What the alert shows.
    var userText: String {
        guard let technicalDetail else { return message }
        return "\(message)\n\n\(technicalDetail)"
    }
}
