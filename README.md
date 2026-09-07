# c-app — Mandarin-Lernkarten für iOS

Private, native iOS-App zum Lernen von Mandarin-Chinesisch mit Lernkarten.
Deutsch als Ausgangssprache, Hanzi + Pinyin als Zielinhalt, Aussprache über
Text-to-Speech und Spracheingabe über die Mandarin-Spracherkennung des Systems.

## Status

**Phasen 0 bis 4 abgeschlossen.**

Vorhanden sind die Architektur- und Planungsdokumentation, die
Claude-Code-Entwicklungsinfrastruktur (`.claude/agents/`, `.claude/skills/`,
`.claude/rules/`), das Xcode-Projekt, die SwiftData-Modelle für Karten und
Tags mit einem rein lokalen `ModelContainer` — und eine nutzbare
Kartenverwaltung: Wörter und Sätze getrennt, Karten anlegen, bearbeiten und
löschen, Suche über Deutsch, Hanzi und Pinyin, Filter nach Kategorie und
Lernstatus, Kategorien umbenennen und löschen.

Build und Unit-Tests laufen grün (iPhone-17-Simulator, iOS 26.5), und alle
fünf Phasen sind auf dem echten iPhone bestätigt.

Neu aus den Phasen 3 und 4: Beim Anlegen einer Karte genügt der deutsche Text
— mit Return oder beim Verlassen des Feldes erzeugt die App Hanzi über Apples
Translation-Framework und daraus das Pinyin mit Tonzeichen. Beides bleibt
jederzeit editierbar, und ein von Hand korrigierter Wert wird nur nach
ausdrücklicher Nutzeraktion überschrieben — über das ↻ im jeweiligen Feld. Die
Pinyin-Erzeugung läuft komplett offline; auf dem Testgerät liegen auch die
Übersetzungsmodelle lokal, sodass die ganze Kette im Flugmodus funktioniert.

Noch nicht vorhanden: **Audio** (Sprachausgabe, Spracherkennung) und der
**Lernmodus** — der Tab „Lernen" ist ein Platzhalter.

Nächster Schritt: **Zwischenphase 4.5 — Pinyin Accuracy und Karten-/Editor-
Politur**, danach **Phase 5 — Learning Engine**. Hintergrund: Die reine
ICU-Transliteration erzeugt bei gültigem Chinesisch sprachlich falsche
Lesungen — `东西` im Sinn „Ding/etwas" ergibt `dōngxī` statt `dōngxi` —, und
das ist Apple-nativ nicht lösbar. Phase 4.5 stellt eine lokale lexikalische
Auflösung davor und kennzeichnet den verbleibenden ICU-Fallback sichtbar.

Die Umsetzung erfolgt Phase für Phase gemäß
[docs/roadmap.md](docs/roadmap.md), mit einem Test nach jeder Phase.

## Ziel

Bestehende Sprachlern-Apps erfüllen einzelne Anforderungen, kombinieren sie
aber nicht in der gewünschten Form. Diese App soll deshalb zunächst eine
fokussierte, hochwertige Flashcard-App werden:

- strikte Trennung von **Wortkarten** und **Satzkarten**
- Karten anlegen mit minimaler Tipparbeit: deutscher Text rein, Hanzi und
  Pinyin werden automatisch erzeugt und bleiben **jederzeit editierbar**
- inhaltliche **Kategorien/Tags** getrennt vom **Lernstatus**
- zwei Abfragerichtungen: Deutsch → Chinesisch (laut sprechen) und
  chinesisches Audio → Deutsch (Hörverstehen)
- Lernsessions, die sich unbegrenzt anfühlen, intern aber in kleinen
  dynamischen Gruppen von ~7 Karten arbeiten
- gewichtete Kartenauswahl nach Lernbedarf statt starrer Stapel oder
  reinem Zufall

Ausdrücklich **nicht** Teil des Produkts: Herzen, Streaks, Zeitlimits,
Tageslimits, Gamification, Werbung, In-App-Käufe, Accounts, Analytics.

## Tech Stack

