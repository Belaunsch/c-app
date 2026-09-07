# Entwicklungs-Roadmap

Eine vorgeschaltete Bootstrap-Phase (**B**) für die Entwicklungsinfrastruktur,
danach 11 Produktphasen (**0–10**). Jede Produktphase endet in einem Zustand,
der auf einem echten iPhone überprüfbar ist. Nach jeder Phase wird getestet,
bevor die nächste beginnt.

Die Bootstrap-Phase trägt absichtlich den Buchstaben B statt einer Nummer,
damit die fachliche Nummerierung 0–10 stabil bleibt.

Verbindliche Regel: **Kein Feature einer späteren Phase vorziehen.** Wenn
während einer Phase eine gute Idee für später auftaucht, wandert sie in den
Backlog (§ Backlog), nicht in den Code.

---

## Reihenfolge und ihre Begründung

Die Reihenfolge weicht bewusst an drei Stellen von der naheliegenden ab:

1. **Kartenverwaltung (Phase 2) vor jeder Automatik.** Wenn Karten manuell
   angelegt werden können, ist die App bereits nutzbar — und alle folgenden
   Phasen haben echte Testdaten. Umgekehrt hinge die Kartenverwaltung sonst
   von der Verfügbarkeit der Übersetzung ab.
2. **Pinyin (Phase 3) vor Übersetzung (Phase 4).** Pinyin ist rein lokal,
   ohne Berechtigungen, ohne Download und vollständig unit-testbar. Die
   Übersetzung hat die größte technische Unsicherheit (offene Frage Q1) und
   soll nicht der erste Automatik-Schritt sein.
3. **Learning Engine (Phase 5) vor der Lern-UI (Phase 6).** Die Engine ist
   reiner Swift-Code mit Unit-Tests. Sie zuerst zu bauen bedeutet: Wenn die
   UI kommt, ist die Logik bereits bewiesen, und Fehler im Lernablauf sind
   eindeutig UI-Fehler.

Die Spracherkennung (Phase 9) kommt spät, weil sie die aufwendigste
Systemintegration ist und für den Kern-Lernablauf nicht erforderlich —
Modus A funktioniert vollständig ohne sie.

| Phase | Titel | Ergebnis |
| --- | --- | --- |
| B | Development Workflow Bootstrap | Claude-Code-Infrastruktur und Workflow stehen, kein App-Code |
| 0 | Foundation & Projekt-Setup | App startet auf dem Gerät, leeres Tab-Gerüst |
| 1 | Datenmodell & Persistenz | Karten und Tags überleben den App-Neustart |
| 2 | Kartenverwaltung | Karten manuell anlegen, suchen, filtern, bearbeiten, löschen |
| 3 | Pinyin-Generierung | Hanzi → Pinyin mit Tonzeichen, editierbar |
| 4 | Übersetzung Deutsch → Chinesisch | Deutsch eingeben, Hanzi + Pinyin vorschlagen lassen |
| 5 | Learning Engine | getestete Lernlogik, noch ohne UI |
| 6 | Lernmodus A | Deutsch → Chinesisch, Selbsteinschätzung, Statusaktualisierung |
| 7 | Sprachausgabe | Mandarin-TTS in Lernmodus und Kartenübersicht |
| 8 | Lernmodus B | chinesisches Audio → Deutsch |
| 9 | Spracherkennung | Mandarin-Spracheingabe mit einfachem Textvergleich |
| 10 | Einstellungen, Fehlerbehandlung & Polish | Release-fähiger Zustand für den privaten Gebrauch |

---

## Phase B — Development Workflow Bootstrap

**Status: abgeschlossen.** Voraussetzung für den Beginn von Phase 0.

### Ziel
Die Claude-Code-Entwicklungsinfrastruktur des Projekts steht, damit die
Produktphasen einem festen, überprüfbaren Ablauf folgen statt jedes Mal neu
erklärt zu werden.

### Scope
Projektinstruktionen, Subagents, Skills, pfadgebundene Regeln und die
Dokumentation des Workflows. **Ausdrücklich kein App-Code.**

### Tasks
- **B.1** Aktuelle Claude-Code-Konventionen gegen die offizielle
  Dokumentation verifizieren (Frontmatter-Schemata, Dateiorte,
  Werkzeugbeschränkungen, Abgrenzung Skill / Subagent / Rule / Agent Team).
- **B.2** Drei Subagents unter `.claude/agents/` anlegen:
  `apple-api-researcher`, `code-reviewer`, `test-auditor` — alle ohne
  Schreibrechte auf Projektdateien.
- **B.3** Drei Skills unter `.claude/skills/` anlegen: `implement-phase`,
  `verify-phase`, `apple-api-spike`.
