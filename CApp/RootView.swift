//
//  RootView.swift
//  CApp
//

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
                    PlaceholderView(tab: tab)
                }
            }
        }
    }
}

/// Platzhalter für Phase 0. Wird in Phase 2 (Karten) und Phase 6 (Lernen)
/// durch die echten Ansichten ersetzt.
private struct PlaceholderView: View {
    let tab: AppTab

    var body: some View {
        ContentUnavailableView(
            tab.title,
            systemImage: tab.systemImage,
            description: Text("Inhalt folgt in einer späteren Phase.")
        )
    }
}

#Preview {
    RootView()
}
