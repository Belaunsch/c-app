---
paths:
  - "**/Learning/**/*.swift"
---

# Regeln für die Learning-Schicht

Diese Regeln gelten für jede Datei unter `Learning/`. Sie sind die
detaillierte Fassung der harten Regel 4 in `CLAUDE.md`. Verbindliche
Spezifikation der Fachlogik: `docs/learning-engine.md`.

## Nur Foundation

`import Foundation` und sonst nichts. Kein `SwiftUI`, kein `SwiftData`, kein
`AVFoundation`, kein `Speech`, kein `Translation`, kein `UIKit`.

Wenn eine Aufgabe hier ein anderes Framework zu brauchen scheint, gehört sie
nicht in diese Schicht. Sie gehört nach `Services/` oder in die
Feature-Schicht.

## Keine Persistenzobjekte

- Kein `@Model`, kein `ModelContext`, kein `@Query`, kein `@Observable`.
- Die Engine arbeitet auf Wertetypen, nicht auf SwiftData-Klassen. Der
  Eingabetyp ist `CardSnapshot`; die Feature-Schicht bildet
  `Card` darauf ab und schreibt die Ergebnisse zurück.
- Die Engine schreibt selbst nie in die Datenbank und liest nie daraus.

Die Enums `LearningStatus` und `CardType` liegen in `Models/`, sind reine
Swift-Enums ohne SwiftData-Abhängigkeit und dürfen hier verwendet werden.

## Deterministisch und pur

- Kein eigener Zufall. Zufallsgeneratoren werden hereingereicht
  (`inout some RandomNumberGenerator`), nie in der Engine erzeugt. Kein
  `Int.random(in:)` ohne übergebenen Generator, kein `shuffled()` ohne
  `using:`.
- Kein `Date()` im Berechnungspfad. Wird eine Zeit gebraucht, wird sie als
  Parameter übergeben, damit Tests sie festlegen können.
- Keine Nebenwirkungen: kein Logging, kein Dateizugriff, kein Netzwerk,
  kein `UserDefaults`.
- Statusübergänge sind reine Funktionen ohne gespeicherten Zustand.

Grund: Bei gleichem Seed und gleicher Eingabe muss dasselbe herauskommen.
Sonst sind die Testfälle aus `docs/learning-engine.md` §10 nicht prüfbar.

## Parameter an einer Stelle

`batchSize`, `reinsertGap`, `maxReinserts`, `recencyFactor` und die
Basisgewichte sind benannte Konstanten an genau einer Stelle
(`docs/learning-engine.md` §8). Keine Zahlenliterale im Code verstreuen.

## Tests sind Pflicht

Jede Datei hier braucht Tests. Für die spezifizierten Bausteine sind die
Testfälle in `docs/learning-engine.md` §10 einzeln nummeriert und werden
vollständig umgesetzt — nicht auswahlweise.

Pflichtabdeckung: Terminierung (ein Batch endet immer), Randfälle (leerer
Pool, Pool mit einer Karte), Ober- und Untergrenzen der Statusübergänge,
Determinismus bei festem Seed.

## Was hier nicht hingehört

Kein Spaced Repetition mit Fälligkeitsdaten, solange die Roadmap es nicht
verlangt — die Nahtstelle dafür ist in `docs/learning-engine.md` §11
beschrieben und wird nicht vorab gebaut. Keine Statistikaggregation, keine
Session-Persistenz, keine Sprachlogik.