| Bereich | Entscheidung |
| --- | --- |
| Sprache | Swift |
| UI | SwiftUI |
| Persistenz | SwiftData (lokal, keine CloudKit-Synchronisation) |
| Übersetzung DE → ZH | Translation Framework (`TranslationSession`) |
| Hanzi → Pinyin | CoreFoundation-Transliteration (`CFStringTokenizer` / `CFStringTransform`) |
| Sprachausgabe | AVFoundation (`AVSpeechSynthesizer`, `zh-CN`-Stimme) |
| Spracherkennung | Speech Framework (`SpeechAnalyzer` / `SpeechTranscriber`) |
| Externe Dependencies | keine |
| Backend | keines |
| Deployment Target | **iOS 26.0** |
| Build-Toolchain | Xcode 26.x (stabil) |

Begründung des Deployment Targets und die geprüfte API-Verfügbarkeit stehen in
[docs/apple-frameworks.md](docs/apple-frameworks.md). Kurzfassung: `SpeechAnalyzer`
und `SpeechTranscriber` gibt es erst ab iOS 26.0, und der UI-freie Initializer
`TranslationSession(installedSource:target:)` ebenfalls erst ab iOS 26.0. Da die
App privat auf einem eigenen Gerät läuft, gibt es keinen Grund, ältere iOS-
Versionen zu unterstützen.

## Entwicklungsprinzipien

1. **MVP zuerst.** Kein Feature bauen, bevor die Foundation dafür nötig ist.
2. **Kleine, testbare Schritte.** Jede Roadmap-Phase endet in einem Zustand,
   der auf dem Gerät überprüfbar ist.
3. **Apple-native Lösungen bevorzugen.**
4. **Keine unnötigen Dependencies.** Aktuell null externe Pakete.
5. **Geschäftslogik unabhängig von Views.** Die Learning Engine kennt weder
   SwiftUI noch SwiftData.
6. **Learning Engine separat testbar** — reine Swift-Typen, Unit-Tests ohne
   Simulator-Abhängigkeit.
7. **Automatik ist Komfort, kein Zwang.** Übersetzung und Pinyin dürfen das
   Speichern einer Karte nie blockieren; manuelle Eingabe ist immer möglich.
8. **Keine vorzeitige Optimierung.**
9. **Keine Gamification.**
10. **Local-first.** Keine Cloud-Architektur ohne konkrete Notwendigkeit.

Bewusst *nicht* verwendet: Repository-Abstraktionen, DI-Frameworks,
Coordinator-Patterns und Drittanbieter-State-Management. SwiftUI und SwiftData
reichen für den Umfang dieser App aus. Details und Begründung in
[docs/architecture.md](docs/architecture.md).

## Dokumentation

| Dokument | Inhalt |
| --- | --- |
| [docs/roadmap.md](docs/roadmap.md) | Bootstrap-Phase B plus 11 Produktphasen (0–10) mit Ziel, Scope, Tasks, Akzeptanzkriterien, Abhängigkeiten und expliziten Nicht-Zielen |
| [docs/architecture.md](docs/architecture.md) | Ordnerstruktur, SwiftData-Modell, Schichten, Services, Fehlerbehandlung, Erweiterbarkeit |
| [docs/learning-engine.md](docs/learning-engine.md) | Spezifikation von Gewichtung, Mini-Batch-Auswahl, Queue-Verhalten und Statusübergängen |
| [docs/apple-frameworks.md](docs/apple-frameworks.md) | Geprüfte API-Verfügbarkeit, Permissions, Offline-/Online-Verhalten, offene technische Fragen, Quellen |
| [docs/claude-workflow.md](docs/claude-workflow.md) | Rollen, Phase-Workflow, Delegationsregeln und Phase-Gate für die Entwicklung mit Claude Code |
| [CLAUDE.md](CLAUDE.md) | Projektregeln und Routing zu Skills und Subagents |

## Datenschutz

Die App ist local-first konzipiert: keine Accounts, kein Login, kein eigener
Server, keine Analytics, keine Telemetrie, keine Werbung.

Zwei Einschränkungen sind dokumentiert und technisch bedingt:

- Sprachmodelle für **Übersetzung** und **Spracherkennung** werden beim ersten
  Gebrauch von Apple-Servern heruntergeladen. Das erfordert einmalig eine
  Internetverbindung; danach läuft die Verarbeitung auf dem Gerät.
- Apple gibt für `TranslationSession` an, dass API-Nutzungs- und
  Performance-Metriken erhoben werden können (Bundle-ID, Sprachpaar) — jedoch
  **keine Inhalte**.

Details in [docs/apple-frameworks.md](docs/apple-frameworks.md).
