# Arbeitsanweisungen für die Entwicklung mit Claude

## Was das hier ist

Private, native iOS-App zum Lernen von Mandarin-Chinesisch (Lernkarten).
Swift, SwiftUI, SwiftData, keine externen Dependencies, kein Backend,
local-first.

**Aktueller Stand: Phase 1 (Datenmodell & Persistenz) ist abgeschlossen** —
SwiftData-Modelle für Karten und Tags, lokaler `ModelContainer`,
DEBUG-Beispieldaten, Build und Tests grün, Gerätetest bestanden. Es gibt noch
keine Karten-UI und keine Fachlogik: Karten lassen sich in der App noch nicht
anlegen. **Nächster Schritt ist Phase 2 (Kartenverwaltung).**

## Vor jeder Änderung lesen

| Frage | Dokument |
| --- | --- |
| Was ist als Nächstes zu tun? | [docs/roadmap.md](docs/roadmap.md) |
| Wo gehört mein Code hin? | [docs/architecture.md](docs/architecture.md) |
| Wie funktioniert die Lernlogik genau? | [docs/learning-engine.md](docs/learning-engine.md) |
| Ab welcher iOS-Version gibt es diese API? Was ist unklar? | [docs/apple-frameworks.md](docs/apple-frameworks.md) |
| Wie arbeiten wir, wer darf was? | [docs/claude-workflow.md](docs/claude-workflow.md) |

## Routing

| Aufgabe | Weg |
| --- | --- |
| Normale Feature-Implementierung | Skill `/implement-phase` |
| Abschlussprüfung einer Phase | Skill `/verify-phase` |
| Apple-API- oder Verfügbarkeitsfrage | Skill `/apple-api-spike`, für Einzelfragen Subagent `apple-api-researcher` |
| Unabhängiges Code Review | Subagent `code-reviewer` |
| Unabhängige Test- und Acceptance-Prüfung | Subagent `test-auditor` |

Produktivcode schreibt **immer der Hauptagent**, nie ein Subagent. Die drei
Subagenten prüfen und recherchieren; sie ändern keine Dateien. Details und
Begründung in [docs/claude-workflow.md](docs/claude-workflow.md).

## Harte Regeln

1. **Eine Phase auf einmal.** Der Umfang steht in der Roadmap. Nichts aus
   einer späteren Phase vorziehen — auch nicht „weil es gerade schnell geht“.
2. **Keine externen Dependencies.** Kein Swift Package, kein CocoaPods, kein
   Carthage. Wenn etwas ohne Paket nicht lösbar erscheint, erst fragen.
3. **Keine Repository-Layer, keine DI-Container, keine Coordinator, kein
   Drittanbieter-State-Management.** Begründung in
   [architecture.md §1](docs/architecture.md#1-schichten).
4. **`Learning/` importiert nur `Foundation`.** Kein SwiftUI, kein SwiftData.
   Detailregeln der Schicht: `.claude/rules/learning-layer.md` (lädt
   automatisch beim Arbeiten an diesen Dateien).
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
    lassen, Review durchführen lassen, auf dem echten Gerät prüfen. Ein
    grüner Testlauf allein ist kein Phasenabschluss. Vollständiges
    Phase-Gate: [docs/claude-workflow.md §5](docs/claude-workflow.md#5-phase-gate).
    Erst danach die nächste Phase.

## Konventionen

- **Swift-Code, Typnamen und Code-Kommentare auf Englisch** (Swift-üblich).
  Das gilt auch für Doc-Comments und Testtitel.
- **Projektdokumentation und alle nutzersichtbaren Texte auf Deutsch.**

  **Bekannte Abweichung (Stand Phase 1):** Der in Phase 0 und 1 geschriebene
  Swift-Code enthält deutsche Kommentare, Doc-Comments und Testtitel — rund
  120 von etwa 240 Kommentarzeilen in 12 von 13 Dateien. Diese Dateien werden
  **nicht** rückwirkend übersetzt; der Aufwand stünde in keinem Verhältnis
  zum Nutzen. Die Regel gilt für **neu geschriebenen** Swift-Code ab Phase 2.
  Bestehende deutsche Kommentare bleiben stehen, bis die betroffene Datei aus
  fachlichem Grund ohnehin umgeschrieben wird — kein Übersetzen um des
  Übersetzens willen.
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