- **B.4** Pfadgebundene Regel `.claude/rules/learning-layer.md` für
  `Learning/**` anlegen.
- **B.5** `CLAUDE.md` um einen Routing-Abschnitt ergänzen, ohne die Datei
  zum Handbuch anwachsen zu lassen.
- **B.6** `docs/claude-workflow.md` mit Rollen, Phase-Workflow,
  Delegationsregeln, Git-Regel und Phase-Gate anlegen.
- **B.7** Bewusst nicht eingerichtete Bestandteile mit Begründung
  dokumentieren (Agent Teams, weitere Implementierungsagenten, Hooks, MCP,
  Plugins).
- **B.8** Frontmatter aller Agent- und Skill-Dateien gegen die verifizierte
  Spezifikation prüfen.

### Akzeptanzkriterien
- [x] Alle Agent- und Skill-Dateien haben gültiges, dokumentiertes Frontmatter.
- [x] Kein Subagent besitzt `Write` oder `Edit`.
- [x] Kein Skill und kein Agent dupliziert die Verantwortung eines anderen.
- [x] `CLAUDE.md` bleibt deutlich unter 200 Zeilen.
- [x] Der Phase-Workflow ist dokumentiert und von `CLAUDE.md` aus erreichbar.
- [x] Agent Teams sind nicht aktiviert.
- [x] Es ist kein produktiver Swift-Code entstanden.

### Abhängigkeiten
Keine.

### Ausdrücklich nicht in dieser Phase
Xcode-Projekt, App-Code, Datenmodell, Hooks, MCP-Server, Plugins, Agent
Teams, zusätzliche Implementierungsagenten.

---

## Phase 0 — Foundation & Projekt-Setup

**Status: abgeschlossen.** Gerätetest auf physischem iPhone (iOS 26) am
2026-09-07 bestanden.

### Ziel
Ein lauffähiges, signiertes iOS-Projekt mit leerem Navigationsgerüst, das auf
dem echten iPhone startet.

### Scope
Projektanlage, Build-Konfiguration, Ordnerstruktur, Test-Target, Deployment
auf das Gerät. Keine Fachlogik.

### Tasks
- **0.1** App-Namen und Bundle-ID festlegen (offene Entscheidung: Arbeitsname
  ist `CApp`).
- **0.2** Xcode-Projekt anlegen: iOS-App, SwiftUI, Deployment Target **iOS 26.0**,
  nur iPhone, Portrait-Orientierung.
