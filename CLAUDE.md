# Arbeitsanweisungen für die Entwicklung mit Claude

## Was das hier ist

Private, native iOS-App zum Lernen von Mandarin-Chinesisch (Lernkarten).
Swift, SwiftUI, SwiftData, keine externen Dependencies, kein Backend,
local-first.

**Aktueller Stand: Planungsphase. Es existiert noch kein App-Code.**

## Vor jeder Änderung lesen

| Frage | Dokument |
| --- | --- |
| Was ist als Nächstes zu tun? | [docs/roadmap.md](docs/roadmap.md) |
| Wo gehört mein Code hin? | [docs/architecture.md](docs/architecture.md) |
| Wie funktioniert die Lernlogik genau? | [docs/learning-engine.md](docs/learning-engine.md) |
| Ab welcher iOS-Version gibt es diese API? Was ist unklar? | [docs/apple-frameworks.md](docs/apple-frameworks.md) |

## Harte Regeln

1. **Eine Phase auf einmal.** Der Umfang steht in der Roadmap. Nichts aus
   einer späteren Phase vorziehen — auch nicht „weil es gerade schnell geht“.
2. **Keine externen Dependencies.** Kein Swift Package, kein CocoaPods, kein
   Carthage. Wenn etwas ohne Paket nicht lösbar erscheint, erst fragen.
3. **Keine Repository-Layer, keine DI-Container, keine Coordinator, kein
   Drittanbieter-State-Management.** Begründung in
   [architecture.md §1](docs/architecture.md#1-schichten).
4. **`Learning/` importiert nur `Foundation`.** Kein SwiftUI, kein SwiftData.
5. **Automatik blockiert nie.** Übersetzung und Pinyin sind Vorschläge.
   Eine Karte muss sich immer speichern lassen, auch wenn beides fehlschlägt.
   Manuell geänderte Werte werden nie automatisch überschrieben.
6. **Keine Gamification.** Keine Streaks, Herzen, Timer, Tageslimits,
   Punktzahlen. Auch nicht „nur als kleines Extra“.
7. **Keine Aussprachebewertung behaupten.** Der Vergleich in Version 1 ist
   rein textuell. Kein Score, keine Prozentangabe, kein Ton-Feedback.
8. **Keine Analytics, keine Telemetrie, kein Crash-Reporting, kein Login,
   kein Server.**
9. **Unsicherheiten dokumentieren statt raten.** Offene technische Fragen
   gehören als Q-Eintrag in
   [apple-frameworks.md §10](docs/apple-frameworks.md#10-offene-technische-fragen-zu-klären-vor-der-jeweiligen-phase).
10. **Am Ende jeder Phase:** Akzeptanzkriterien durchgehen, Tests laufen
    lassen, auf dem echten Gerät prüfen. Erst dann die nächste Phase.

## Konventionen

- **Code, Typnamen und Kommentare auf Englisch** (Swift-üblich).
- **Alle nutzersichtbaren Texte auf Deutsch.**
- Deployment Target **iOS 26.0**, nur iPhone, Portrait.
- Fehlerbehandlung: kein `try!`, keine leeren `catch {}`. Für
  nutzersichtbare Fehler `AppError` in `Support/` verwenden.
- Tests für alles unter `Learning/` und für `PinyinService` sind Pflicht,
  nicht optional.

## Build und Test

Entwickelt wird in VS Code, gebaut und auf dem Gerät gestartet wird mit Xcode.

```bash
xcodebuild -scheme CApp -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme CApp -destination 'platform=iOS Simulator,name=iPhone 17' test
```

**Voraussetzung einmalig:** Die Xcode-Lizenz muss akzeptiert sein, sonst
verweigern `git` und `xcodebuild` den Dienst:

```bash
sudo xcodebuild -license accept
```

Neue Dateien werden in VS Code angelegt; durch die *synchronisierten Ordner*
(Xcode 16+) landen sie automatisch im Target — `project.pbxproj` muss nicht
angefasst werden.
