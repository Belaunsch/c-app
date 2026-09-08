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
    }
}

#if DEBUG
#Preview {
    // `CardListView` uses `@Query`, so the preview needs a container. This is
    // what `SampleData` was built for in phase 1.
    if let container = try? SampleData.makePreviewContainer() {
        RootView()
            .modelContainer(container)
    } else {
        Text("Vorschaudaten nicht verfügbar")
    }
}
#endif