- **0.3** Ordnerstruktur gemäß [architecture.md](architecture.md#2-ordnerstruktur)
  anlegen (`Models/`, `Learning/`, `Services/`, `Features/`, `Support/`).
- **0.4** Ordner als *synchronisierte Ordner* (Xcode 16+) einbinden, damit in
  VS Code angelegte Dateien automatisch im Target landen.
- **0.5** Unit-Test-Target `CAppTests` anlegen; ein trivialer Test läuft grün.
- **0.6** `RootView` mit `TabView`: Tabs „Lernen“ und „Karten“, beide mit
  Platzhalterinhalt. **Kein** Einstellungen-Tab (siehe
  [Architekturentscheidung A6](architecture.md#6-navigation)).
- **0.7** Signing mit dem eigenen Apple-Developer-Account einrichten und die
  App auf dem physischen iPhone starten.
- **0.8** `.gitignore` prüfen (liegt bereits vor) und den ersten Code-Commit
  anlegen.
- **0.9** Jetzt, mit existierendem Xcode-Projekt, bewerten, ob ein Hook einen
  echten Vorteil bringt — etwa Absicherung von `project.pbxproj` oder ein
  Formatierungslauf nach jedem Edit. Nur einrichten, wenn ja; sonst die
  Entscheidung in [claude-workflow.md §6](claude-workflow.md#6-bewusst-nicht-eingerichtet)
  vermerken.

### Akzeptanzkriterien
- [x] Die App startet auf dem echten iPhone (nicht nur im Simulator).
- [x] Beide Tabs sind sichtbar und umschaltbar.
- [x] `xcodebuild test` läuft grün durch.
- [x] Eine in VS Code neu angelegte Swift-Datei erscheint ohne manuellen
      Schritt im Xcode-Target.
- [x] Keine externe Dependency im Projekt.

### Abhängigkeiten
Phase B (Entwicklungsinfrastruktur).

### Ausdrücklich nicht in dieser Phase
Datenmodell, Persistenz, jegliche UI über Platzhalter hinaus, App-Icon,
Launch-Screen, Berechtigungen in der Info.plist.

---

## Phase 1 — Datenmodell & Persistenz

**Status: abgeschlossen.** Gerätetest auf physischem iPhone (iOS 26) am
2026-09-07 bestanden: App startet, öffnet beim zweiten Start den bestehenden
lokalen Store, keine Fehleransicht.

### Ziel
SwiftData-Modelle für Karten und Tags, die einen App-Neustart überleben.

### Scope
Modelle, `ModelContainer`, Testdaten, Integrationstest. Noch keine
Bedienoberfläche zum Bearbeiten.

### Tasks
- **1.1** `CardType` (`word`, `sentence`) und `LearningStatus`
  (`new`, `weak`, `medium`, `good`, `secure`) als Enums; `LearningStatus`
  `Comparable` mit `Int`-RawValue.
- **1.2** `@Model final class Card` gemäß
  [Datenmodell-Skizze](architecture.md#3-datenmodell), inklusive
  `hanziWasEditedManually` und `pinyinWasEditedManually`.
- **1.3** `@Model final class Tag` mit many-to-many-Beziehung zu `Card`;
  Löschregeln so setzen, dass beim Löschen einer Karte keine Tags und beim
  Löschen eines Tags keine Karten verschwinden.
- **1.4** Verifizieren, ob SwiftData die Enums direkt speichert. Falls nicht:
  privates RawValue-Feld plus berechnete Property; die öffentliche
  Modell-API bleibt unverändert.
- **1.5** `ModelContainer` in `CAppApp` aufsetzen (lokal, **ohne** CloudKit).
- **1.6** Migrationsstrategie festhalten: zunächst automatische
  leichtgewichtige Migration; ein `VersionedSchema` wird erst eingeführt,
  wenn eine Änderung es erzwingt. Entscheidung als Kommentar im Code
  festhalten (offene Frage Q7).
- **1.7** `SampleData` mit ca. 20 Wort- und 10 Satzkarten über mehrere Tags
  und Lernstatus, nur unter `#if DEBUG`.
- **1.8** Integrationstest mit In-Memory-`ModelContainer`: anlegen, laden,
  Tag zuweisen, löschen.
- **1.9** Alle Properties mit sinnvollen Defaults versehen (Konvention, hält
  eine spätere CloudKit-Option offen — kostet jetzt nichts).

### Akzeptanzkriterien
- [x] Eine im Code angelegte Karte ist nach einem App-Neustart noch vorhanden.
- [x] Eine Karte lässt sich mehreren Tags zuordnen.
- [x] Das Löschen einer Karte löscht keinen Tag und umgekehrt.
- [x] Der Integrationstest läuft grün.
- [x] Vorschau-Daten stehen für SwiftUI-Previews bereit.

### Abhängigkeiten
Phase 0.

### Ausdrücklich nicht in dieser Phase
Kartenlisten-UI, Editor, Übersetzung, Pinyin, Gewichtungslogik,
Antwort-Historie (`ReviewLog`).

---

## Phase 2 — Kartenverwaltung (manuell)

### Ziel
Karten vollständig manuell verwalten können. Ab hier ist die App real
benutzbar und liefert Testdaten für alle Folgephasen.

### Scope
Kartenübersicht mit Suche und Filtern, Editor zum Anlegen und Bearbeiten,
Löschen, Tag-Verwaltung, manuelle Statusänderung. Keinerlei Automatik.

### Tasks
- **2.1** `CardListView`: Liste aller Karten mit Hanzi, Pinyin und deutschem
  Text; Lernstatus als dezentes visuelles Merkmal.
- **2.2** Umschalter Wörter / Sätze (`Picker` im Segmented-Stil) — die beiden
  Kartentypen werden nie gemischt dargestellt.
- **2.3** Suche über deutschen Text, Hanzi und Pinyin (`.searchable`).
- **2.4** Filter nach Tag (Mehrfachauswahl) und nach Lernstatus.
- **2.5** „+“-Button prominent in der Toolbar; öffnet den Editor als Sheet.
- **2.6** `CardEditorView` mit Feldern: Kartentyp, Deutsch, Hanzi, Pinyin,
  Tags, Lernstatus. Alle Felder frei editierbar.
- **2.7** Tag-Auswahl mit Anlegen neuer Tags direkt im Editor; bestehende
  Tags werden vorgeschlagen, Duplikate (Groß-/Kleinschreibung, Leerzeichen)
  werden zusammengeführt.
- **2.8** Bearbeiten einer bestehenden Karte; setzt `hanziWasEditedManually`
  bzw. `pinyinWasEditedManually`, sobald das jeweilige Feld vom Nutzer
  geändert wurde.
- **2.9** Löschen per Swipe mit Bestätigung.
- **2.10** Validierung: Speichern erst möglich, wenn Deutsch **und** Hanzi
  gefüllt sind. Pinyin darf leer bleiben.
- **2.11** Leerzustände: „Noch keine Karten“ mit direktem Weg zum Anlegen;
  „Keine Treffer“ bei leerem Filterergebnis.

### Akzeptanzkriterien
- [ ] Eine Wortkarte lässt sich vollständig manuell anlegen, bearbeiten und löschen.
- [ ] Eine Satzkarte ebenso.
- [ ] Wörter und Sätze sind getrennt sichtbar; ein Umschalten ändert die Liste.
- [ ] Suche findet Karten über alle drei Textfelder.
- [ ] Filter nach Tag und Lernstatus lassen sich kombinieren.
- [ ] Der Lernstatus lässt sich manuell setzen.
- [ ] Alle Änderungen überleben einen App-Neustart.

### Abhängigkeiten
Phase 1.

### Ausdrücklich nicht in dieser Phase
Automatische Übersetzung, automatische Pinyin-Erzeugung, Audio-Wiedergabe,
Lernmodus, Sortieroptionen, Import/Export, Massenbearbeitung.

---

## Phase 3 — Pinyin-Generierung

### Ziel
Aus Hanzi automatisch Pinyin mit Tonzeichen erzeugen — lokal, offline und
jederzeit überschreibbar.

### Scope
`PinyinService` plus dessen Einbindung in den Karten-Editor.

### Tasks
- **3.1** `PinyinService` mit `CFStringTokenizer` und
  `kCFStringTokenizerAttributeLatinTranscription` (wortweise Segmentierung).
- **3.2** Fallback über `CFStringTransform` mit
  `kCFStringTransformMandarinLatin`, falls die Tokenizer-Variante für eine
  Eingabe nichts liefert.
- **3.3** Normalisierung der Ausgabe: Leerzeichen vereinheitlichen,
  Satzzeichen sinnvoll behandeln, Tonzeichen **erhalten**.
- **3.4** Unit-Tests mit festen Paaren aus Wörtern und Sätzen; die erwarteten
  Werte einmalig auf dem Gerät verifizieren und im Test festschreiben
  (offene Frage Q6).
- **3.5** Einbindung in den Editor: Beim Verlassen des Hanzi-Feldes wird
  Pinyin vorgeschlagen — **nur**, wenn das Pinyin-Feld leer ist oder
  `pinyinWasEditedManually == false`.
- **3.6** Sichtbarer Button „Pinyin neu erzeugen“, mit dem der Nutzer die
  Automatik bewusst erneut anstoßen kann.
- **3.7** Bekannte Grenzen (polyphone Zeichen) als kurzen Hinweis im Editor
  erwähnen, ohne aufdringlich zu sein.

### Akzeptanzkriterien
- [ ] `苹果` ergibt `píngguǒ` (mit Tonzeichen).
- [ ] Ein Satz ergibt sinnvoll segmentiertes Pinyin mit Tonzeichen.
- [ ] Manuell geändertes Pinyin wird von der Automatik nie überschrieben.
- [ ] „Pinyin neu erzeugen“ überschreibt auch manuelle Werte — nach
      bewusster Nutzeraktion.
- [ ] Die Unit-Tests laufen grün.
- [ ] Funktioniert im Flugmodus.

### Abhängigkeiten
Phase 2.

### Ausdrücklich nicht in dieser Phase
Übersetzung, Auflösung polyphoner Zeichen über Wörterbücher, Pinyin ohne
Tonzeichen, Zhuyin, Audio.

---

## Phase 4 — Übersetzung Deutsch → Chinesisch

### Ziel
Deutschen Text eingeben und automatisch Hanzi erzeugen lassen; Pinyin folgt
aus Phase 3.

### Scope
`TranslationService`, Verfügbarkeitsprüfung, Download-Flow, Einbindung in den
Editor.

### Tasks
- **4.1** **Spike zuerst:** `LanguageAvailability.status(from: .german,
  to: .chineseSimplified)` auf dem Zielgerät ausführen und das Ergebnis in
  [apple-frameworks.md](apple-frameworks.md#10-offene-technische-fragen-zu-klären-vor-der-jeweiligen-phase)
  unter Q1 eintragen. Erst danach weiterbauen.
- **4.2** `TranslationService` mit `TranslationSession(installedSource:target:)`
  für den Normalfall (Sprachen installiert).
- **4.3** `TranslationHostView` (unsichtbar) mit `.translationTask()` für den
  Download-Pfad; das System übernimmt Zustimmung und Fortschrittsanzeige.
- **4.4** Zustandsbehandlung im Editor: `installed` → übersetzen;
  `supported` → Download anbieten; `unsupported` → Automatik dauerhaft
  ausblenden, manuelle Eingabe bleibt unverändert möglich.
- **4.5** Editor-Ablauf: Kartentyp wählen → deutschen Text eingeben →
  „Übersetzen“ → Hanzi wird gefüllt → Pinyin wird daraus erzeugt → beides
  prüfbar und korrigierbar.
- **4.6** Übersetzung ist ein **Vorschlag**: Wird Hanzi manuell geändert,
  setzt das `hanziWasEditedManually` und schützt den Wert vor
  Überschreiben.
- **4.7** Fehlerbehandlung: Fehlschlag zeigt einen Inline-Hinweis, blockiert
  aber nie das Speichern.
- **4.8** Falls Q1 negativ ausfällt: Pivot über Englisch als dokumentierten
  Notfallpfad evaluieren — **nicht** implementieren, ohne die
  Qualitätseinbuße vorher an echten Beispielen zu prüfen.

### Akzeptanzkriterien
- [ ] Q1 ist mit einem konkreten Messergebnis beantwortet und dokumentiert.
- [ ] Aus „Apfel“ entsteht eine plausible Hanzi-Ausgabe mit passendem Pinyin.
- [ ] Aus einem deutschen Satz entsteht eine plausible chinesische Übersetzung.
- [ ] Eine manuell korrigierte chinesische Formulierung bleibt erhalten.
- [ ] Bei nicht installierten Sprachen erscheint der System-Download-Dialog.
- [ ] Bei fehlgeschlagener Übersetzung lässt sich die Karte trotzdem speichern.

### Abhängigkeiten
Phasen 2 und 3.

### Ausdrücklich nicht in dieser Phase
Rückübersetzung Chinesisch → Deutsch, mehrere Übersetzungsvorschläge zur
Auswahl, Batch-Übersetzung bestehender Karten, Audio.

---

## Phase 5 — Learning Engine (ohne UI)

### Ziel
Die vollständige Lernlogik als reiner, getesteter Swift-Code.

### Scope
Alles unter `Learning/` gemäß [learning-engine.md](learning-engine.md).
**Keine einzige Zeile SwiftUI.**

### Tasks
- **5.1** `CardSnapshot`, `SelfAssessment`, `SessionConfiguration` als
  Wertetypen.
- **5.2** `CardWeighting`: Basisgewichte plus Recency-Faktor
  ([§3](learning-engine.md#3-gewichtung)).
- **5.3** `BatchSelector`: gewichtete Auswahl ohne Zurücklegen nach
  Efraimidis–Spirakis, mit injiziertem `RandomNumberGenerator`
  ([§4](learning-engine.md#4-auswahl-des-mini-batches)).
- **5.4** `SessionQueue`: Mischen, Fortschalten, Wiedereinstreuung mit
  `reinsertGap` und `maxReinserts`, Batch-Ende-Erkennung
  ([§5](learning-engine.md#5-queue-und-wiedereinstreuung)).
- **5.5** `StatusTransition`: reine Funktion gemäß Übergangsmatrix
  ([§6](learning-engine.md#6-statusübergänge)), inklusive der Regel
  „Statusänderung nur bei der ersten Einschätzung pro Batch“.
- **5.6** Normalisierungsfunktion für den späteren Textvergleich
  (Interpunktion und Whitespace entfernen, auch chinesische Satzzeichen) —
  hier schon anlegen, weil sie rein und testbar ist.
- **5.7** Alle 19 Testfälle aus
  [§10](learning-engine.md#10-testfälle-für-phase-5) implementieren.
- **5.8** Alle Parameter als benannte Konstanten an einer Stelle
  ([§8](learning-engine.md#8-parameter)).

### Akzeptanzkriterien
- [ ] Alle 19 spezifizierten Tests laufen grün.
- [ ] Der Ordner `Learning/` importiert nichts außer `Foundation`.
- [ ] Gleicher RNG-Seed liefert reproduzierbar dieselbe Auswahl.
- [ ] Ein Batch der Größe 1 mit dauerhaftem „Nochmal“ terminiert.
- [ ] Die Testsuite läuft in unter einer Sekunde.

### Abhängigkeiten
Phase 1 (nur für die Enums `LearningStatus` und `CardType`).

### Ausdrücklich nicht in dieser Phase
Lern-UI, Persistieren von Antworten, Spaced Repetition, Audio,
Spracherkennung.

---

## Phase 6 — Lernmodus A: Deutsch → Chinesisch

### Ziel
Der erste vollständige Lernablauf: Sessionauswahl, Karten abfragen,
Selbsteinschätzung, Lernstatus aktualisieren — noch ohne Ton.

### Scope
Session-Setup, Abfrage-UI, Anbindung der Engine an SwiftData.

### Tasks
- **6.1** `SessionSetupView`: Auswahl von Inhalt (Wörter / Sätze), Richtung
  (vorerst nur Modus A auswählbar) und optional Tags.
- **6.2** `LearnSessionModel` (`@Observable`): Pool laden, auf
  `CardSnapshot` abbilden, Engine ansteuern, Ergebnisse persistieren.
- **6.3** `PromptGermanToChineseView`: zeigt den deutschen Text und
  fordert zum lauten Sprechen auf.
- **6.4** Aufdecken zeigt Hanzi und Pinyin.
- **6.5** `SelfAssessmentBar` mit vier Aktionen: Nochmal, Schwer, Gut, Sicher.
- **6.6** Antwort verarbeiten: Zähler und `lastReviewedAt` immer aktualisieren,
  Status nur bei der ersten Einschätzung im Batch; sofort speichern.
- **6.7** Nahtloser Übergang zum nächsten Mini-Batch, ohne sichtbaren
  Einschnitt für den Nutzer.
- **6.8** Session jederzeit beendbar; keine Zwischenbilanz mit Wertung
  (keine Gamification) — höchstens eine sachliche Angabe „x Karten
  bearbeitet“.
- **6.9** Leerzustand, wenn der Pool leer ist, mit direktem Weg zum Anlegen
  einer Karte.

### Akzeptanzkriterien
- [ ] Eine Session mit Wörtern lässt sich starten und durchlaufen.
- [ ] Eine Session mit Sätzen ebenso; die Typen werden nie gemischt.
- [ ] Nach „Nochmal“ erscheint die Karte erst nach mehreren anderen wieder.
- [ ] Nach der siebten aufgelösten Karte folgen automatisch weitere Karten.
- [ ] Der Lernstatus ändert sich gemäß Übergangsmatrix und ist in der
      Kartenübersicht sichtbar.
- [ ] Die Änderungen überleben einen App-Neustart.
- [ ] Nirgends erscheinen Herzen, Streaks, Timer oder Limits.

### Abhängigkeiten
Phasen 2 und 5.

### Ausdrücklich nicht in dieser Phase
Audio-Wiedergabe, Spracherkennung, Modus B, Statistiken, Session-Verlauf,
Wiederaufnahme einer unterbrochenen Session.

---

## Phase 7 — Sprachausgabe (Mandarin TTS)

### Ziel
Korrekte Mandarin-Aussprache auf Knopfdruck hören.

### Scope
`SpeechSynthesisService` und dessen Einbindung in Lernmodus A und die
Kartenübersicht.

### Tasks
- **7.1** **Zuerst prüfen:** `AVSpeechSynthesisVoice.speechVoices()` auf dem
  Zielgerät nach `zh-CN` filtern, verfügbare Stimmen und Qualitäten
  protokollieren und unter Q5 in
  [apple-frameworks.md](apple-frameworks.md#10-offene-technische-fragen-zu-klären-vor-der-jeweiligen-phase)
  eintragen.
- **7.2** `SpeechSynthesisService` mit **einer langlebigen**
  `AVSpeechSynthesizer`-Instanz (das System retained sie nicht selbst).
- **7.3** Stimmenauswahl nach Qualität: `.premium` > `.enhanced` > `.default`.
- **7.4** `AVAudioSession` korrekt konfigurieren, damit die Wiedergabe auch
  bei stummgeschaltetem Klingelton und über Kopfhörer funktioniert.
- **7.5** Play-Button in der aufgedeckten Karte in Modus A.
- **7.6** Play-Button in der Kartenübersicht und im Editor (zum Prüfen beim
  Anlegen).
- **7.7** Ist keine `zh-CN`-Stimme vorhanden: Button ausblenden und einmalig
  erklären, wie Stimmen unter *Einstellungen → Bedienungshilfen →
  Gesprochene Inhalte → Stimmen* nachgeladen werden.
- **7.8** Sprechgeschwindigkeit auf einen für Lernende angenehmen Wert
  setzen; die Verstellbarkeit kommt in Phase 10.

### Akzeptanzkriterien
- [ ] Ein Wort wird in verständlichem Mandarin mit korrekten Tönen ausgegeben.
- [ ] Ein Satz ebenso.
- [ ] Die Wiedergabe bricht nicht vorzeitig ab (Retain-Problem ausgeschlossen).
- [ ] Wiedergabe funktioniert über Lautsprecher und Kopfhörer.
- [ ] Ohne passende Stimme erscheint ein verständlicher Hinweis statt eines
      toten Buttons.
- [ ] Funktioniert im Flugmodus.

### Abhängigkeiten
Phase 6.

### Ausdrücklich nicht in dieser Phase
Automatisches Abspielen ohne Nutzeraktion, Aufnahme, Spracherkennung,
Modus B, Stimmenauswahl in den Einstellungen.

---

## Phase 8 — Lernmodus B: Chinesisches Audio → Deutsch

### Ziel
Hörverstehen trainieren: Die App spielt Chinesisch ab, der Nutzer erschließt
die Bedeutung.

### Scope
Zweite Abfragerichtung, aufbauend auf derselben Engine.

### Tasks
- **8.1** `SessionConfiguration.direction` um `audioToGerman` erweitern; die
  Richtung ist im Session-Setup wählbar.
- **8.2** `PromptAudioToGermanView`: Zunächst sind **weder Hanzi noch Pinyin**
  sichtbar — nur ein Play-Button.
- **8.3** Wiedergabe beliebig oft wiederholbar.
- **8.4** Aufdecken zeigt Hanzi, Pinyin und die deutsche Bedeutung.
- **8.5** Zwischenschritt „Hanzi anzeigen“, der Hanzi sichtbar macht, ohne
  die deutsche Bedeutung aufzudecken.
- **8.6** Selbsteinschätzung und Statuslogik unverändert aus Phase 6
  übernehmen — die Engine bleibt unangetastet.
- **8.7** Karten ohne verwendbares Hanzi werden für diesen Modus aus dem Pool
  ausgeschlossen.

### Akzeptanzkriterien
- [ ] Modus B lässt sich im Setup wählen und startet korrekt.
- [ ] Vor dem Aufdecken sind Hanzi und Pinyin nicht sichtbar.
- [ ] Das Audio lässt sich mehrfach abspielen.
- [ ] „Hanzi anzeigen“ deckt die deutsche Bedeutung nicht mit auf.
- [ ] Die Lernstatuslogik verhält sich identisch zu Modus A.
- [ ] An der Learning Engine wurde für diese Phase nichts geändert.

### Abhängigkeiten
Phase 7.

### Ausdrücklich nicht in dieser Phase
Spracherkennung, Hanzi-Schreibübungen, Audio → Hanzi als eigener Modus,
gemischte Sessions über beide Richtungen.

---

## Phase 9 — Spracherkennung (Mandarin)

### Ziel
In Modus A laut sprechen und eine einfache, ehrliche Rückmeldung erhalten,
ob das Gesagte zum Sollwert passt.

### Scope
`SpeechRecognitionService`, Berechtigungen, Modell-Download, Textvergleich.

### Tasks
- **9.1** **Spike zuerst:** `SpeechTranscriber.supportedLocales` und
  `installedLocales` auf dem Zielgerät ausgeben; prüfen, ob `zh_CN` enthalten
  ist und ob das Gerät die Hardware-Anforderungen erfüllt. Ergebnis unter
  Q2 und Q3 dokumentieren. Bei leerem Array: `DictationTranscriber` prüfen.
- **9.2** `NSMicrophoneUsageDescription` und
  `NSSpeechRecognitionUsageDescription` in der Info.plist setzen (beide, siehe
  Q4) und die tatsächlich angezeigten Dialoge protokollieren.
- **9.3** Locale über `AssetInventory` reservieren und die Modelle
  herunterladen; Fortschritt und Fehler in der UI sichtbar machen.
- **9.4** `SpeechRecognitionService` mit `SpeechAnalyzer` und
  `SpeechTranscriber`: Start, Stop, Ergebnis als erkannter Text.
- **9.5** Aufnahme-Button in Modus A; Aufnahme ist immer optional — die
  Selbsteinschätzung funktioniert auch ohne Mikrofon vollständig.
- **9.6** Vergleich mit der in Phase 5 gebauten Normalisierungsfunktion:
  bei Gleichheit „Antwort wahrscheinlich korrekt“, sonst beide Varianten
  nebeneinander anzeigen.
- **9.7** **Keine** Score-Anzeige, **keine** Prozentangabe, **keine**
  Ton-Bewertung. Die Selbsteinschätzung bleibt die maßgebliche Bewertung.
- **9.8** Verweigerte Berechtigung sauber behandeln: Mikrofonteil entfällt,
  der Rest der App bleibt uneingeschränkt nutzbar.
- **9.9** Nicht mehr benötigte Locale-Reservierungen wieder freigeben.

### Akzeptanzkriterien
- [ ] Q2, Q3 und Q4 sind mit Messergebnissen vom Gerät dokumentiert.
- [ ] Nach Aussprache von „苹果“ erkennt die App „苹果“ und meldet
      „wahrscheinlich korrekt“.
- [ ] Bei abweichender Erkennung werden Soll und Ist nebeneinander gezeigt,
      ohne Wertung.
- [ ] Es erscheint nirgends ein Aussprache-Score.
- [ ] Bei verweigerter Mikrofonberechtigung bleibt die App voll bedienbar.
- [ ] Nach dem Modell-Download funktioniert die Erkennung im Flugmodus.

### Abhängigkeiten
Phase 6 (Phase 7 empfohlen, damit Soll und Ist direkt hörbar vergleichbar sind).

### Ausdrücklich nicht in dieser Phase
Tonanalyse, Aussprachebewertung, phonetischer Ähnlichkeitsvergleich,
automatisches Setzen der Selbsteinschätzung aus dem Erkennungsergebnis,
kontinuierliche Erkennung ohne Knopfdruck.

---

## Phase 10 — Einstellungen, Fehlerbehandlung, Device-Test & Polish

### Ziel
Ein Zustand, den man täglich benutzen möchte.

### Scope
Einstellungen, durchgängige Fehlerbehandlung, Leerzustände, Zugänglichkeit,
Test auf dem Gerät unter realen Bedingungen.

### Tasks
- **10.1** `SettingsView` als Sheet über einen Zahnrad-Button in der
  Kartenübersicht (kein eigener Tab, siehe
  [A6](architecture.md#6-navigation)).
- **10.2** Einstellungen: Sprechgeschwindigkeit, Stimmenauswahl (falls
  mehrere `zh-CN`-Stimmen vorhanden), `batchSize` (5–10), Verwaltung der
  Sprachmodelle, Anzeige der Kartenanzahl je Status.
- **10.3** Alle Fehlerfälle aus
  [architecture.md §7](architecture.md#7-fehlerbehandlung) durchgehen und
  jeweils tatsächlich auslösen und prüfen.
- **10.4** Leerzustände und Ladezustände in allen Bereichen prüfen.
- **10.5** Dynamic Type und VoiceOver testen; chinesische Texte brauchen
  ausreichend große Schrift, Hanzi mit korrekter Sprachauszeichnung.
- **10.6** Dark Mode prüfen.
- **10.7** **Flugmodus-Test:** Nach den Modell-Downloads müssen Kartenanlage
  (mit Pinyin), Lernen, TTS und Spracherkennung offline funktionieren.
- **10.8** Test mit realistischem Bestand (mehrere hundert Karten): Suche,
  Filter und Session-Start dürfen nicht spürbar verzögern. Erst wenn es
  hakt, über `#Index` nachdenken — nicht vorher.
- **10.9** App-Icon und Launch-Screen.
- **10.10** Die offenen Fragen Q1–Q7 in
  [apple-frameworks.md](apple-frameworks.md#10-offene-technische-fragen-zu-klären-vor-der-jeweiligen-phase)
  abschließend mit den Messergebnissen beantworten.
- **10.11** Entscheidung A6 (kein Einstellungen-Tab) neu bewerten, jetzt mit
  dem tatsächlichen Umfang der Einstellungen.
- **10.12** README auf den tatsächlichen Stand bringen.

### Akzeptanzkriterien
- [ ] Alle Einstellungen wirken sich sofort und dauerhaft aus.
- [ ] Kein Fehlerfall führt zu einem Absturz oder einem stillen Verschlucken.
- [ ] Die App ist nach den Modell-Downloads vollständig offline nutzbar.
- [ ] Bedienbar mit vergrößerter Schrift.
- [ ] Mehrere hundert Karten ohne spürbare Verzögerung.
- [ ] Q1–Q7 sind beantwortet.
- [ ] Die App läuft stabil über mehrere Tage täglicher Nutzung auf dem Gerät.

### Abhängigkeiten
Phasen 0–9.

### Ausdrücklich nicht in dieser Phase
Alles aus dem Backlog. App Store, TestFlight, iCloud-Sync, iPad-Layout.

---

## Backlog (ausdrücklich nicht im MVP)

Sammelstelle für Ideen, die während der Umsetzung auftauchen. Nichts hiervon
wird vor Abschluss von Phase 10 begonnen.

**Weitere Lernmodi**
- Hanzi → Bedeutung
- Hanzi → Aussprache
- Pinyin → Bedeutung
- Deutsch → Hanzi schreiben (Handschrifteingabe)
- Chinesisches Audio → Hanzi
- Gezieltes Satztraining
- Tonspezifische Übungen

**Lernlogik**
- Echtes Spaced Repetition mit Fälligkeitsdaten (Vorbereitung siehe
  [learning-engine.md §11](learning-engine.md#11-vorbereitung-auf-echtes-spaced-repetition))
- Wiederaufnahme einer unterbrochenen Session
- Gemischte Sessions über mehrere Richtungen

**Inhalte**
- Beispielsätze zu einem Wort
- Mehrere Übersetzungsvarianten pro Karte
- Import/Export eigener Kartensets
- Batch-Übersetzung bestehender Karten

**Auswertung**
- Statistiken über den Zeitverlauf (benötigt ein `ReviewLog`-Modell)
- Fortschritt je Tag

**Sprache**
- Echte Aussprachebewertung inklusive Tonanalyse
- Phonetischer Ähnlichkeitsvergleich statt exaktem Textvergleich

**Technik**
- iCloud-Synchronisation
- iPad-Layout
- Widgets
- Bewertung von iOS 27 als Deployment Target
