//
//  CAppApp.swift
//  CApp
//
//  Created by Philipp Bühler on 06.09.26.
//

import SwiftData
import SwiftUI

@main
struct CAppApp: App {
    /// Der Container wird beim Start aufgebaut. Ein Fehler wird nicht per
    /// `try!` in einen Absturz und nicht per stillem `catch` in einen
    /// unsichtbaren Datenverlust verwandelt, sondern angezeigt
    /// (`docs/architecture.md` §7).
    private let container: Result<ModelContainer, any Error>

    /// Genau **eine** Instanz für die Laufzeit der App, wie der Container.
    ///
    /// Sie muss so lange leben, weil `AVSpeechSynthesizer` vom System nicht
    /// gehalten wird — pro View einen zu erzeugen wäre der klassische Weg zu
    /// abgeschnittener Wiedergabe. Weitergegeben über die Environment, nicht
    /// als Singleton: Der Container fährt schon so, also braucht es kein
    /// zweites Muster und keinen DI-Container.
    @State private var speech = SpeechSynthesisService()

    init() {
        container = Result { try Self.makeModelContainer() }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                RootView()
                    .modelContainer(container)
                    .environment(speech)
            case .failure(let error):
                PersistenceErrorView(error: error)
            }
        }
    }
}

extension CAppApp {
    /// Das Schema der App.
    static var schema: Schema {
        Schema([Card.self, Tag.self])
    }

    /// Der produktive Datenspeicher: rein lokal, auf der Platte, ohne
    /// CloudKit, ohne Login, ohne Backend.
    ///
    /// **Migration (Task 1.6, offene Frage Q7):** Es gibt bewusst kein
    /// `VersionedSchema` und keinen `SchemaMigrationPlan`. Solange die
    /// Kartenmenge klein und die App privat ist, genügt die automatische
    /// leichtgewichtige Migration von SwiftData, die additive Änderungen
    /// (neue Properties mit Default, neue Modelle) selbst erledigt. Eine
    /// Migrationsinfrastruktur wird erst eingeführt, wenn eine konkrete
    /// Schemaänderung sie erzwingt — etwa das Umbenennen oder Entfernen einer
    /// Property oder eine Änderung an einer Beziehung.
    static func makeModelContainer() throws -> ModelContainer {
        try ModelContainer(for: schema)
    }
}

/// Letzte Reißleine, falls der lokale Datenspeicher nicht geöffnet werden
/// kann. Ohne Container gibt es nichts anzuzeigen, aber der Grund soll
/// sichtbar sein statt zu einem stummen Absturz zu führen.
private struct PersistenceErrorView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label("Daten nicht verfügbar", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Der lokale Datenspeicher konnte nicht geöffnet werden.\n\n\(error.localizedDescription)")
        }
    }
}
