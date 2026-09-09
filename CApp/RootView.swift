//
//  RootView.swift
//  CApp
//

import SwiftData
import SwiftUI

/// Die Tabs der Bottom Navigation.
///
/// Bewusst genau zwei. Die Einstellungen bekommen keinen eigenen Tab, sondern
/// werden später über einen Button in der Kartenübersicht erreicht — siehe
/// `docs/architecture.md`, Entscheidung A6.
///
/// `nonisolated`, weil das App-Target `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
/// setzt. Ohne die Annotation wäre die `Equatable`-Konformität an den Main-Actor
/// gebunden und im Test nicht nutzbar — im Swift-6-Sprachmodus ein Fehler.
/// Die modulweite Entscheidung dazu ist Q8 in `docs/apple-frameworks.md`.
nonisolated enum AppTab: CaseIterable, Hashable {
    case learn
    case cards

    var title: String {
        switch self {
        case .learn: "Lernen"
        case .cards: "Karten"
        }
    }

    var systemImage: String {
        switch self {
        case .learn: "graduationcap"
        case .cards: "rectangle.stack"
        }
    }
}

/// Das Navigationsgerüst der App.
struct RootView: View {
    @Environment(SpeechSynthesisService.self) private var speech

    /// Der Hinweis auf eine fehlende chinesische Stimme, einmal pro App-Lauf.
    ///
    /// Hier statt in jedem der drei Bildschirme mit Speaker: Ein Hinweis, ein
    /// Ort. Gezeigt wird er beim Erscheinen, also bevor der Nutzer den
    /// fehlenden Knopf sucht — der Preis ist, dass er kommt, noch ehe jemand
    /// Ton wollte. Das ist die bessere Richtung: Der Knopf ist unsichtbar,
    /// und ohne Erklärung wäre unklar, warum.
    ///
    /// **`@State`, nicht `let`** — und das ist der ganze Punkt an dieser
    /// Property: Ein View ist ein Wert und wird beliebig oft neu gebaut.
    /// Als `let` entstünde bei jeder Rekonstruktion eine frische Notice mit
    /// zurückgesetztem Flag, und „einmal pro App-Lauf" hielte nur so lange,
    /// wie die Elternebene zufällig nichts neu auswertet. `@State` bindet
    /// die Instanz an die **Identität** des Views: Der Initialisierer eines
    /// späteren Aufbaus wird verworfen, die erste Notice bleibt. Für eine
    /// Referenz ohne `@Observable` ist das die passende Semantik —
    /// `@StateObject` verlangt `ObservableObject`, das dieser Typ nicht ist
    /// und nicht braucht, weil niemand auf ihn hin neu zeichnet.
    @State private var missingVoice = MissingVoiceNotice()

    /// Treibt den Alert. Liegt hier statt in der Notice, weil SwiftUI
    /// `@State` beim Lesen in `body` ohne Einschränkung verfolgt.
    @State private var showsMissingVoiceNotice = false

    var body: some View {
        TabView {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.systemImage) {
                    switch tab {
                    case .learn:
                        SessionSetupView()
                    case .cards:
                        CardListView()
                    }
                }
            }
        }
        .onAppear {
            // Erst nachsehen, dann urteilen: Der Nutzer kann die Stimme
            // zwischen zwei Starts nachgeladen haben.
            speech.refreshVoice()
            noticeIfUnavailable()
        }
        // Auch mitten im Betrieb: Löscht der Nutzer die letzte chinesische
        // Stimme, meldet das System es, `voice` wird `nil` und die Knöpfe
        // verschwinden. Ohne diesen Zweig blieben sie unerklärt weg.
        .onChange(of: speech.isAvailable) { _, _ in
            noticeIfUnavailable()
        }
        .alert("Keine chinesische Stimme", isPresented: $showsMissingVoiceNotice) {
            Button("OK") {}
        } message: {
            Text(MissingVoiceNotice.message)
        }
        .alert(
            "Aussprache nicht möglich",
            isPresented: Binding(
                get: { speech.failure != nil },
                set: { if $0 == false { speech.failure = nil } }
            ),
            presenting: speech.failure
        ) { _ in
            Button("OK") { speech.failure = nil }
        } message: { failure in
            Text(failure.message)
        }
    }

    private func noticeIfUnavailable() {
        guard RootView.shouldNotice(isAvailable: speech.isAvailable),
              missingVoice.shouldShow() else { return }
        showsMissingVoiceNotice = true
    }

    /// Whether the missing-voice notice is due. Its own function so the rule
    /// is testable — the audit found this branch had never executed, and
    /// pinning `isAvailable` to `true` broke no test.
    static func shouldNotice(isAvailable: Bool) -> Bool {
        isAvailable == false
    }
}

#if DEBUG
#Preview {
    // `CardListView` uses `@Query`, so the preview needs a container. This is
    // what `SampleData` was built for in phase 1.
    if let container = try? SampleData.makePreviewContainer() {
        RootView()
            .modelContainer(container)
            .environment(SpeechSynthesisService())
    } else {
        Text("Vorschaudaten nicht verfügbar")
    }
}
#endif
