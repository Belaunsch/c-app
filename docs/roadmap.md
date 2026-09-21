# Entwicklungs-Roadmap

Eine vorgeschaltete Bootstrap-Phase (**B**) für die Entwicklungsinfrastruktur,
danach 11 Produktphasen (**0–10**) und, nach v1, die Phasen 11 bis 14. Jede
Produktphase endet in einem Zustand, der überprüfbar ist. Nach jeder Phase
wird getestet, bevor die nächste beginnt.

**Die finale Abnahme ist am 2026-09-21 erneut nach hinten gerückt**, hinter
[Phase 13](#phase-13--lernflow--assisted-classification-ux) und
[Phase 14](#phase-14--ai-erklärung-zu-einer-karte). Der Grund ist derselbe wie
beim ersten Mal: Beide Phasen verändern das Produkt real — Phase 13 den gesamten
Bedienfluss der Lernkarte und das Schema —, und eine Abnahme vor ihnen würde
etwas abnehmen, das so nicht ausgeliefert wird. **Phase 14 ist durch ihre eigene
Messung kleiner geworden** (Task 14.0, am 2026-09-21 erledigt): Der Bulk-Fall ist
gemessen gescheitert und gestrichen, geblieben ist die Erklärung zu einer Karte. **Die bisherige Abnahme- und Gerätetesthistorie
bleibt vollständig stehen**; sie sind Entwicklungsbelege für die jeweils
geprüften Pfade.

**Die vollständige Geräteprüfung und der mehrtägige Alltagstest sind seit dem
2026-09-13 kein Gate der einzelnen Phase mehr**, sondern ein gemeinsames Gate
am Ende: [Finale Geräte- und Release-Abnahme](#finale-geräte--und-release-abnahme).
Gezielte Gerätetests innerhalb einer Phase bleiben erlaubt und üblich, wo sich
ein hardwareabhängiger Pfad sonst nicht sinnvoll belegen lässt — sie sind dann
**Entwicklungsbelege**, nicht die Abnahme des Produkts. Der Grund für die
Umstellung steht bei Phase 10 unter „Einordnung der Geräteprüfung".

Die Bootstrap-Phase trägt absichtlich den Buchstaben B statt einer Nummer,
damit die fachliche Nummerierung 0–10 stabil bleibt.

Verbindliche Regel: **Kein Feature einer späteren Phase vorziehen.** Wenn
während einer Phase eine gute Idee für später auftaucht, wandert sie in den
Backlog (§ Backlog), nicht in den Code.

**Einmalige, ausdrücklich genehmigte Ausnahme:** Die Phasen **3 und 4** wurden
als ein gekoppelter Meilenstein umgesetzt — eine Implementierung, ein
Gerätetest, ein Commit. Grund: Phase 4 baut unmittelbar auf Phase 3 auf, und
der erste sinnvoll prüfbare Produktzustand ist die vollständige Kette
`Deutsch → Hanzi → Pinyin`. Die Akzeptanzkriterien beider Phasen blieben
getrennt und wurden getrennt abgehakt. **Die Regel „eine Phase auf einmal"
gilt für alle weiteren Phasen unverändert weiter** — diese Ausnahme ist kein
Präzedenzfall.

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
| 11 | Review History & Assisted Assessment | Antwort-Historie, Vorschlag statt Vierfachfrage im sauberen Fall |
| 12 | Session-Sprachmodus | Aufnahme startet je Karte von selbst, beendet wird sie per Tap |
| 13 | Lernflow & Assisted Classification UX | Aufgeben statt Nochmal, Stop im Aufnahmepfad, *Weiter* statt vier Tasten, Einstufung auf Zustimmung |
| 14 | AI-Integration | Umfang noch nicht spezifiziert |

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

**Status: abgeschlossen.** Gerätetest auf physischem iPhone (iOS 26) am
2026-09-07 bestanden: gesamter Lebenszyklus für Wort- und Satzkarten, Suche
inklusive Pinyin ohne Tonzeichen, kombinierte Filter, Kategorienverwaltung mit
Umbenennen und Löschen, Persistenz über einen vollständigen App-Neustart.

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
  Tags, ~~Lernstatus~~. Alle Felder frei editierbar. **Der Lernstatus-Picker
  ist seit dem Gerätetest der Phase 6 entfernt** — Begründung in Task 6.10;
  der Editor schreibt den Status auch nicht mehr.
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
- **2.12** `TagListView`, erreichbar aus der Toolbar der Kartenübersicht:
  bestehende Kategorien **umbenennen** und **löschen**. Umbenannt wird die
  vorhandene `Tag`-Entität selbst — kein neuer Tag, keine Neuzuordnung von
  Karten, dadurch bleiben alle Beziehungen erhalten. Löschen entfernt nur die
  Zuordnung (`.nullify` aus Phase 1), niemals eine Karte. Bestätigung vor dem
  Löschen.
- **2.13** Für den neuen Namen gelten dieselben Regeln wie beim Anlegen
  (trimmen, Case-insensitive Duplikaterkennung, Diakritika **nicht** falten,
  Längengrenze). Zielt der neue Name auf einen bereits vergebenen Namen, wird
  das Speichern verhindert und erklärt — **kein automatisches Zusammenführen**.
  Tag-Merging ist nicht Teil von Phase 2.

### Akzeptanzkriterien
- [x] Eine Wortkarte lässt sich vollständig manuell anlegen, bearbeiten und löschen.
- [x] Eine Satzkarte ebenso.
- [x] Wörter und Sätze sind getrennt sichtbar; ein Umschalten ändert die Liste.
- [x] Suche findet Karten über alle drei Textfelder.
- [x] Filter nach Tag und Lernstatus lassen sich kombinieren.
- [x] ~~Der Lernstatus lässt sich manuell setzen.~~ **Überholt durch den
      Gerätetest der Phase 6** (Task 6.10): Nutzer verwechselten die
      Bewertung eines Versuchs mit dem längerfristigen Kenntnisstand. Der
      Picker ist entfernt; der Status entsteht aus den Selbsteinschätzungen.
      In der Kartenübersicht bleibt er als dezenter Punkt sichtbar.
- [x] Alle Änderungen überleben einen App-Neustart.
- [x] Eine Kategorie lässt sich umbenennen; alle zugeordneten Karten zeigen
      danach den neuen Namen.
- [x] Umbenennen auf einen bereits vergebenen Namen wird verhindert und
      verständlich erklärt, ohne zusammenzuführen.
- [x] Eine Kategorie lässt sich löschen; die zugeordneten Karten bleiben
      erhalten.

### Abhängigkeiten
Phase 1.

### Ausdrücklich nicht in dieser Phase
Automatische Übersetzung, automatische Pinyin-Erzeugung, Audio-Wiedergabe,
Lernmodus, Sortieroptionen, Import/Export, Massenbearbeitung,
**Zusammenführen von Kategorien**.

---

## Phase 3 — Pinyin-Generierung

**Status: abgeschlossen.** Zwei Gerätetests auf dem physischen iPhone
(iOS 26), beide am 2026-09-07. Der erste belegte die fachlichen Kriterien und
fand drei echte Fehler: ein beim Speichern veraltetes Pinyin, ins Pinyin
durchgereichter Nicht-Hanzi-Text und der Fokuswechsel als einziger Auslöser.
Nach den Korrekturen (Tasks 3.9, 4.12, 4.13) hat der zweite Gerätetest die
geänderten Pfade vollständig bestätigt — beide Save-/Race-Wege, Return ohne
Doppeltrigger, die ↻-Bedienelemente, den Nicht-Hanzi-Schutz, das geleerte
Pinyin und den Flugmodus.

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
- **3.5** Einbindung in den Editor: Beim Verlassen des Hanzi-Feldes wird das
  Pinyin automatisch abgeleitet — **nur**, wenn das Pinyin nicht von Hand
  korrigiert wurde. Die Herkunft wird dafür live im Editor-State geführt und
  nicht beim Speichern aus dem gespeicherten Wert erschlossen (Q9).
- **3.6** Sichtbarer Button „Pinyin neu erzeugen“, mit dem der Nutzer die
  Automatik bewusst erneut anstoßen kann.
- **3.7** Bekannte Grenzen (polyphone Zeichen) als kurzen Hinweis im Editor
  erwähnen, ohne aufdringlich zu sein.
- **3.8** Hanzi ist die fachliche Quelle für automatisch erzeugtes Pinyin:
  Ändert der Nutzer das Hanzi, wird das Pinyin danach aus dem **aktuellen**
  Hanzi neu abgeleitet — sofern es nicht von Hand korrigiert wurde.
- **3.9** *Nach dem ersten Gerätetest ergänzt:* Automatisches Pinyin nur aus
  echtem Hanzi. ICU reicht Nicht-Chinesisches durch — am Gerät wurde aus
  `asdf` im Hanzi-Feld das Pinyin `asdf`. Unicode-basierte Han-Erkennung plus
  Plausibilitätsprüfung des Ergebnisses; lässt sich nichts ableiten, wird ein
  **automatisches** Pinyin geleert statt veraltet stehen gelassen, ein
  **manuelles** nie gelöscht. Begründung in
  [architecture.md A20](architecture.md#10-zusammenfassung-der-architekturentscheidungen).

### Akzeptanzkriterien
- [x] `苹果` ergibt `píngguǒ` (mit Tonzeichen).
- [x] Ein Satz ergibt sinnvoll segmentiertes Pinyin mit Tonzeichen.
- [x] Manuell geändertes Pinyin wird von der Automatik nie überschrieben.
- [x] „Pinyin neu erzeugen“ (seit Task 4.13 das ↻ im Pinyin-Feld) überschreibt
      auch manuelle Werte — nach bewusster Nutzeraktion. **Bewusste Verengung:**
      Wenn sich aus dem Hanzi nichts ableiten lässt, löscht auch diese Aktion
      einen manuellen Wert nicht; sie hätte nichts, was sie an seine Stelle
      setzen könnte. Festgenagelt in `invalidHanziKeepsManualPinyin`.
- [x] Die Unit-Tests laufen grün.
- [x] Funktioniert im Flugmodus. *(Beide Gerätetests am 2026-09-07: Hanzi →
      Pinyin im Flugmodus erfolgreich, der zweite mit der geänderten Kette aus
      Han-Prüfung und Plausibilitätsprüfung.)*

### Abhängigkeiten
Phase 2.

### Ausdrücklich nicht in dieser Phase
Übersetzung, Auflösung polyphoner Zeichen über Wörterbücher, Pinyin ohne
Tonzeichen, Zhuyin, Audio.

---

## Phase 4 — Übersetzung Deutsch → Chinesisch

**Status: abgeschlossen.** Zwei Gerätetests auf dem physischen iPhone
(iOS 26), beide am 2026-09-07. Der erste belegte die fachlichen Kriterien und
fand drei echte Fehler: ein beim Speichern veraltetes Pinyin, ins Pinyin
durchgereichter Nicht-Hanzi-Text und der Fokuswechsel als einziger Auslöser.
Nach den Korrekturen (Tasks 3.9, 4.12, 4.13) hat der zweite Gerätetest die
geänderten Pfade vollständig bestätigt — beide Save-/Race-Wege, Return ohne
Doppeltrigger, die ↻-Bedienelemente, den Nicht-Hanzi-Schutz, das geleerte
Pinyin und den Flugmodus.

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
- **4.2** ~~`TranslationService` mit `TranslationSession(installedSource:target:)`~~
  **Überholt in Phase 4:** Der direkte Initializer wird nicht gebraucht.
  `TranslationService` beantwortet nur, *ob* und *womit* übersetzt werden kann;
  die Übersetzung läuft auf der Session aus `.translationTask`.
- **4.3** ~~`TranslationHostView` (unsichtbar)~~ **Überholt in Phase 4:** Es
  gibt keine Host-View. Der Editor trägt `.translationTask` selbst; derselbe
  Modifier liefert die Session **und** holt die Download-Zustimmung — ein
  Codepfad statt zwei. Begründung in
  [architecture.md §5](architecture.md#translationservice).
- **4.4** Zustandsbehandlung im Editor: `installed` → übersetzen;
  `supported` → Download anbieten; `unsupported` → Automatik dauerhaft
  ausblenden, manuelle Eingabe bleibt unverändert möglich.
- **4.5** Editor-Ablauf **ohne Button-Zwang**: Kartentyp wählen → deutschen
  Text eingeben → Feld verlassen → Hanzi wird automatisch gefüllt → Pinyin
  wird daraus abgeleitet → beides prüfbar und korrigierbar. Ausgelöst wird
  beim Verlassen des Feldes, nicht bei jedem Tastendruck.
- **4.6** Übersetzung ist ein **Vorschlag**: Wird Hanzi manuell geändert,
  setzt das `hanziWasEditedManually` und schützt den Wert vor
  Überschreiben.
- **4.7** Fehlerbehandlung: Fehlschlag zeigt einen Inline-Hinweis, blockiert
  aber nie das Speichern.
- **4.8** Falls Q1 negativ ausfällt: Pivot über Englisch als dokumentierten
  Notfallpfad evaluieren — **nicht** implementieren, ohne die
  Qualitätseinbuße vorher an echten Beispielen zu prüfen.
- **4.9** „Neu übersetzen“ als sichtbarer Button: die einzige Freigabe, ein
  von Hand geändertes Hanzi zu überschreiben. Danach gilt Hanzi wieder als
  automatisch, und das Pinyin wird zur neuen Vorlage passend neu abgeleitet —
  auch, wenn es zuvor von Hand korrigiert war.
- **4.10** Keine veralteten Ergebnisse: Ändert der Nutzer den deutschen Text
  mehrfach schnell, darf ein älteres Übersetzungsergebnis den neueren Text
  niemals überschreiben.
- **4.11** Übersetzungsstrategie und Verfügbarkeitsprüfung gegen die
  **aktuelle** Apple-Dokumentation entscheiden und begründen, nicht gegen die
  Planungsannahme aus Phase 0.
- **4.12** *Nach dem ersten Gerätetest ergänzt:* Der Editor synchronisiert
  seinen Zustand **vor** dem Speichern, und zwar gegen die **Quelle** des
  aktuellen automatischen Pinyins, nicht gegen „hat sich das Hanzi geändert".
  Am Gerät wurde `水` mit dem Pinyin `miànbāo` gespeichert, weil direkt aus dem
  Hanzi-Feld gespeichert wurde und kein Fokusereignis kam; ein zweiter Weg zum
  selben Fehler führte über eine Übersetzung, die eintrifft, während der Nutzer
  ein eigenes Hanzi tippt. Korrektheit darf nicht von SwiftUI-Fokusereignissen
  abhängen; die Regel ist ohne View testbar. Begründung in
  [architecture.md A19](architecture.md#10-zusammenfassung-der-architekturentscheidungen).
- **4.13** *Nach dem ersten Gerätetest ergänzt:* Return/„Fertig“ schließt die
  Eingabe ab — Tastatur zu, Fokus weg, dieselbe Automatik wie beim
  Fokusverlust, und **kein** zweiter Übersetzungslauf durch beides zusammen.
  Die beiden separaten Buttons entfallen; „Neu übersetzen“ und „Pinyin neu
  erzeugen“ sitzen als natives ↻ direkt im jeweiligen Feld, mit unveränderter
  Semantik und Accessibility-Label. Begründung in
  [architecture.md A21](architecture.md#10-zusammenfassung-der-architekturentscheidungen).

### Akzeptanzkriterien
- [x] Q1 ist mit einem konkreten Messergebnis beantwortet und dokumentiert.
      *(Gerätetest 2026-09-07: `installed`, siehe
      [apple-frameworks.md §10](apple-frameworks.md#10-offene-technische-fragen-zu-klären-vor-der-jeweiligen-phase).)*
- [x] Aus „Apfel“ entsteht eine plausible Hanzi-Ausgabe mit passendem Pinyin.
      *(Gerätetest: `苹果` / `píngguǒ`.)*
- [x] Aus einem deutschen Satz entsteht eine plausible chinesische Übersetzung.
      *(Gerätetest: „Ich möchte etwas essen.“ → `我想吃点东西`.)*
- [x] Eine manuell korrigierte chinesische Formulierung bleibt erhalten.
- [~] Bei nicht installierten Sprachen erscheint der System-Download-Dialog.
      **Bedingtes Kriterium, Bedingung nicht eingetreten:** Auf dem Testgerät
      sind die Modelle installiert (Q1 = `installed`, Übersetzung läuft im
      Flugmodus), also kann der Dialog nicht erscheinen. Ausbleiben ist hier
      korrektes Verhalten und blockiert die Phase nicht. Die App baut keine
      eigene Download-Infrastruktur: den Dialog löst allein Apples
      `.translationTask` aus. Ungeprüft bleibt damit nur der Pfad auf einem
      Gerät ohne Modelle.
- [x] Bei fehlgeschlagener Übersetzung lässt sich die Karte trotzdem speichern.

### Abhängigkeiten
Phasen 2 und 3.

### Ausdrücklich nicht in dieser Phase
Rückübersetzung Chinesisch → Deutsch, mehrere Übersetzungsvorschläge zur
Auswahl, Batch-Übersetzung bestehender Karten, Audio.

---

## Phase 4.5 — Pinyin Accuracy + Karten-/Editor-Politur

**Status: abgeschlossen.** Gerätetest auf physischem iPhone (iOS 26) am
2026-09-08 bestanden: CC-CEDICT-Auflösung, Prüfhinweis bei nicht eindeutigen
Fällen, geschützte manuelle Korrektur, ↻ setzt den Hinweis neu, Konsistenz
nach App-Neustart, vollständige Pipeline offline, kein merkbares Stocken beim
ersten Öffnen des Editors, sowie die gesamte UI-Politur. Zwischenphase,
eingeschoben nach dem Gerätetest der Phasen 3+4. Phase 5 bleibt davon
unberührt.

### Ziel
Zwei getrennte Themen aus dem Gerätetest abarbeiten. Erstens und wichtiger:
Der reine ICU-Pfad erzeugt bei **gültigem** Chinesisch sprachlich falsche
Lesungen. Zweitens: Karten- und Editor-Oberfläche kompakter und ruhiger
machen.

Belegt am Gerät: `Ich möchte etwas essen.` → `我想吃点东西` ergab
`wǒ xiǎng chī diǎn dōngxī`. Im Sinn „Ding/etwas" ist `dōngxi` mit neutralem
`xi` zu erwarten; der Apple-native Fallback liefert sogar nur `dōng xī`.
Reine Transliteration reicht damit nicht als alleinige Quelle.

### Scope
`PinyinService` (Resolver), `ChineseLexicon`, `PinyinTone`, gebündelte
CC-CEDICT-Daten, Editor-Hinweis, Karten- und Editor-UI. **Nicht** angefasst:
`TranslationService`, Race-Schutz, Card-CRUD, Tagging, `LearningStatus`,
SwiftData-Query-Strategie.

### Tasks

**Teil A — Pinyin Accuracy**

- **4.5.1** **Research zuerst.** Lokale lexikalische Datenquelle suchen und
  bewerten: vereinfachtes Chinesisch, Wort-/Phraseneinträge, mehrere
  Lesungen, neutrale Töne, Glossen, Offline-Nutzung, Bundle-taugliche Größe,
  Lizenz, die das Bündeln erlaubt. Ergebnis dokumentieren, **Datenquelle
  bevorzugt gegenüber einer Laufzeit-Dependency**. *Ergebnis:* CC-CEDICT,
  CC BY-SA 4.0, 125.009 Einträge. Herkunft, Lizenz, Version und alle
  Ableitungen in
  [SOURCE.md](../CApp/Resources/ThirdParty/CC-CEDICT/SOURCE.md) und
  [ATTRIBUTION.md](../CApp/Resources/ThirdParty/CC-CEDICT/ATTRIBUTION.md).
- **4.5.2** Datenbestand **messen, bevor** gebündelt wird: Dateigröße,
  nutzbare Einträge, Parse-Zeit, Speicherbedarf, Bundle-Zuwachs. Messwerte in
  [architecture.md §5](architecture.md#5-services) und SOURCE.md.
- **4.5.3** Ableitung als Daten-Asset über ein reproduzierbares Skript
  (`tools/generate-cedict-asset.py`, nicht Teil des App-Targets). Rohdatei
  bleibt außerhalb des Repositories.
- **4.5.4** `PinyinTone`: Tonziffern → Tonzeichen als reine, vollständig
  getestete Funktion. Töne 1–4, neutraler Ton 5 **ohne** Zeichen, `ü` und
  die `u:`-Schreibweise, korrekte Zeichenplatzierung, Groß-/Kleinschreibung.
  Nicht über ICU lösen, wenn eine reine Funktion genügt.
- **4.5.5** Auflösungs-Pipeline: eindeutiger Lexikoneintrag → chinesischer
  Kontext über die längste bekannte Phrase → ansonsten **nicht raten**,
  sondern ICU-Fallback mit `needsReview`. Wortgrenzen von ICU, Lesungen vom
  Lexikon (A23).
- **4.5.6** `PinyinResolution` mit `text`, `source` und `needsReview`.
  Kategorial, **keine** Confidence-Werte. Sobald ein fachlich relevanter Teil
  auf Fallback beruht, gilt das Gesamtergebnis als prüfbedürftig.
- **4.5.7** Sichtbarer, **situativer** Hinweis direkt unter dem Pinyin-Feld,
  wenn `needsReview`: „Pinyin konnte nicht eindeutig bestimmt werden. Bitte
  prüfen." Kein Dauertext, nicht alarmistisch, keine Behauptung, der Wert sei
  falsch. Manuelle Korrektur beendet den Hinweis, das ↻ setzt ihn neu.
- **4.5.7a** Bekannte Grenze, bewusst so: Wer Deutsch tippt, Hanzi tippt und
  sofort speichert, speichert ein prüfbedürftiges Pinyin, ohne den Hinweis
  gesehen zu haben — blockieren darf der Editor nach Regel 5 nicht. Beim
  Wiederöffnen der Karte steht der Hinweis da, weil der Zustand abgeleitet
  wird.
- **4.5.8** Warnzustand **abgeleitet**, nicht persistiert: Der Resolver ist
  rein und offline, also beantwortet das gespeicherte Hanzi die Frage beim
  Öffnen erneut. Keine Schemaänderung.
- **4.5.9** Spike Deutsch → englische Glossen. *Ergebnis:* kein tragfähiger
  lokaler Weg unter den Projektregeln, Begründung in
  [architecture.md A24](architecture.md#10-zusammenfassung-der-architekturentscheidungen).
  Nicht durch eine Heuristik ersetzt.
- **4.5.10** Schutzmechanismen aus Phase 3/4 unverändert erhalten:
  `pinyinSourceHanzi`, Q9-Herkunftslogik, Race- und Stale-Schutz, beide
  Manuell-Merker, Save-Reconciliation, Han-Erkennung,
  Plausibilitätsprüfung.

**Teil B — UI-Politur**

- **4.5.11** `Karten` als kompakter, zentrierter Navigation-Bar-Titel. Links
  das Kategoriensymbol, rechts Filter und `+`. Native Toolbar, keine
  nachgebaute Leiste. Bottom-Navigation unverändert.
- **4.5.12** Lernstatus und Kategorien wandern von zwei Dauer-Controls auf
  ein Filter-Sheet hinter einem Symbol. Filtersemantik unverändert,
  Zurücksetzen enthalten.
- **4.5.13** Aktiver Filter erkennbar über das **gefüllte** Symbol, dazu ein
  gesprochenes Accessibility-Label mit der Anzahl aktiver Gruppen. Kein
  Badge-Zirkus, keine Gamification.
- **4.5.14** Reihenfolge im Kartenbildschirm: Navigationsleiste, Suche,
  Wörter/Sätze, Liste. Keine zusätzliche Filterzeile.
- **4.5.15** Kategorienverwaltung bleibt ein eigener Knopf mit dem Label
  „Kategorien verwalten" und öffnet weiterhin `TagListView`. Nicht mit dem
  Filter zusammenlegen (A25).
- **4.5.16** Satzkarten: Deutsch, Hanzi und Pinyin wieder mehrzeilig
  editierbar, Abschluss über „Fertig" in der Tastatur-Toolbar. Wortkarten
  bleiben einzeilig mit Return. **Kein** Doppel-Trigger, Race-Schutz
  unverändert.
- **4.5.17** Permanente Erklärungstexte entfernen — Pflichtfelder,
  ↻-Erklärung, allgemeiner Vorschlag- und Polyphonie-Hinweis. Situative
  Hinweise bleiben. Faustregel: Dauertext weg, konkreter Zustand hin.

### Akzeptanzkriterien
- [x] `苹果` → `píngguǒ`, `谢谢` → `xièxie`, `早上` → `zǎoshang`, `钱` → `qián`.
- [x] Der chinesische Kontext löst Mehrdeutigkeit: `买东西` → `mǎi dōngxi`,
      `东西南北` → `dōngxī nánběi`, `早上好` → `zǎoshang hǎo`, jeweils **ohne**
      Warnung.
- [x] Ein nicht auflösbares Wort fällt auf ICU zurück und setzt
      `needsReview` — `东西` allein und `我想吃点东西`.
- [x] Ein vollständig aufgelöstes Ergebnis setzt **keinen** Warnzustand.
- [x] Manuelle Pinyin-Korrektur beendet den Warnzustand, das ↻ setzt ihn neu.
- [x] Der Warnzustand wird beim Öffnen einer bestehenden Karte korrekt neu
      abgeleitet, ohne Schemaänderung.
- [x] Nicht-Hanzi-Schutz, Plausibilitätsprüfung, Save-Reconciliation und
      `pinyinSourceHanzi` bleiben grün.
- [x] Auflösung funktioniert ohne Übersetzung und ohne Netz.
- [x] Filterlogik: `hasActiveFilters`, Gruppenzählung, Zurücksetzen,
      kombinierte Filter.
- [x] Build und Tests grün, Debug und Release, warnungsfrei.
- [x] Gerätetest: Auflösung, Prüfhinweis, ↻, Flugmodus. *(2026-09-08:
      `谢谢`→`xièxie`, `早上`→`zǎoshang`, `钱`→`qián`, `买东西`→`mǎi dōngxi` und
      `东西南北`→`dōngxī nánběi` je ohne Hinweis; `东西` und der Satz
      `我想吃点东西` mit Hinweis; manuelle Korrektur geschützt und
      hinweisfrei; ↻ setzt ihn wieder; Warnzustand nach Neustart konsistent;
      Pipeline offline vollständig.)*
- [x] Gerätetest: Navigationsleiste, Filter-Sheet, aktiver Filter, Suche,
      Wörter/Sätze, mehrzeilige Satzfelder, „Fertig", entfallene Dauertexte.
      *(2026-09-08 bestanden, „Fertig" ohne Doppeltrigger, direkter Save aus
      fokussierten Feldern korrekt, Persistenz und bestehende
      Kartenfunktionen unverändert.)*

### Abhängigkeiten
Phasen 3 und 4.

### Ausdrücklich nicht in dieser Phase
Zweite Wörterbuchquelle (erst nach Messung des Restbedarfs), deutsche
Bedeutungsauflösung, Glossen im Asset, Aussprachebewertung, ML- oder
LLM-Auflösung, generische NLP-, Repository- oder DI-Architektur, jede
Phase-5-Funktionalität.

---

## Phase 5 — Learning Engine (ohne UI)

**Status: abgeschlossen.** Reine Foundation-Logik, deshalb **ohne
Gerätetest** — kein Akzeptanzkriterium dieser Phase ist geräteabhängig, es
gibt keine UI und keinen Persistenzpfad. Das Gate stützt sich auf Debug- und
Release-Build, die vollständige Testsuite, den Import-/Scope-Audit,
Determinismus, Terminierung, Laufzeit und die beiden Reviews. Q8 ist mit
dieser Phase geschlossen.

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
- **5.9** *Q8 abgeschlossen:* Actor-Isolation mit zwei Compile-Spikes
  gemessen, Variante A gewählt (Target behält den MainActor-Default,
  `Learning/` ist einzeln `nonisolated`). `project.pbxproj` unverändert.
  Messwerte in
  [apple-frameworks.md §10, Q8](apple-frameworks.md#10-offene-technische-fragen-zu-klären-vor-der-jeweiligen-phase).

**Bewusst nicht gebaut:** `batchSize` ist **kein** Parameter von
`BatchSelector.selectBatch`. Die in §8 vorgesehene Verstellbarkeit (5–10)
muss zwei Stellen erreichen — die Auswahl **und** die Recency-Schwelle von
zwei Batches. Eine Größe nur an der Auswahl vorbeizuführen hätte die Schwelle
still auf dem alten Wert gelassen; im Review als solches gefunden und die
ungenutzte Stellschraube deshalb entfernt.

### Akzeptanzkriterien
- [x] Alle 19 spezifizierten Tests laufen grün. *(Einzeln vorhanden und mit
      `§10, test N` zugeordnet; die Zuordnung wurde im Audit inhaltlich
      geprüft, nicht nur die Kommentare.)*
- [x] Der Ordner `Learning/` importiert nichts außer `Foundation`. *(Neun
      Dateien, neun `import Foundation`, null Treffer für SwiftUI, SwiftData,
      `@Model`, `ModelContext`, `@Query`, `@Observable`, `Date()` oder Zufall
      ohne injizierten Generator.)*
- [x] Gleicher RNG-Seed liefert reproduzierbar dieselbe Auswahl.
      *(Gegenprobe: globaler Zufall statt injiziertem Generator macht
      `sameSeedSameResult` rot.)*
- [x] Ein Batch der Größe 1 mit dauerhaftem „Nochmal“ terminiert.
      *(Als Invariante geprüft, mit Schranke; Gegenprobe: entfernte
      `maxReinserts`-Guard und Off-by-one werden beide erkannt.)*
- [x] Die Testsuite läuft in unter einer Sekunde. *(Die 32 Phase-5-Tests:
      langsamster Einzeltest 0,052 s. Die **gesamte** Suite mit 250 Tests
      liegt darüber, weil die SwiftData- und Lexikon-Suiten aus früheren
      Phasen dazugehören — das ist nicht Gegenstand dieses Kriteriums.)*

### Abhängigkeiten
Phase 1 (nur für die Enums `LearningStatus` und `CardType`).

### Ausdrücklich nicht in dieser Phase
Lern-UI, Persistieren von Antworten, Spaced Repetition, Audio,
Spracherkennung.

---

## Phase 6 — Lernmodus A: Deutsch → Chinesisch

**Status: abgeschlossen.** Physischer Gerätetest am **2026-09-08** vollständig
bestanden, nach drei Korrekturrunden: die erste am Lernbildschirm und am
Karteneditor (Tasks 6.10 bis 6.14), die zweite am Kategorienfilter und an der
Tastatur (6.15, 6.16), die dritte an zwei Regressionen derselben
Container-Gesture — erst legte `Hinzufügen` keine Kategorie mehr an, dann ließ
sich keine Kategorie mehr an- oder abwählen. Beide sind über den in
[A27](architecture.md#10-zusammenfassung-der-architekturentscheidungen) hinterlegten
Rückweg erledigt: Die Gesture ist entfernt, jeder Weg aus der Tastatur liegt in
der Aktion des angetippten Controls.

Stand des Gates: **296 Tests grün**, 0 fehlgeschlagen, 0 übersprungen, 0
Compilerwarnungen auf einem Debug-Build von null; Release-Build von null
ebenfalls grün und warnungsfrei. Dazu drei Runden `code-reviewer` und
`test-auditor` sowie Gegenproben durch Mutation für die ODER-Semantik des
Lernfilters, die Poolbildung, die Store-Deduplizierung und den Selection-State
der Kategorien.

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

*Nach dem ersten physischen Gerätetest ergänzt:*

- **6.10** Kein manueller `Lernstatus` mehr im Karteneditor. Der Gerätetest
  hat gezeigt, dass Nutzer die Bewertung **eines Versuchs** und den
  **längerfristigen Kenntnisstand** für dasselbe halten — begriffliche
  Trennung jetzt in
  [learning-engine.md §2](learning-engine.md#2-begriffe). Neue Karten starten
  intern auf `new`, bestehende behalten ihren Wert. **Keine** Migration der
  fünfstufigen Skala, keine Änderung der Gewichtung.
- **6.11** `Hinzufügen` im Karteneditor legt die Kategorie unmittelbar an und
  persistiert sie; sie überlebt das Abbrechen der Karte. Kein „neu"-Badge,
  kein Löschsymbol im Editor — ein Tap wählt nur zu oder ab. Überholt A14,
  Begründung dort.
- **6.12** Tastatur-`Fertig` nur bei Deutsch, Hanzi und Pinyin, nicht beim
  Kategoriennamen. Getrennter Fokuszustand, Race- und Submit-Logik aus
  Phase 3/4 unverändert.
- **6.13** Lernen-Screen wie die Kartenansicht: kompakter zentrierter Titel,
  Kategorienfilter als Toolbar-Knopf mit gefülltem Symbol bei aktiver
  Auswahl, keine Dauer-Kategoriensektion, keine „Inhalt"-Überschrift, keine
  Richtungs-Control (es gibt nur eine Richtung), kein „Auswahl aufheben".
- **6.14** **Queue-Korrektur aus dem Gerätetest:** Eine Wiederholung liegt
  hinter jeder noch ungesehenen Karte, und `maxReinserts` ist 1. Physisch
  reproduziert war ein Zyklus `A B C D A B C D`, während E, F und G nie
  gezeigt wurden. Details und Begründung in
  [learning-engine.md §5](learning-engine.md#5-queue-und-wiedereinstreuung);
  die alte Regel ist dort als überholt gekennzeichnet.
- **6.15** **Kategorienfilter im Lernen verknüpft mit ODER.** Zwei gewählte
  Kategorien üben die Vereinigung beider Mengen, nicht den Schnitt. Im
  Gerätetest leerte die Wahl einer zweiten Kategorie die Session, weil kaum
  eine Karte in zwei Kategorien liegt. Die Kartenliste behielt damals UND,
  weil die beiden Bildschirme verschiedene Fragen zu stellen schienen —
  Begründung in
  [architecture.md A26](architecture.md#10-zusammenfassung-der-architekturentscheidungen).
  Der Kartentyp bleibt außerhalb dieser Regel — Wörter und Sätze mischen sich
  nie. **Nachtrag:** Der Satz „die Kartenliste behält UND" gilt nicht mehr.
  Dasselbe Argument — kaum eine Karte liegt in zwei Kategorien — hat später
  auch die Kartenliste auf ODER gebracht, siehe
  [architecture.md A32](architecture.md#10-zusammenfassung-der-architekturentscheidungen).
- **6.16** **Die Tastatur der Kategorieneingabe lässt sich wieder schließen.**
  Jeder Weg aus der Tastatur liegt **in der Aktion des Controls**, das der
  Nutzer angefasst hat: `Hinzufügen` legt die Kategorie an und gibt danach —
  und nur bei Erfolg — den Fokus frei; ein Tap auf eine Kategorie schaltet
  **zuerst** die Auswahl um und gibt den Fokus danach frei; Wischen schließt
  über `scrollDismissesKeyboard(.interactively)`. **Am Formular hängt keine
  Tap-Gesture**, siehe unten. Damit schließt ein Tap auf völlig freie Fläche
  die Tastatur nicht mehr — bewusst aufgegeben. Die Regel aus 6.12 gilt
  unverändert weiter.

  **Zwei Regressionen aus dem Gerätetest, beide von derselben
  Container-Gesture:** Die erste Fassung benutzte `simultaneousGesture` —
  später zusätzlich räumlich begrenzt über `SpatialTapGesture` plus
  `onGeometryChange`. Simultane Erkennung verschluckt einen Tap nicht,
  **konkurriert aber mit der Aktivierung eines Buttons**: Ein Tap auf
  `Hinzufügen` schloss nur die Tastatur, die Kategorie wurde nie angelegt,
  und weitere Taps blieben ebenso wirkungslos. Der räumliche Ausweg war damit
  doppelt falsch — er löste ein Problem, das die Standardpriorität gar nicht
  hat, und behielt die Ursache. Die zweite Fassung nahm deshalb `.gesture`
  mit Standardpriorität, bei der laut Doku jedes Control den Tap gewinnt.
  Auch das ist am Gerät gescheitert: Danach ließ sich **keine Kategorie mehr
  an- oder abwählen**, Auswahl entstand nur noch beim Anlegen. Drei Varianten
  gemessen, drei gescheitert — die Gesture ist jetzt vollständig entfernt und
  wird nicht durch eine fünfte ersetzt. Die Lehre daraus steht als Entscheidung
  [A27](architecture.md#10-zusammenfassung-der-architekturentscheidungen), weil sie über
  diese Phase hinaus gilt — samt dem festgelegten Rückweg: Verliert am Gerät
  doch ein Control seine Aktion, wird die Container-Gesture **entfernt** und
  die freie Fläche kostet eine Wischbewegung. Kein Ausweichen auf
  `simultaneousGesture` und keine räumliche Eingrenzung; beides ist gemessen
  gescheitert. Ein Button in einer `Form`-Zeile braucht zudem
  `.buttonStyle(.borderless)`, sonst wirkt die ganze Zeile als Button.

### Akzeptanzkriterien
- [x] Eine Session mit Wörtern lässt sich starten und durchlaufen.
- [x] Eine Session mit Sätzen ebenso; die Typen werden nie gemischt.
- [x] Nach „Nochmal“ erscheint die Karte erst nach mehreren anderen wieder.
- [x] Nach der siebten aufgelösten Karte folgen automatisch weitere Karten.
- [x] Der Lernstatus ändert sich gemäß Übergangsmatrix und ist in der
      Kartenübersicht sichtbar.
- [x] Die Änderungen überleben einen App-Neustart.
- [x] Nirgends erscheinen Herzen, Streaks, Timer oder Limits.

### Abhängigkeiten
Phasen 2 und 5.

### Ausdrücklich nicht in dieser Phase
Audio-Wiedergabe, Spracherkennung, Modus B, Statistiken, Session-Verlauf,
Wiederaufnahme einer unterbrochenen Session.

---

## Phase 6.5 — Pinyin & Pronunciation Accuracy Hardening

**Status: abgeschlossen.** Zwischenphase, vor Phase 7 eingeschoben. Der
physische Gerätetest lief am **2026-09-09** durch, in zwei Läufen: der
Hauptdurchlauf über Neutralton, dritten Ton, `一`, `不` und Polyphone samt
manueller Korrektur, ↻ und Persistenz, und danach ein gezielter Nachtest über
die Änderungen des Accuracy Pass. Bestätigt am Gerät: `一个` → `yí ge`,
`我有一个问题` → `wǒ yǒu yí ge wèntí`, `一号` → `yí hào`, `千禧一代` →
`Qiānxǐ Yī dài`, `不看` → `bù kàn`, `很好` → `hěn hǎo` mit Prüfhinweis.
`cedict-base-tones.txt` ist auf dem Gerät wirksam, das Editor-Sheet stockt
beim ersten Öffnen nach vollständigem Neustart nicht, Flugmodus funktioniert.
**Alle sechs Gerätewerte sind deckungsgleich mit der Simulatormessung.**

### Gemessener Stand

| | |
| --- | --- |
| Golden Corpus | **372 Fälle** in elf Kategorien |
| davon mit Aussprache-Erwartung | 347 |
| exakt getroffen | **343 / 347 = 98,8 %** |
| Wortgrenzen (Kategorie K) | 0 Abweichungen |
| falsch gesetzte Prüfhinweise | 0 |
| Tests | **373 grün**, 0 Warnungen, Debug und Release von null |

Der Prozentwert gilt für **genau diesen Corpus**, nicht für beliebigen Text.
Es gibt bewusst keine Schwelle auf der Quote — statt einer Zahl prüft
`goldenCorpus()` die Fehlermenge **namentlich** gegen
`PinyinCorpusTests.knownFailures` plus leere Review- und Abstandslisten. Das
wirkt in beide Richtungen: eine neue Abweichung wird rot, eine behobene muss
dort erst gestrichen werden.

Der Resolver-Aufwand der neuen Schicht liegt im Messrauschen, gegengeprüft mit
abgeschalteter Sandhi-Schicht. Lexikon kalt 100 ms, Grundton-Abfrage 0 ms,
Wort 0,28 ms, langer Satz 0,57 ms.

### Was entstanden ist

- **`PinyinSyllable`** — strukturierte Zwischenrepräsentation mit sieben
  Feldern: Hanzi, Buchstaben ohne Tonzeichen, **lexikalischer Ton**
  (Oberfläche), **Oberflächenton** (was gesprochen wird), **Grundton** (was
  eine Nachbarregel auslöst), **Unit-Nummer** (Wort), **Fuß-Nummer**
  (Konstituente im Wort), Wortanfang. Die letzten drei sind der eigentliche
  Inhalt dieser Phase.
- **`ToneSandhi`** — reine Funktion, importiert nur `Foundation`,
  `nonisolated`, **33 eigene Tests in 41 Fällen**. Eine Silbe schreibt immer
  nur ihren *eigenen* Oberflächenton; welchen Ton eine Regel **liest**, ist
  dagegen von Fall zu Fall verschieden und in
  [A28](architecture.md#10-zusammenfassung-der-architekturentscheidungen)/[A30](architecture.md#10-zusammenfassung-der-architekturentscheidungen)
  festgehalten: erster Dritt-Ton-Zyklus lexikalisch, zweiter Zyklus über die
  Fußgrenze auf dem Oberflächenton, `一`/`不` auf dem Grundton des Nachbarn.
  Diese drei auseinanderzuhalten ist nicht Pedanterie — wer den zweiten
  Zyklus für redundant hält und „aufräumt", stellt `xiáoláoshǔ` wieder her.
- **`PinyinService.footSplit`** — bestimmt die Klammerung über Teil-Stichwörter
  (längstes Präfix, längstes Suffix; genau eines bekannt entscheidet, sonst
  Teilung in der Mitte als konservativer Fall).
- **`cedict-base-tones.txt`** — 407 Zeilen, Grundtöne reduzierter Silben,
  abgeleitet aus dem schon gebündelten `cedict-readings.txt` von
  `tools/generate-cedict-base-tones.py`. Keine neue Datenquelle;
  Herkunft, Verfahren und Lizenz in
  [SOURCE.md](../CApp/Resources/ThirdParty/CC-CEDICT/SOURCE.md).
- **`PinyinResolution.transformations`** — kategorial `thirdTone`, `yi`, `bu`.
  Keine Confidence, kein Ereignisprotokoll.
- Satzzeichen bleiben als tonlose Grenze in der Silbenkette erhalten, sonst
  hätte `他不。对了` über den Punkt hinweg `bú` ergeben.
- Golden Corpus in `CAppTests/Resources/`: der datengestützte Teil aus
  `tools/generate-pinyin-corpus.py`, die regelkritischen Kategorien E, F, G,
  J und K von Hand. **Keine Schemaänderung, kein Netzzugriff.**

### Die zwei offenen Entscheidungen, beide geschlossen

1. **Sandhi über Wortgrenzen?** Beim dritten Ton **nein** — nur innerhalb
   einer Lexikoneinheit, und dort zusätzlich zyklisch je Konstituente, weil
   die Realisierung über Grenzen hinweg prosodisch variabel ist (A28). Bei
   `一` und `不` **ja** — diese Regeln hängen am Zeichen und an der
   unmittelbar folgenden Silbe, nicht an einer Domäne; deshalb wird `一天` zu
   `yìtiān`, obwohl es kein Stichwort ist.
2. **`一下` und `一点`: Lexikon oder Regel?** Beides, in dieser Reihenfolge.
   Das Lexikon liefert die **lexikalische** Lesung (`yi1 xia4`, `yi1 dian3`),
   die Regel leitet daraus die gesprochene Form ab (`yíxià`, `yìdiǎn`). Die
   beiden Wege widersprechen sich nicht, sobald man sie als zwei Schichten
   liest statt als Alternativen — genau das ist die Trennung, die diese Phase
   eingeführt hat.

### Accuracy Pass — was aus den sechs Restfehlern wurde

| | |
| --- | --- |
| Restfehler vor dem Pass | 6 |
| algorithmisch behoben | **3** — `一个` und seine zwei Satzvorkommen |
| Goldwert korrigiert | 0 |
| als echte Mehrdeutigkeit umgebucht | 0 |
| prosodisch variabel | 0 |
| verbleibende echte Fehler | **4**, alle Datenlücke |

Die letzte Zeile ist eine mehr als drei behobene aus sechs erwarten lässt, und
das hat einen Grund: `不看` war vor dem Pass ein Restfehler, ich hatte es
**aus dem Messsatz genommen**, und das wurde zurückgenommen — siehe unten.

**Behoben, Klasse B (verlorene lexikalische Information) — `一个`.** Kein
Sonderfall, sondern ein Datenmodellproblem: `一个` ist `yi1 ge5`, gesprochen
`yíge`, weil die `一`-Regel vom **Grundton** des folgenden Zeichens ausgelöst
wird und nicht vom neutralen Ton an der Oberfläche. `PinyinSyllable`
unterscheidet jetzt beides; die Reduktion bleibt in der Ausgabe erhalten.

Den Grundton liefert `cedict-base-tones.txt`. Verfahren: zählen, welche Töne
jede Silbe über alle reinen Han-Stichwörter annimmt, den **vorherrschenden**
nehmen ab 90 % der Nicht-Neutral-Vorkommen, bei **mindestens fünf** Belegen.
Vorherrschend statt eindeutig ist wesentlich — `个` liest `ge4` 86-mal, `ge5`
43-mal, `ge3` genau einmal, und wer Eindeutigkeit verlangt, bekommt für den
entscheidenden Fall keine Antwort. Die Mindestevidenz kam aus dem Review:
ohne sie ruhten 59 Zeilen auf ein bis drei Belegen, und `们 men` ergab 2 allein
aus dem Ortsnamen 图们, nicht aus einem Vollton des Pluralsuffixes. **407 von
538** reduzierten Silben bekommen so einen Grundton; die übrigen **131**
antworten `nil`, und `nil` heißt „keine Regel anwenden".

Vorberechnet statt zur Laufzeit gezählt, weil derselbe Zensus gemessen 314 ms
kostet und `ChineseLexicon` auf dem Main Actor liegt — im `.task` des Editors
wäre das ein merkbares Stocken.

**Reichweite, ehrlich:** 407 Zeilen sind nicht 407 wirksame Antworten. Über
den ganzen gebündelten Bestand stehen nur vier Silbenpaare `一`/`不`
unmittelbar vor einer reduzierten Silbe, und **`一`+`个` ist das einzige, bei
dem der Mechanismus die Ausgabe tatsächlich verändert** — bei `不`+`得` ist
`不` meist selbst lexikalisch neutral, bei `不`+`儿` und `不`+`是` wird der
Grundton nie gefragt. Die übrigen Regelzweige sind synthetisch in
`ToneSandhiTests` festgehalten, nicht am Bestand gemessen. Das Zählen kam aus
den beiden Reviews; meine erste Formulierung „466 Silben" legte eine
Reichweite nahe, die die Daten nicht tragen.

**Meine zurückgenommene Fehlentscheidung — `不看`.** Ich hatte `不看` samt
`不难`, `不喝` und `不说` nach Kategorie J umgebucht, mit der Begründung, für
denselben Fall eine Aussprache **und** einen Prüfhinweis zu erwarten sei
widersprüchlich. Das Review hat es widerlegt: Die Konjunktion ist der
**informativste** Fall — `needsReview` sagt „die App ist unsicher", der
Sollwert sagt „so ist es richtig", zusammen „unsicher und falsch". Die
J-Politik gilt für Fälle, in denen die *Wahrheit selbst* unentscheidbar ist
(`东西`); `不看` ist keiner, dort ist `看` das `kàn` von „nicht ansehen" und
die Lernform determiniert. Die Umbuchung hätte einen messbaren Fehler aus dem
Satz genommen und die Quote von 98,8 auf 99,1 % geschmeichelt — zwei
Maßstäbe, während `一号`, `千禧一代` und `水果酒` mit dem richtigen Sollwert
stehen bleiben. **Zurückgenommen**; alle vier stehen wieder mit Sollwert und
Prüfhinweis im Messsatz.

**`一号` bleibt ein Fehler, aber nicht der, den ich vermutet hatte.** Die
Normfrage war zu klären, bevor eine Seite angepasst wird. Belegt: `一月一号`
ist `yī yuè yī hào` — als Ordnungs- und Datumsangabe behält `一` den
Grundton. Der Corpus-Sollwert war also **richtig** und die App liegt falsch.
Damit greift der Korrekturzweig „Goldwert reparieren" hier gerade nicht.

### Bekannte Grenzen, gemessen statt behauptet

Alle vier stehen mit dem **sprachlich richtigen** Sollwert im Corpus und
namentlich in `PinyinCorpusTests.knownFailures`, tauchen also in der Messung
auf statt in einer Wortliste zu verschwinden.

- **`一号`** — Ordnungs- und Datumsangabe, siehe oben. Ob ein `一` zählt oder
  benennt, ist semantisch; CC-CEDICT trägt die Klassifikator-Markierung in
  den **englischen Glossen**, und die hat das Asset verworfen. Konkreter
  Vorschlag für eine spätere Phase: eine Klassifikator-Kennzeichnung ins
  Asset aufnehmen, dann ist die ganze Ordnungszahl-Klasse lösbar (`一号`,
  `一楼`, `一年级`).
- **`千禧一代`** — CC-CEDICT schreibt `Yi1` groß, obwohl es kein Eigenname
  ist, und der Eigennamen-Guard fällt darauf herein. Den Guard zu streichen
  ist schlechter: dann käme in jedes `不列颠`-Kompositum ein falsches `bú`.
  Die Alternativen sind im Review an den Daten durchprobiert — „nur wenn die
  Silbe die erste des Stichworts ist" repariert `千禧一代`, bricht aber
  `一带一路`. Im vorhandenen Signal gibt es keine bessere Regel.
- **`水果酒`** — das Wort **ist** ein Stichwort und bildet eine Unit; Ursache
  ist die Fuß-Heuristik. `水果` **und** `果酒` sind Stichwörter, damit ist die
  Klammerung unbelegt, es greift die Mittelteilung, und `水` behält seinen
  dritten Ton. Das Leerzeichen im Ergebnis kommt von ICUs Segmentierung, der
  Tonfehler nicht. (Zuerst stand hier eine Fehldiagnose auf die Domänenregel
  — vom Audit gefunden.) **Kein anderer Tie-Break hilft, und das ist gemessen
  statt behauptet:** Linkspräferenz repariert `水果酒`, bricht aber `小雨伞`
  (`[小[雨伞]]`, kleiner Regenschirm); Mitte und Rechtspräferenz umgekehrt.
  Über die unentscheidbaren Fälle des Corpus treffen alle drei gleich oft. Es
  ist ein echter Tausch zwischen zwei Wörtern, nicht ein behebbarer Fehler —
  die Frequenzinformation, die ihn entscheiden würde, steht nicht im Asset.
- **`不看`** — `看` ist mehrdeutig, kommt tonlos bei der Regel an und kann sie
  nicht auslösen. Der Prüfhinweis erscheint korrekt, die Aussprache ist
  trotzdem falsch, weil `看` hier determiniert `kàn` ist.

**Die größte Fehlerklasse liegt weiterhin nicht beim Sandhi, sondern in der
Grundauflösung:** 34 von 60 gewöhnlichen Alltagssätzen enthalten mindestens
ein Wort ohne eindeutige Lexikonlesung. Alltagszeichen wie `好`, `个`, `大`,
`行`, `长`, `为`, `号`, `少`, `教`, `重`, `还`, `都`, `得`, `觉`, `乐`, `差`
stehen alle in der Mehrdeutigkeitsliste.

### Akzeptanzkriterien
- [x] Lexikalische Lesung und Lernaussprache sind getrennte Werte; die
      kanonische Lesung bleibt aus dem Lexikon ablesbar.
- [x] Dritter Ton vor drittem Ton wird angewandt, aber nur innerhalb einer
      belegten lexikalischen Einheit und dort zyklisch je Konstituente.
      `你好`→`níhǎo`, `展览馆`→`zhánlánguǎn`, `小老鼠`→`xiǎoláoshǔ`.
- [x] Keine globale Zeichenpositions-Heuristik über einen ganzen String; die
      einzige positionsbasierte Entscheidung ist die Mittelteilung im
      unbelegten Fall, benannt in A28.
- [x] `一` vor viertem Ton `yí`, sonst `yì`, mit strukturell erkannten
      Ausnahmen: Ordnungszahl nach `第`, Ziffernnachbarschaft, Reduplikation,
      Eigennamen-Signal.
- [x] `不` vor viertem Ton `bú`, sonst `bù`; lexikalischer Neutralton hat
      Vorrang und wird von keiner Regel angefasst (`对不起`, `看不见`).
- [x] Neutralton wird nie geraten, sondern gelesen.
- [x] Polyphone bleiben eine getrennte Stufe; Sandhi entscheidet nie eine
      Lesung, und ein Rateergebnis wird von keiner Tonregel geheilt.
- [x] `needsReview` greift genau dort, wo die App keine sichere Antwort hat —
      0 Abweichungen über 372 Fälle, als harte Zusicherung im Test.
- [x] Golden Corpus vorhanden, Sollwerte nicht aus der Implementierung
      abgeleitet, Restfehler namentlich festgeschrieben.
- [x] Manuelle Korrektur, beide ↻ und die Editor-Warnung unverändert.
- [x] Kein Schemawechsel, keine Laufzeit-Dependency, kein Netzzugriff, kein
      Audio, kein Speech-Code.
- [x] Keine merkbare Verzögerung im Editor; Ladezeit gegen den Stand vor der
      Phase gemessen.
- [x] Gezielter Nachtest auf dem Gerät zu den Änderungen nach dem
      Hauptdurchlauf — bestanden, siehe Statuszeile.

### Der gezielte Nachtest und warum er nötig war
Nach dem Hauptdurchlauf kamen hinzu: eine neue gebündelte Ressource
(`cedict-base-tones.txt`, 7 KB, in `ChineseLexicon.prepare()` geladen), ein
`let`-Feld auf einem Werttyp und zwei Regel-Aufrufstellen. Nichts an UI,
Provenance-Logik oder Persistenz. Ein vollständiger Durchlauf war deshalb
nicht gerechtfertigt, zwei Dinge konnte der Simulator aber nicht beantworten,
und beide sind am Gerät bestätigt:

1. **Liegt die neue Datei im Gerätebundle?** Sie hängt am Mechanismus der
   synchronisierten Ordner, und der Ausfall wäre **stumm** gewesen:
   `loadBaseTones` liefert dann `[:]`, `一个` fällt lautlos auf `yīge` zurück,
   und es erscheint kein Hinweis. Am Gerät kommt `yí ge`, die Datei ist also
   wirksam.
2. **Stockt das Editor-Sheet beim ersten Öffnen?** Die Ladearbeit liegt im
   `.task` auf dem Main Actor, und die 314 ms, die die Vorberechnung
   begründen, sind gemessen und nicht geschätzt. Kein merkbares Stocken.

### Ausdrücklich nicht in dieser Phase
Audio, Spracherkennung, Aussprachebewertung. **Für Phase 9 wird festgehalten:**
Ein Treffer der Spracherkennung heißt „der erkannte Text stimmt wahrscheinlich
mit dem Zieltext überein" — nie „richtig ausgesprochen". Kein Score, keine
Prozentangabe, kein Ton-Feedback (harte Regel 7 in `CLAUDE.md`).

---

## Phase 7 — Sprachausgabe (Mandarin TTS)

**Status: abgeschlossen.** Der physische Gerätetest lief am **2026-09-09**
vollständig durch, auf einem iPhone 16 Pro unter iOS 26.6. Bestätigt am
Gerät: Wiedergabe im Lernmodus erst nach dem Aufdecken; fünf schnelle Taps
erzeugen **keine** Warteschlange; ein Kartenwechsel spricht den neuen Text;
nur der gerade sprechende Knopf zeigt den aktiven Zustand, und er bleibt
nicht hängen. In der Kartenliste öffnete der Lautsprecher-Tap den Editor
**nicht**, der Zeilen-Tap öffnete ihn — das A27-Risiko war für **diese**
Struktur am Gerät geprüft und trat nicht ein. **Nachtrag:** Die geprüfte
Struktur ist inzwischen ersetzt. Der Kartenlisten-Polish nach Phase 7 (A32)
hat den `NavigationLink` durch einen Zeilen-Button ersetzt und den Editor
hinter einen Stift gelegt; dieser Beleg trägt also nicht weiter und der
Lautsprecher-gegen-Zeile-Fall steht auf der Checkliste jenes Schritts erneut. Im Editor spricht der Knopf das **ungespeicherte**
Hanzi, und beide ↻, Kategorien, Tastatur, Cursor, Speichern und Abbrechen
verhalten sich unverändert. Audio: bei aktivem Lautlos-Schalter weiterhin
hörbar, über Lautsprecher und Kopfhörer, Lautstärketasten normal, im
**Flugmodus** funktionsfähig, kurzer und langer Satz vollständig ohne
vorzeitigen Abbruch. Lifecycle mit Tabwechsel und Hintergrundwechsel sowie
eine **echte Audio-Unterbrechung** hinterlassen keinen hängenden Zustand.

### Stimme und Parameter

| | |
| --- | --- |
| Regel | `.premium` > `.enhanced` > `.default`, innerhalb einer Klasse ein deterministischer Identifier-Tiebreak |
| Auf dem Testgerät gewählt | **Lili (Premium)**, `com.apple.voice.premium.zh-CN.Lili`, `zh-CN`, `.premium` |
| Getesteter Default-Fallback | **Tingting**, `com.apple.voice.super-compact.zh-CN.Tingting` |
| Sprechrate | **0.45**, gemessen gegen `0.40` und `0.50` |
| Audio-Session | `.playback` + `.voicePrompt`, bei Bedarf aktiviert, mit `notifyOthersOnDeactivation` freigegeben |
| Utterance-Text | immer **Hanzi**, nie Pinyin (A31) |
| Tests | **389 Testfunktionen / 447 Einzelausführungen**, 0 Fehlschläge, 0 Compilerwarnungen, Debug und Release von null |

Lili wurde erst während der Phase über die iOS-Einstellungen nachgeladen.
Gewählt wird sie vom **unveränderten** Qualitätsselektor, ohne Sonderfall auf
Namen oder Identifier — der Tiebreak wird nicht einmal befragt, weil die
Qualitätsklasse vorher entscheidet. Die Vorzugsliste auf Tingting bleibt der
Weg für Geräte ohne Premium- oder Enhanced-Stimme; sie stammt aus einem
physischen Hörvergleich und nicht aus einer technischen Kennzeichnung, denn
im ersten Gerätebestand meldeten alle neun `zh-CN`-Stimmen dieselbe Klasse.
Details beider Messrunden in [apple-frameworks.md](apple-frameworks.md), Q5.

### Bekannte Grenzen

- **Die erreichbare Qualität hängt am Gerätebestand.** Ohne nachgeladene
  Premium- oder Enhanced-Stimme spricht die App mit einer `.default`-Stimme
  und klingt entsprechend synthetischer. Die App lädt keine Stimmen nach und
  bietet keine Stimmenauswahl an — das ist Sache der iOS-Einstellungen. Für
  andere Premium- oder Enhanced-Stimmen als Lili verlässt sich die App auf
  Apples Klassifikation, ohne sie gehört zu haben.
- **Der Fall „keine Mandarin-Stimme" ist auf diesem Gerät nicht erzeugbar**,
  weil die neun `zh-CN`-Stimmen Systemkomponenten sind. Die *Regel* ist über
  eine Datennaht (`installedVoices`) vollständig getestet, die *Anzeige* des
  Hinweises hat weder Test- noch Gerätebeleg. Bewusst so akzeptiert, statt
  Stimmen zu löschen.
- **Kein Interruption-Observer.** `stop()` hängt an `onDisappear` der
  Lernsession und des Editors; die Kartenliste ist ein Tab-Root und
  verschwindet nie. Der Gerätetest zeigt nach Hintergrundwechsel und echter
  Unterbrechung keinen hängenden Zustand, deshalb bleibt ein
  `AVAudioSession`-Beobachter ungebaut — er käme erst bei einem belegten
  Finding, nicht auf Verdacht.
- **Ersetzung statt Warteschlange ist gerätegedeckt, nicht testgedeckt.** Das
  bedingungslose `stopSpeaking(at: .immediate)` vor jedem `speak` lässt sich
  an dieser Naht nicht seriös automatisieren, weil das Timing von
  `synthesizer.isSpeaking` nicht dokumentiert ist. Belegt durch „fünf
  schnelle Taps" am Gerät.

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
- [x] Ein Wort wird in verständlichem Mandarin mit korrekten Tönen ausgegeben.
- [x] Ein Satz ebenso.
- [x] Die Wiedergabe bricht nicht vorzeitig ab (Retain-Problem ausgeschlossen).
- [x] Wiedergabe funktioniert über Lautsprecher und Kopfhörer.
- [x] Ohne passende Stimme erscheint ein verständlicher Hinweis statt eines
      toten Buttons.
- [x] Funktioniert im Flugmodus.

### Abhängigkeiten
Phase 6.

### Ausdrücklich nicht in dieser Phase
Automatisches Abspielen ohne Nutzeraktion, Aufnahme, Spracherkennung,
Modus B, Stimmenauswahl in den Einstellungen.

---

## Phase 8 — Lernmodus B: Chinesisches Audio → Deutsch

**Status: abgeschlossen.** Der physische Gerätetest lief am **2026-09-10**
vollständig durch, auf einem iPhone 16 Pro unter iOS 26.6. Bestätigt am
Gerät: Modus B ist im Setup wählbar und startet; vor dem Aufdecken ist weder
Hanzi noch Pinyin noch die Bedeutung sichtbar; nichts spielt von selbst; das
Audio ist beliebig oft wiederholbar und erzeugt keine Warteschlange;
„Hanzi anzeigen" zeigt **nur** das Hanzi; „Antwort zeigen" deckt Hanzi,
Pinyin und Bedeutung auf und erst dann erscheint die Bewertungsleiste; die
Bewertung führt zur nächsten, wieder vollständig verdeckten Karte; Wörter
und Sätze bleiben getrennt und die Kategorienauswahl wird respektiert;
Modus A verhält sich unverändert. Ebenfalls am Gerät bestätigt: **laufendes
Audio stoppt beim Kartenwechsel**, und die nachgereichte UI-Angleichung
(Modus A zeigt nach dem Aufdecken großer Lautsprecher → Hanzi → Pinyin →
Deutsch, Modus B unverändert).

### Umgesetzte Struktur

| | |
| --- | --- |
| Richtung | `SessionDirection` in `SessionConfiguration`, Standard `.germanToChinese` |
| Wirkung der Richtung | **reine Präsentation** — nichts unter `Learning/` liest die Konfiguration |
| Wahl | Segment-Picker im Setup zwischen Wörter/Sätze und Kategorien, nicht persistiert |
| Stufen Modus B | nur Audio → Hanzi allein → volle Antwort, in `PromptStage` |
| Sichtbarkeit und Tore | `AudioPrompt`, plus ein erschöpfender `switch` über die Stufe |
| Geteilter Endzustand | `LearnRevealedAnswerView` für **beide** Richtungen (A34) |
| Audio | unverändert `SpeechSynthesisService`, `SpeakButton`, Rate 0.45, Hanzi als Text |
| Pool | unverändert `LearnSessionModel.poolCards`, keine richtungsspezifische Filterung |
| Tests | **451 Testfunktionen / 509 Einzelausführungen**, 0 Fehlschläge, 0 Compilerwarnungen, Debug und Release von null |

Festgehalten, weil es die Grenzen der Phase sind: Deutsch → Chinesisch bleibt
Modus A, Audio → Deutsch ist Modus B, es gibt **keine gemischten Sessions**
über beide Richtungen, **kein Autoplay**, **keine Spracherkennung** und
**keine Aussprachebewertung**. Audio → Hanzi als dritter Modus ist nicht
gebaut.

### Bekannte Grenze der Absicherung

Dass der Zwischenschritt die Bedeutung nicht verrät, ist **strukturell**
gesichert — die verdeckte Anordnung enthält weder Deutsch noch Pinyin — und
durch den Gerätetest belegt, aber **nicht durch einen Test**. Gemessen:
Verschiebt man `.hanziShown` in den aufgedeckten Zweig, bleibt die gesamte
Suite grün. Kein Test in diesem Projekt erreicht ein SwiftUI-`body`, und eine
Snapshot-Infrastruktur wurde bewusst nicht eingeführt. Umgekehrt ist belegt:
Eine später hinzugefügte Stufe kompiliert nicht, bis der `switch` sie
einordnet. Die Regeln, die einen Aufrufer haben — `showsHanzi`,
`offersHanziStep`, `allowsAssessment` — sind vollständig falsifizierbar; drei
weitere verloren durch die geteilte Endansicht ihren Aufrufer und wurden
entfernt, statt als Spiegel stehenzubleiben (A34).

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
- [x] Modus B lässt sich im Setup wählen und startet korrekt.
- [x] Vor dem Aufdecken sind Hanzi und Pinyin nicht sichtbar.
- [x] Das Audio lässt sich mehrfach abspielen.
- [x] „Hanzi anzeigen“ deckt die deutsche Bedeutung nicht mit auf.
- [x] Die Lernstatuslogik verhält sich identisch zu Modus A.
- [x] An der Learning Engine wurde für diese Phase nichts geändert.

### Abhängigkeiten
Phase 7.

### Ausdrücklich nicht in dieser Phase
Spracherkennung, Hanzi-Schreibübungen, Audio → Hanzi als eigener Modus,
gemischte Sessions über beide Richtungen.

---

## Phase 9 — Spracherkennung (Mandarin)

**Status: abgeschlossen.** Die physischen Gerätetests liefen am **2026-09-11**
und **2026-09-12** auf einem iPhone 16 Pro unter iOS 26.6. Bestätigt am Gerät:
Erkennung startet, nimmt auf, finalisiert und liefert einen finalen
Mandarin-Text; ein Exact-Match zeigt **„Erkannt wie erwartet"**, eine
Abweichung zeigt Erkannt und Erwartet neutral nebeneinander; nirgends
erscheint ein Score, ein Prozentwert oder ein Ausspracheurteil; die
Selbsteinschätzung bleibt die einzige Bewertung. Ebenfalls bestätigt:
Erkennung im **Flugmodus**, verweigerte und danach erneut erteilte
Mikrofonberechtigung, der AudioSession-Handoff zwischen Erkennung und
Sprachausgabe in beide Richtungen, Hintergrund und Rückkehr, der
Zustands-Reset zwischen Karten und „Nichts erkannt" samt erneutem Versuch.

### Was diese Phase gebaut hat

| | |
| --- | --- |
| Erkennung | `SpeechAnalyzer` + `SpeechTranscriber`, kein `DictationTranscriber`, kein zweiter Pfad |
| Locale | über `supportedLocale(equivalentTo:)`, danach **validiert** auf `zh`/`Hans`/`CN` |
| Assets | Bereitschaft über `AssetInventory.status(forModules:)` für genau die benutzte Konfiguration, nie über `installedLocales`, nie gecacht |
| Audio | `AVAudioEngine` mit Tap, eigener `AVAudioConverter` auf `bestAvailableAudioFormat`, Format zur Laufzeit gelesen |
| Vergleich | ausschließlich `AnswerNormalization` — kein Fuzzy, keine Ähnlichkeit, keine Script-Konvertierung |
| Berechtigung | nur `NSMicrophoneUsageDescription`, angefragt beim ersten Mikrofontipp |
| Engine | `CApp/Learning/` **vollständig unverändert** |
| Tests | **470 Testfunktionen / 528 Einzelausführungen**, 0 Fehlschläge, 0 Compilerwarnungen, Debug und Release von null |

### Bekannte Grenzen

- **Die Erkennungsgenauigkeit ist eine gemessene Produktgrenze, kein
  Qualitätsversprechen.** Der Benchmark unten wurde nach dem ersten
  Positivdurchgang abgebrochen; 8 von 16 normal gesprochenen Zielantworten
  wurden als anderer Text erkannt. Ein Exact-Match taugt deshalb **nicht** als
  Correctness-Rückmeldung, und der Produkttext sagt das auch nicht mehr.
- **Task 9.9 ist nicht umgesetzt** und nach Phase 10 verschoben — Begründung
  beim Task.
- **Der Service ist nicht unit-getestet.** Mikrofon, Audiokonvertierung und
  Analyzer brauchen Hardware; ein Protokoll drumherum ergäbe nur ein Mock,
  das sich selbst recht gibt. Was ohne Gerät prüfbar ist — Locale-Regel,
  Vergleich, Kartenzuordnung, Wortlaut, Zustandstabelle des Knopfes — ist
  falsifizierbar abgedeckt und durch Mutationen gegengeprobt. Der Rest steht
  im Gerätetestprotokoll.

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
- **9.2** `NSMicrophoneUsageDescription` setzen und die tatsächlich
  angezeigten Dialoge protokollieren. *(Korrigiert am 2026-09-12: Ursprünglich
  verlangte dieser Task **beide** Schlüssel „vorsorglich, siehe Q4". Q4 ist
  inzwischen aus Apples Primärquelle geklärt — `NSSpeechRecognitionUsageDescription`
  ist an den Serverpfad gebunden, den `SpeechAnalyzer` nach Apples eigener
  Aussage nicht benutzt. Der Schlüssel wird deshalb **nicht** gesetzt, und
  `SFSpeechRecognizer.requestAuthorization` wird nicht aufgerufen. Die
  vorsorgliche Planung ist damit überholt, nicht stillschweigend übergangen;
  Belege in `apple-frameworks.md` §7.)*
- **9.3** Locale über `AssetInventory` reservieren und die Modelle
  herunterladen; Fortschritt und Fehler in der UI sichtbar machen.
- **9.4** `SpeechRecognitionService` mit `SpeechAnalyzer` und
  `SpeechTranscriber`: Start, Stop, Ergebnis als erkannter Text.
- **9.5** Aufnahme-Button in Modus A; Aufnahme ist immer optional — die
  Selbsteinschätzung funktioniert auch ohne Mikrofon vollständig.
- **9.6** Vergleich mit der in Phase 5 gebauten Normalisierungsfunktion:
  bei Gleichheit **„Erkannt wie erwartet"**, sonst beide Varianten
  nebeneinander anzeigen. *(Wortlaut korrigiert am 2026-09-12: Ursprünglich
  stand hier „Antwort wahrscheinlich korrekt" — eine Aussage über die
  **Antwort**, die der Benchmark nicht trägt. Der neue Wortlaut sagt, was
  tatsächlich geprüft wurde: zwei Texte stimmen überein.)*
- **9.7** **Keine** Score-Anzeige, **keine** Prozentangabe, **keine**
  Ton-Bewertung. Die Selbsteinschätzung bleibt die maßgebliche Bewertung.
- **9.8** Verweigerte Berechtigung sauber behandeln: Mikrofonteil entfällt,
  der Rest der App bleibt uneingeschränkt nutzbar.
- **9.9** ~~Nicht mehr benötigte Locale-Reservierungen wieder freigeben.~~
  **In Phase 9 bewusst nicht umgesetzt, verschoben nach Phase 10.** Apple
  dokumentiert, dass das System die Assets nach einem
  `release(reservedLocale:)` später entfernt — ein routinemäßiger Aufruf beim
  App- oder Sessionende erzwänge also einen erneuten Download und widerspräche
  der Offline-Nutzung, die diese Phase gerade erreicht hat. Die Freigabe
  gehört an eine ausdrückliche Nutzeraktion und damit in die Verwaltung der
  Sprachmodelle in Phase 10, wo sie vorgemerkt ist.

### Qualitätsanforderung, festgelegt in Phase 6.5

**Spracherkennung und Aussprachebewertung sind zwei verschiedene Dinge.** Diese
Phase misst ausschließlich das Erste. Die Kette ist:

```text
gesprochenes Mandarin
→ Apples Spracherkennung
→ erkanntes Hanzi
→ Normalisierung
→ Vergleich mit dem Ziel-Hanzi
```

Daraus darf **genau** eine von zwei Aussagen entstehen:

- „wahrscheinlich erkannt"
- „abweichend erkannt"

Nicht daraus entstehen darf: „richtig ausgesprochen", „Ton korrekt", ein
Prozentwert, ein Score, eine Sternebewertung. Ein Treffer der
Spracherkennung heißt, dass der erkannte **Text** wahrscheinlich zum Zieltext
passt — nichts über die Aussprache. Das ist harte Regel 7 in `CLAUDE.md`, und
es gilt auch dann, wenn die Erkennung sehr zuverlässig arbeitet: Ein Erkenner
mit gutem Sprachmodell errät den richtigen Satz auch aus schlechter
Aussprache.

**Kein automatisches Heraufsetzen des Lernstatus** allein aufgrund eines
einzelnen ASR-Treffers. Die Selbsteinschätzung bleibt die Quelle des
Lernstands (§6.1 in [learning-engine.md](learning-engine.md)).

### Gerätebenchmark — ehemalige Voraussetzung für READY, überholt am 2026-09-12

> **Diese Spezifikation wird nicht umgeschrieben.** Sie stand vor der
> Messung fest und bleibt im Wortlaut erhalten, samt Schwellen, die nicht
> erreicht wurden. Was sich geändert hat, ist nicht das Kriterium, sondern
> die Produktannahme dahinter — die Begründung steht unter „Warum die
> Schwelle nicht gelockert wird". Das neue READY-Gate steht bei den
> Akzeptanzkriterien.

Vor dem Phasenabschluss ein eigener Benchmark auf echter Hardware, mindestens:

| Dimension | Fälle |
| --- | --- |
| Länge | einsilbige Wörter, mehrsilbige Wörter, kurze Sätze, lange Sätze |
| Wiederholung | dieselbe Äußerung mehrfach |
| Umgebung | normale Zimmergeräusche, leise Stimme, laute Stimme |
| Netz | Flugmodus |
| Gegenproben | bewusst falsche Wörter, ähnlich klingende Wörter |

Metriken mindestens: exakte Übereinstimmung des normalisierten Hanzi,
Character Error Rate, False Accepts, False Rejects. Die letzten zwei sind die
wichtigen — sie sagen, wie oft die App eine falsche Äußerung durchwinkt und
wie oft sie eine richtige ablehnt.

#### Messsatz und Schwellen — festgelegt am 2026-09-11, **vor** jeder Messung

Der obige Abschnitt nennt Dimensionen und Metriken, aber weder einen
konkreten Messsatz noch eine Schwelle. Damit wäre „Voraussetzung für READY"
nicht erfüllbar gewesen: Zahlen ließen sich erheben, aber jedes Urteil
„bestanden" wäre ein Kriterium, das hinterher entsteht — in Kenntnis des
Ergebnisses, also zum denkbar schlechtesten Zeitpunkt. Das Folgende ist
deshalb **vor** dem ersten Versuch fixiert worden.

##### Fester Messsatz

Aus dem realen Kartenbestand werden vor Beginn genau **16 Karten** ausgewählt
und **namentlich protokolliert**:

| Gruppe | Anzahl |
| --- | --- |
| einsilbige Wörter | 4 |
| mehrsilbige Wörter | 4 |
| kurze Sätze | 4 |
| längere Sätze | 4 |

**Während des Benchmarks wird keine Karte ausgetauscht**, insbesondere nicht,
weil sie schlecht erkannt wird. Ein Messsatz, der sich dem Ergebnis anpasst,
misst nichts.

Jede der 16 Zielkarten wird **dreimal normal gesprochen** — 16 × 3 = **48
positive Versuche**.

Dazu **12 negative Gegenproben**:

- 6 klar falsche Wörter oder Antworten
- 6 ähnlich klingende, aber tatsächlich anders ausgesprochene Wörter

**Keine echten Homophone** als Negativprobe. Bei identischem akustischem
Signal kann ein Erkenner nicht sinnvoll zwischen zwei geschriebenen
Bedeutungen unterscheiden; ein solcher „Fehler" wäre keiner der App,
sondern eine Eigenschaft der Sprache.

**Keine absichtlich falschen Töne** als eigene Gegenprobe. Phase 9 bewertet
weder Aussprache noch Töne (harte Regel 7) — eine Tonprobe würde eine Frage
stellen, die dieser Phase nicht zusteht.

Gesamt: **60 Erkennungsversuche.**

Sobald das Mandarin-Asset für die verwendete Modulkonfiguration bereit ist,
wird der Benchmark **vollständig im Flugmodus** durchgeführt.

##### Metriken

Für die **48 positiven** Versuche:

- exakte Übereinstimmung nach `AnswerNormalization`
- Character Error Rate
- False Rejects
- alle drei zusätzlich **getrennt** nach einsilbigen Wörtern, mehrsilbigen
  Wörtern, kurzen Sätzen und langen Sätzen

Für die **12 negativen** Versuche:

- False Accepts
- der tatsächlich erkannte Text
- das erwartete Ziel

**Definitionen:**

> **False Reject** — eine normal und als korrekt beabsichtigt gesprochene
> Zielantwort, deren normalisiertes Erkennungsergebnis **nicht** dem
> Ziel-Hanzi entspricht.
>
> **False Accept** — eine bewusst andere Äußerung, deren normalisiertes
> Erkennungsergebnis **trotzdem** dem Ziel-Hanzi entspricht und deshalb den
> Zustand „Antwort wahrscheinlich korrekt" auslösen würde.

Klassifiziert wird **nach dem vorher festgelegten Testtyp**, nicht nach der
subjektiven Aussprachequalität des Sprechenden. Letztere zu beurteilen ist
genau das, was diese Phase nicht tut.

##### READY-Schwellen

Der Benchmark ist bestanden, wenn **alle vier gleichzeitig** zutreffen:

| Metrik | Schwelle |
| --- | --- |
| False Accepts | **0 von 12** |
| False Reject Rate | **≤ 20 %** der 48 positiven Versuche |
| Gesamt-CER | **≤ 15 %** |
| exakte normalisierte Treffer **je Längengruppe** | **≥ 60 %** |

Die Null bei den False Accepts ist die strengste Zahl und die wichtigste: Ein
durchgewunkener Fehler bestätigt dem Lernenden ausgerechnet das, was er
falsch gemacht hat. Ein False Reject ist ärgerlich, aber die
Selbsteinschätzung fängt ihn auf.

**Geltungsbereich.** Die Schwellen sind ein Engineering- und Produkt-Gate für
**diese** private App, auf **dem getesteten Gerät**, mit **diesem festen
Corpus**. Daraus folgt keine Aussage über Mandarin-Spracherkennung im
Allgemeinen und erst recht keine über Aussprachequalität.

##### Wenn das Gate nicht besteht

- Messwerte werden **nicht** verändert.
- Testkarten werden **nicht** nachträglich ausgetauscht.
- Schwellen werden **nicht** nachträglich verschoben.
- Zuerst wird das **Fehlerbild** analysiert, nicht die Produktlogik geändert.

Bei einem False Accept wird **zuerst der konkrete Fall angesehen**. Konnte
Apples Transkription zwischen Ziel und Gegenprobe objektiv nicht
unterscheiden — akustisch oder semantisch —, ist das ein **Designproblem des
Messsatzes** und wird als solches gemeldet und gemeinsam entschieden. Der
Messsatz wird in diesem Fall nicht still geändert.

#### Durchführung — Stand 2026-09-12

**Funktionaler Retest: bestanden.** Der korrigierte Build wurde auf dem
iPhone 16 Pro unter iOS 26.6 vollständig nachgetestet. Bestätigt: Erkennung
funktioniert; Match-Reveal und die Mismatch-Darstellung Erkannt/Erwartet
funktionieren; „Nichts erkannt" samt zweitem Versuch funktioniert; der
irreführende Downloadtext ist weg; das Mismatch-Layout stimmt; **der erste
Lautsprecher-Tap nach einer Erkennung ist hörbar** (der behobene
Session-Handoff); wiederholtes Wechseln zwischen Erkennung und Sprachausgabe
funktioniert in beide Richtungen; Hintergrund und Rückkehr funktionieren;
**Erkennung im Flugmodus funktioniert**; eine verweigerte Mikrofonberechtigung
blockiert den Lernmodus nicht, und nach erneuter Freigabe funktioniert die
Aufnahme wieder.

**Benchmark: begonnen und bewusst abgebrochen.** Der erste von drei geplanten
Positivdurchgängen über die 16 vorher festgelegten Karten wurde durchgeführt:

| Gruppe | exakte Treffer |
| --- | --- |
| einsilbige Wörter | 2 / 4 = 50 % |
| mehrsilbige Wörter | 3 / 4 = 75 % |
| kurze Sätze | 2 / 4 = 50 % |
| lange Sätze | 1 / 4 = 25 % |
| **gesamt** | **8 / 16 = 50 %** |

Damit standen nach dem ersten Drittel bereits **8 False Rejects**. Das
vorab festgelegte Gate erlaubt bei 48 positiven Versuchen höchstens 20 %,
also **maximal 9** — von den verbleibenden 32 Versuchen hätte höchstens ein
einziger weiterer scheitern dürfen. Angesichts dieses eindeutigen Signals
wurde die Erhebung aus Effizienzgründen gestoppt.

**Was damit ausdrücklich nicht vorliegt:** Die 12 Negativversuche wurden
**nicht** durchgeführt, es gibt also **keine gemessenen False Accepts**. Die
Gesamt-CER wurde **nicht** vollständig erhoben. **Der Benchmark ist nicht
vollständig durchgeführt, und das Gate ist nicht bestanden.**

#### Was das Ergebnis zeigt — und was nicht

Nicht gemessen wurden: Tonqualität, Aussprache, sprachliche Richtigkeit. Über
keines davon sagt dieser Durchgang etwas.

Die belastbare Aussage lautet:

> Auf diesem Gerät und mit diesem Anfänger-Sprecher produziert der
> `SpeechTranscriber` bei normal gemeinten Zielantworten häufig einen **anderen
> chinesischen Text**. Ein Exact-Match gegen das Karten-Hanzi erzeugt deshalb
> zu viele False Rejects, um als robuste **Correctness-Bewertung** der
> gesprochenen Antwort zu dienen.

#### Warum die Schwelle nicht gelockert wird

Das vorab festgelegte Gate gehörte zu einer **stärkeren Produktannahme**:
dass ein ASR-Exact-Match als brauchbare Correctness-Rückmeldung dienen kann.
Diese Annahme hat der reale Test **nicht bestätigt**.

Die Konsequenz ist deshalb **nicht**, die Schwelle nachträglich zu senken —
das wäre genau das Verschieben eines vorab festgelegten Kriteriums, das die
Spezifikation oben ausschließt. Die Konsequenz ist, die **Produktbehauptung zu
reduzieren**: von einer Correctness-Rückmeldung auf eine neutrale
Transkriptionsübereinstimmung. Ein Gate, das zu einer aufgegebenen Annahme
gehört, wird nicht bestanden erklärt, sondern als überholt gekennzeichnet —
mitsamt dem Grund.

**Diese Messung bleibt als Evidenz erhalten und wird nicht gelöscht**, auch
wenn das Kriterium, gegen das sie gemessen wurde, nicht weitergilt. Sie ist
der Beleg dafür, warum die Produktsemantik enger wurde.

### Akzeptanzkriterien

**Neu gefasst am 2026-09-12.** Das ursprüngliche Kriterium „Nach Aussprache
von 苹果 erkennt die App 苹果 und meldet „wahrscheinlich korrekt"" hing von
zwei Dingen zugleich ab: von Apples Erkennungsleistung bei einem bestimmten
Sprecher **und** von einem Wortlaut. Das Erste ist keine Eigenschaft dieser
App, und der Benchmark hat gezeigt, dass es keine verlässliche ist. Die
Kriterien prüfen deshalb jetzt, was die App selbst leistet und behauptet.

- [x] `SpeechTranscriber` startet, nimmt auf, finalisiert und liefert auf dem
      physischen Zielgerät einen finalen Mandarin-Text.
- [x] Der von Apple gelieferte finale Text wird **als solcher** dargestellt —
      die App korrigiert, ersetzt, übersetzt und fuzzy-matcht ihn nicht.
- [x] Der Vergleich mit dem Karten-Hanzi läuft **ausschließlich** über die
      bestehende `AnswerNormalization`.
- [x] Liefert der Transcriber einen finalen Text, der nach
      `AnswerNormalization` dem erwarteten Hanzi entspricht, zeigt die App
      **„Erkannt wie erwartet"** — und nichts anderes. Das Kriterium ist damit
      deterministisch und hängt nicht davon ab, ob Apple einen bestimmten
      Sprecher bei einem bestimmten Versuch richtig transkribiert.
- [x] Bei Abweichung werden **Erkannt** und **Erwartet** neutral gezeigt, ohne
      Bewertung der Aussprache oder des Wissensstands.
- [x] Spracherkennung bleibt vollständig optional: verweigerte Berechtigung,
      fehlendes Erkennungsergebnis und Nichtbenutzung des Mikrofons blockieren
      den normalen Lernablauf nicht.
- [x] Es erscheint nirgends ein Score, ein Prozentwert, eine Konfidenz, eine
      Tonbewertung oder ein Ausspracheurteil.
- [x] Spracherkennung verändert **niemals** automatisch den `LearningStatus`;
      die Selbsteinschätzung bleibt in Phase 9 die einzige Bewertung des
      Versuchs.
- [x] Die Systempfade funktionieren auf dem Gerät: offline, verweigerte und
      danach erneut erteilte Berechtigung, der AudioSession-Handoff zwischen
      Erkennung und Sprachausgabe, Hintergrund und Rückkehr, Zustands-Reset
      zwischen Karten, „Nichts erkannt" samt erneutem Versuch.
- [x] **Dokumentations-Gate:** Der begonnene Accuracy-Benchmark bleibt
      vollständig und unverfälscht als gemessene Produktgrenze dokumentiert —
      einschließlich der nicht erreichten Schwellen und der Tatsache, dass er
      abgebrochen wurde.

### Abhängigkeiten
Phase 6 (Phase 7 empfohlen, damit Soll und Ist direkt hörbar vergleichbar sind).

### Ausdrücklich nicht in dieser Phase
Tonanalyse, Aussprachebewertung, phonetischer Ähnlichkeitsvergleich,
automatisches Setzen der Selbsteinschätzung aus dem Erkennungsergebnis,
kontinuierliche Erkennung ohne Knopfdruck.

---

## Phase 10 — Einstellungen, Fehlerbehandlung, Device-Test & Polish

### Vorgemerkt aus dem Phase-9-Gerätetest

- **`rectangle.stack.badge.questionmark` existiert nicht.** Die Konsole meldet
  „No symbol named 'rectangle.stack.badge.questionmark' found in system symbol
  set". Der Name steht seit Phase 6 im Leerzustand von `LearnSessionView` und
  hat mit Phase 9 nichts zu tun; er blockiert nichts und wurde deshalb dort
  nicht nebenbei geändert. Beim Durchgehen der Leerzustände mitkorrigieren.
- **Freigabe von Sprachmodellen (Task 9.9).** Phase 9 hat bewusst **kein**
  routinemäßiges `AssetInventory.release(reservedLocale:)` eingebaut: Apple
  entfernt die Assets danach, was einen erneuten Download erzwänge und der
  Offline-Anforderung widerspricht. Die Freigabe gehört an eine ausdrückliche
  Nutzeraktion — also in die Verwaltung der Sprachmodelle in dieser Phase.

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
- [x] Alle Einstellungen wirken sich sofort und dauerhaft aus. — Gerätetest
  2026-09-12, Schritte 3 bis 7.
- [x] Kein Fehlerfall führt zu einem Absturz oder einem stillen Verschlucken.
  — Gerätetest Schritt 11, dazu die vollständige Codelesung in
  [architecture.md §7](architecture.md#7-fehlerbehandlung). **Grenze, die
  dazugehört:** Die vier SwiftData-Schreibfehler (Zeilen 18–21 der Matrix)
  sind auch am Gerät nicht auslösbar — ein `save()`, das wirft, lässt sich
  nicht herbeiführen. Für sie gilt weiterhin Codelesung plus `rollback()`,
  nicht Messung.
- [x] Die App ist nach den Modell-Downloads vollständig offline nutzbar. —
  Gerätetest Schritt 12 im Flugmodus: Karte aus deutschem Text angelegt
  (Hanzi und Pinyin), gelernt, Aussprache gehört, Mikrofon benutzt.
- [x] Bedienbar mit vergrößerter Schrift. — Gerätetest Schritt 8, große und
  Accessibility-Textgröße, Lernkarte mit langem Satz.
- [x] Mehrere hundert Karten ohne spürbare Verzögerung. — Gerätetest
  Schritt 13, dazu `LargeCollectionTests` mit 500 Karten (gemessen 9,9 / 22,5
  / 6,4 ms). **Was das nicht sagt:** Der Bestand auf dem Testgerät ist
  kleiner als die 500 des Fixtures; die Aussage für wirklich mehrere hundert
  Karten stützt sich auf die Messung, nicht auf das Gefühl am Gerät.
- [x] **Präzisiert am 2026-09-12:** Q1–Q6 sind beantwortet; Q7 ist mit
  Begründung und konkretem Fälligkeitspunkt dokumentiert.
  *(Ursprünglicher Wortlaut: „Q1–Q7 sind beantwortet." Der war so nicht
  erfüllbar, und zwar nicht aus Nachlässigkeit: Q7 fragt, ob die automatische
  SwiftData-Migration über die Projektlaufzeit reicht. Bis heute hat es keine
  Schemaänderung gegeben — `CApp/Models/` ist seit dem Commit `2e9b627` aus
  Phase 1 unverändert —, also existiert **keine empirische Evidenz in beide
  Richtungen**. Einen Haken zu setzen hieße, eine Annahme als Messung
  auszugeben. Das Kriterium ist deshalb offen **präzisiert** statt still
  überschrieben; die Begründung und der Fälligkeitspunkt stehen in
  [apple-frameworks.md §10](apple-frameworks.md#10-offene-technische-fragen-zu-klären-vor-der-jeweiligen-phase).
  Fälligkeitspunkt: die **erste additive Schemaänderung**, voraussichtlich
  `ReviewLog` in Phase 11.)*
- [→] Die App läuft stabil über mehrere Tage täglicher Nutzung auf dem Gerät.
  **Am 2026-09-13 aus Phase 10 in das globale Release-Gate verschoben** — siehe
  [Finale Geräte- und Release-Abnahme](#finale-geräte--und-release-abnahme).
  Das Kriterium ist damit **nicht erledigt und nicht gestrichen**, sondern an
  einer anderen Stelle fällig. Es steht hier weiter, weil ein stillschweigend
  entferntes Akzeptanzkriterium später wie ein nie gestelltes aussieht.

### Einordnung der Geräteprüfung — Entscheidung vom 2026-09-13

**Ursprüngliche Planung:** Der mehrtägige Alltagstest war ein
Akzeptanzkriterium **dieser** Phase, und die Phase galt bis dahin als offen.

**Geändert am 2026-09-13, bewusst und mit diesem Grund:** Nach Phase 10 folgen
noch Phase 11 und Phase 12, und beide verändern das reale Produkt erneut —
Phase 11 bringt mit `ReviewLog` die erste Schemaänderung des Projekts, Phase 12
greift in den Audio- und Spracherkennungs-Lebenszyklus ein. Ein mehrtägiger
Stabilitätsbeleg für den Stand von Phase 10 wäre danach kein Beleg mehr für
das ausgelieferte Produkt, und die Dokumentation stünde auf dem denkbar
schlechtesten Satz: „Phase 12 implementiert, Phase-10-Gerätetest noch offen".

**Konsequenz:** Die vollständige Geräteprüfung und der Alltagstest sind ab
jetzt **ein gemeinsames Gate am Ende der Roadmap**, nicht pro Phase. Phase 10
gilt nach Tests, Builds, Reviews, Gegenmutationen und Implementierung als
**implementiert**. Einen offenen Punkt namens „Phase-10-Gerätetest" oder
„Phase-10-Soak-Test" gibt es nicht mehr.

**Was das nicht heißt:** Die Geräteprüfung entfällt nicht. Sie wird verschoben,
nicht erlassen — und sie wird am Ende **strenger**, weil sie dann das fertige
Produkt prüft statt eines Zwischenstands.

**Die Haken oben bleiben stehen und bedeuten weiterhin, was sie sagen** — sie
stützen sich auf die Entwicklungs-/Zwischentests vom 2026-09-12 und
2026-09-13, deren Messungen unverändert unten stehen. Was sie **nicht** sind:
die Abnahme des fertigen Produkts. Die steht am Ende der Roadmap.

### Stand am 2026-09-13

**Gebaut, im Simulator grün, auf dem Gerät geprüft — und trotzdem nicht
abgeschlossen.** 537 Testfunktionen / 595 Einzelausführungen, 0 Fehlschläge,
0 Compilerwarnungen auf einem Debug-Build von null, Release-Build von null
ebenso.

#### Physischer Gerätetest am 2026-09-12 — bestanden

**Einordnung seit dem 2026-09-13: Entwicklungs-/Zwischentest.** Er belegt die
unten namentlich genannten Pfade auf dem damaligen Stand — das bleibt gültig
und wird nicht umgedeutet. Er ist **nicht** die Abnahme des fertigen Produkts;
die steht im Abschnitt
[Finale Geräte- und Release-Abnahme](#finale-geräte--und-release-abnahme).

**Gerät:** iPhone 16 Pro (`iPhone17,1`), **iOS 26.6**, per Kabel, Debug-Build,
installiert über `devicectl` (`de.belaunsch.CApp`). Modell und Systemversion
sind am Gerät ausgelesen, nicht erinnert.

Geprüfte Pfade, in der Reihenfolge des Durchlaufs:

| # | Pfad | Was geprüft wurde |
| --- | --- | --- |
| 1 | Erster Start | App-Icon auf dem Homescreen, Start ohne Splash-Blitz, Kartenliste erscheint |
| 2 | Einstellungen | Zahnrad in *Karten*, alle Abschnitte vorhanden |
| 3 | Sprechtempo | Langsam / Normal / Schnell am selben Wort gehört; wirkt ab der nächsten Wiedergabe, ohne Neustart |
| 4 | Stimme | Automatisch ergibt Lili (Premium); manuelle Wahl spricht die gewählte Stimme; Auswahl überlebt den Neustart |
| 5 | Kartenzahl je Runde | 5 gezählt; Änderung mitten in der Runde lässt die laufende Runde bei 5 und wirkt ab der nächsten mit 10 |
| 6 | Kartenzahl je Lernstand | Zahlen gegen die Kartenliste geprüft, ändern sich nach einer Bewertung |
| 7 | Sprachmodell | Status gelesen, entfernt, wieder vorbereitet; danach Mikrofon erneut benutzt |
| 8 | Dynamic Type | Große und Accessibility-Textgröße, Lernkarte mit langem Satz |
| 9 | VoiceOver | Chinesisch wird mit chinesischer Stimme gelesen, Pinyin nicht buchstabiert; Zahnrad, Stift, Lautsprecher und Mikrofon sind benannt |
| 10 | Dark Mode | alle Bildschirme durchgegangen |
| 11 | Leer- und Fehlerzustände | Suche ohne Treffer, Kategorie ohne Karten im Lern-Setup, Karte ohne chinesischen Text |
| 12 | **Flugmodus** | Karte aus deutschem Text angelegt (Hanzi + Pinyin), gelernt, Aussprache gehört, Mikrofon benutzt |
| 13 | Bestand | Suche, Sortierwechsel, Session-Start ohne spürbare Verzögerung |
| 14 | Regression | beide Lernrichtungen, Karte bearbeiten, Kategorien anlegen und umbenennen |

**Was der Durchlauf nicht zeigt** — und was deshalb kein Kriterium abhakt: die
vier SwiftData-Schreibfehler (nicht auslösbar), die False-Accept-Eigenschaft
der Spracherkennung (in Phase 9 ausdrücklich ungemessen) und die Stabilität
über mehrere Tage. Genau Letzteres ist das offene Kriterium.

**Und er lag vor der Korrekturrunde.** Der Durchlauf vom 2026-09-12 fand auf
dem Build **vor** den Änderungen vom 2026-09-13 statt. Auf dem Gerät war das
Modell bereits installiert, der Weg „Entfernen → Vorbereiten" lief also ohne
echten Download — genau deshalb ist der Doppeldruck dort nie aufgefallen. Die
übrigen zwölf Schritte berührt die Korrektur nicht; für die geänderten Pfade
gab es deshalb den gezielten Nachtest unten.

#### Gezielter Nachtest der Korrekturrunde am 2026-09-13 — bestanden

**Einordnung: Entwicklungs-/Zwischentest**, wie der Durchlauf vom Vortag. Er
belegt die geänderten Pfade und ersetzt die finale Abnahme nicht.

**Gerät:** iPhone 16 Pro (`iPhone17,1`), **iOS 26.6**, Debug-Build. Geprüft
wurde ausschließlich, was die Korrekturrunde verändert hat; der Rest stand
bereits aus dem Durchlauf vom Vortag.

**Zum getesteten Build, so genau wie es belegbar ist:** Produktivcode und
Arbeitsbaum sind seit der Verifikation unverändert — 537 Testfunktionen / 595
Einzelausführungen grün, Debug-Build von null und Release-Build von null mit 0
Compilerdiagnosen. Der gezielte Gerätetest lief auf der auf dem iPhone
vorhandenen korrigierten Installation. **Deren Herkunft ist in der Sitzung,
die diese Zeilen geschrieben hat, nicht unabhängig verifiziert worden**: Der
Installationsversuch aus der Sitzung heraus scheiterte an einem gesperrten
Gerät, die tatsächlich getestete Installation ist also anderweitig entstanden.
Dass sie exakt dem verifizierten Arbeitsbaum entspricht, wird hier deshalb
nicht behauptet.

| # | Pfad | Was geprüft wurde |
| --- | --- | --- |
| 1 | Entfernen | Zeile wechselt auf „Wird entfernt …", danach „Freigegeben — das System löscht die Daten später"; Entfernen-Knopf verschwindet, Vorbereiten erscheint |
| 2 | kein zweites Entfernen | nach erfolgreicher Freigabe wird kein Entfernen mehr angeboten — die falsche Meldung „Es gab keine Reservierung zurückzugeben" ist damit unerreichbar |
| 3 | Vorbereiten starten | sofort „Wird vorbereitet …", dann „Wird geladen …" mit Fortschrittsbalken; der Vorbereiten-Knopf verschwindet dabei |
| 4 | während des Downloads mehrfach tippen | kein zweiter Download, der Balken springt nicht und verschwindet nicht |
| 5 | Download abschließen | „Bereit", Mikrofon im Lernen wieder benutzbar |
| 6 | Erkennungsfehler im Lernen | Meldung steht unter dem Mikrofonknopf und **nicht** unter „Sprachmodelle" |
| 7 | Fehler beim Vorbereiten aus den Einstellungen | Meldung steht dort, Zeile sagt „Nicht geladen", Knopf bleibt für einen erneuten Versuch; die Erklärung überlebt Schließen und Wiederöffnen und erscheint **nicht** unter dem Mikrofon |
| 8 | Sprechtempo | Änderung überlebt Beenden und Neustart |
| 9 | Batchgröße | Session mit 5 gestartet, mitten in der Runde auf 10 gestellt: laufende Runde bleibt 5, die nächste hat 10 |

Damit sind die vier Blocker aus der zweiten Prüfung und die vier Befunde der
Nachkontrolle **auch auf dem Gerät** bestätigt — nicht nur im Test.

Der mehrtägige Alltagstest beginnt mit diesem korrigierten Build **neu**.

Fertig: Einstellungen (Sprechtempo, Stimme, Kartenzahl je Runde, Verwaltung
des Erkennungsmodells, Kartenzahl je Lernstand), Fehler-Audit als Matrix in
[architecture.md §7](architecture.md#7-fehlerbehandlung), Leer- und
Ladezustände, Sprachauszeichnung für VoiceOver, Dynamic Type für die
chinesischen Texte, App-Icon, Q1–Q6, A6 neu bewertet, README.

**Zwei Messungen, die etwas widerlegt haben:**

- **Der Launch-Screen-Hintergrund lässt sich nicht über `INFOPLIST_KEY_*`
  setzen.** Weder `…_BackgroundColor` noch `…_UIColorName` erreichen die
  gebaute `Info.plist`; die Einstellung wird ohne Warnung verworfen. Gemessen
  am Release-Produkt, Belege in `apple-frameworks.md` §9. Die Startfläche
  bleibt deshalb die Systemhintergrundfarbe — was zugleich die bessere Wahl
  ist, weil der erste Bildschirm der App eine Liste auf Systemhintergrund ist
  und eine farbige Fläche davor ein Splash wäre.
- **Die Zeitmessung in `LargeCollectionTests` war blind.** Sie las
  `Duration.components.attoseconds`, also nur den Sekundenbruchteil: 1,4 s
  meldeten sich als 400 ms und bestanden die 500-ms-Schranke. Behoben, und
  die Schranken sitzen jetzt an gemessenen Werten (9,9 / 22,5 / 6,4 ms) statt
  an einer Zahl, die 20- bis 80-mal zu groß war.

**Aus der ersten Review-/Audit-Runde behoben:** „Locale nicht auflösbar" und
„noch nicht gefragt" waren derselbe Zustand und ergaben ein dauerhaftes „Wird
geprüft …" neben einem Knopf ohne Wirkung; `releaseModel()` hatte den
Aufnahme-Guard nicht und meldete nicht, wenn es nichts freizugeben gab; das
einzige stumme `try?` der App liegt jetzt in einem `do/catch` mit Log; die
Weitergabe der Batchgröße an die Recency-Schwelle ist mit einer Gegenmutation
abgesichert (vorher wäre ihr Wegfall unbemerkt geblieben); `LearnAnswer.spoken`
und `accessibilityLabel` waren toter Code.

**Was diese Runde noch nicht behoben hatte — und die zweite Prüfung gefunden
hat.** Die Korrektur an `modelStatus` schloss nur das **kurze** Fenster nach
dem Download: Der Zustand wurde vor dem `.downloading`-Frühausstieg gesetzt,
aber weiterhin erst *nach* `downloadAndInstall()`. Während des eigentlichen
Downloads — Minuten, nicht Millisekunden — galt also weiter Apples letzte
Antwort „Noch nicht geladen", `canPrepareModel` blieb `true`, der Knopf stand
neben dem eigenen Fortschrittsbalken, und ein zweiter Druck startete einen
zweiten `downloadAndInstall()` neben dem ersten; das zuerst fertige Task
räumte dann den Fortschritt des anderen ab. Die Formulierung, die hier zuvor
stand, las sich, als sei der Doppeldruck damit erledigt — das war sie nicht.

**In der Korrekturrunde am 2026-09-13 geschlossen:**

- `SpeechModelState` unterscheidet jetzt, was **diese App** tut, von dem, was
  Apple meldet: `.preparing`, `.downloading` und `.failed` neben `.assets(…)`.
  Der Downloadzustand wird **vor** dem `await` gesetzt, und zwar zusammen mit
  Fortschritt und Phase in einer einzigen Operation (`beginDownload`), damit
  die drei nicht wieder auseinanderlaufen.
- Ein zweiter Lauf wird an der Quelle abgewiesen: `beginModelWork()` gibt
  `nil` zurück, solange ein eigener Lauf in der Luft ist. Der verborgene Knopf
  ist die Höflichkeit, diese Regel ist die Absicherung.
- Modellläufe haben eine eigene Generation (`modelEpoch`) nach dem Muster des
  Aufnahmepfads. Ein überholter Lauf schreibt weder Zustand noch Fortschritt;
  `releaseModel()` prüft das jetzt auch **nach** seinem `await`.
- Fehler sind getrennt: `failure` gehört dem Aufnahmepfad, `modelFailure` der
  Modellverwaltung. Ein Erkennungsfehler aus dem Lernen erscheint nicht mehr
  unter „Sprachmodelle", und umgekehrt erklärt sich eine in den Einstellungen
  gestartete Vorbereitung nicht mehr unter dem Mikrofonknopf. Ein veralteter
  Modellfehler verschwindet beim erneuten Öffnen; die Erklärung eines gerade
  gescheiterten Versuchs (`.failed`) bleibt stehen.

**Zweite Korrekturrunde am selben Tag, aus Review und Audit der ersten.** Die
erste Runde hatte den Doppeldownload geschlossen und dabei eine gleichwertige
Fehlerklasse eingeführt:

- `takeOverModelWork()` erhöhte die Generation, ohne den Zustand zu
  beanspruchen. Der überholte Lauf durfte sein eigenes Ende nicht mehr
  schreiben, und `refreshModelStatus()` weigert sich absichtlich, einen
  laufenden Zustand zu korrigieren — der Einstellungsbildschirm wäre bis zum
  App-Neustart auf „Wird geladen …" eingefroren. Wer übernimmt, beansprucht
  jetzt den Zustand und erbt damit die Pflicht, ihn zu beenden; eine
  Gegenmutation sichert das ab.
- `refreshModelStatus()` löschte `modelFailure` bedingungslos und hätte damit
  genau die Erklärung gelöscht, wegen der man den Bildschirm öffnet.
- Ein erfolgreiches Entfernen blieb ohne Rückmeldung: Apple löscht die Assets
  später, der gemessene Status sagte weiter „Bereit", und ein zweiter Tipp
  meldete „Es gab keine Reservierung zurückzugeben" — nach einer Entfernung,
  die funktioniert hatte. Dafür gibt es jetzt `.released` mit eigenem Satz,
  und der Entfernen-Knopf ist danach weg.
- Übernahm das System einen Download selbst, blieb `phase` auf `.downloading`
  hängen: Die Einstellungen sagten irgendwann „Bereit", das Mikrofon blieb
  aber bis zum Neustart mit „Sprachmodell wird geladen …" gesperrt. Dieser
  Pfad ist **älter** als die Korrekturrunden; `refreshModelStatus()` ist die
  einzige Stelle, die beide Werte sieht, und zieht die Phase jetzt nach.
- `SpeechRate` schreibt seine Rohwerte aus, wie `CardSortOrder` es seit Phase 6
  vormacht, und `PreferencesTests.rawValuesArePinned` nagelt sie fest. Ohne das
  hätte ein Umbenennen des Swift-Falls jeder Installation still das Sprechtempo
  zurückgesetzt.

**Status: Implementierung abgeschlossen.** Sechs der sieben
Akzeptanzkriterien sind erfüllt und belegt; das siebte — Stabilität über
mehrere Tage — ist am 2026-09-13 in die
[finale Geräte- und Release-Abnahme](#finale-geräte--und-release-abnahme)
verschoben worden, zusammen mit der vollständigen Geräteprüfung. Belegt sind:
537 Testfunktionen / 595 Einzelausführungen grün, Debug-Build von null und
Release-Build von null mit 0 Compilerdiagnosen, zwei unabhängige Code Reviews
und zwei Testaudits mit abgearbeiteten Findings, zehn Gegenmutationen, dazu
die beiden Entwicklungs-Gerätetests oben.

**Der frühere Wortlaut hier lautete `NOT READY — mehrtägiger Soak-Test
ausstehend`** und war für die damalige Struktur richtig. Er ist nicht gelöscht,
sondern ersetzt, weil das Gate umgezogen ist — die Begründung steht oben unter
„Einordnung der Geräteprüfung".

### Abhängigkeiten
Phasen 0–9.

### Ausdrücklich nicht in dieser Phase
Alles aus dem Backlog. App Store, TestFlight, iCloud-Sync, iPad-Layout.

---

## Post-v1 / Weiterentwicklung

Zwei Produktphasen nach v1. **Noch nichts davon ist entschieden oder
implementiert.** Sie stehen hier, damit die Richtung festgehalten ist und
damit spätere Entscheidungen nicht rückwirkend so aussehen, als wären sie
immer geplant gewesen. Phase 9 und Phase 10 bleiben in ihrer Reihenfolge
unberührt.

### Randbedingung aus dem Phase-9-Gerätetest

Der erste Positivdurchgang des Phase-9-Benchmarks hat am **2026-09-12** auf
dem iPhone 16 Pro unter iOS 26.6 ergeben:

> Auf diesem Gerät und mit diesem Anfänger-Sprecher produziert der
> `SpeechTranscriber` bei normal gemeinten Zielantworten häufig einen
> **anderen chinesischen Text**. Ein Exact-Match gegen das Karten-Hanzi
> erzeugt deshalb zu viele False Rejects, um als robuste
> **Correctness-Bewertung** der gesprochenen Antwort zu dienen.

Gemessen: **8 von 16** exakten Treffern über die vier Längengruppen, also
**8 False Rejects** im ersten von drei geplanten Durchgängen. Die Erhebung
wurde danach abgebrochen; die Zahlen und ihre Grenzen stehen vollständig bei
Phase 9 unter „Durchführung".

**Was damit nicht gesagt ist:** nichts über Tonqualität, nichts über
Aussprache, nichts über sprachliche Richtigkeit. Das wurde nicht gemessen —
gemessen wurde die Übereinstimmung zweier Texte.

Das ist die **zentrale Randbedingung für Phase 11** und der Grund, warum ein
Speech-Mismatch dort ausdrücklich **keine** hinreichende negative Evidenz
ist. Ein Exact-Match bleibt umgekehrt brauchbare **positive** Evidenz: Dass
der Erkenner ausgerechnet den Zieltext produziert hat, passiert nicht
versehentlich.

---

## Phase 11 — Review History & Assisted Assessment

### Ziel

Die App soll nicht dauerhaft nach **jeder einzelnen Karte** eine manuelle
Selbsteinschätzung verlangen. Stattdessen sammelt sie über mehrere Reviews
Evidenz über den Kenntnisstand einer Karte und **schlägt** an geeigneten
Stellen einen neuen `LearningStatus` vor.

### Grundlage: der zurückgestellte ReviewLog

Seit Phase 1 ist festgehalten, dass es **keine** Antwort-Historie gibt und ein
`ReviewLog` additiv nachrüstbar wäre. Phase 11 ist der Punkt, an dem er
gebraucht wird: Ohne Historie gibt es keine Evidenz, und ohne Evidenz keinen
Vorschlag.

Pro Review sollen mindestens die für die Lernentscheidung relevanten Fakten
rekonstruierbar sein:

| Feld | Wofür |
| --- | --- |
| Karte | worauf sich der Eintrag bezieht |
| Zeitpunkt | zeitliche Alterung der Evidenz |
| Lernrichtung | Modus A und Modus B stellen verschiedene Fragen |
| vorheriger Status | Ausgangslage der Bewertung |
| Speech verwendet | ob überhaupt eine automatische Evidenz vorlag |
| ASR Exact Match | die Evidenz selbst, soweit vorhanden |
| manueller Reveal | Aufdecken ohne Versuch ist kein Wissensbeleg |
| Retry | mehrfache Anläufe an derselben Karte |
| SelfAssessment | die tatsächliche Bewertung, **falls** eine abgegeben wurde |

Der genaue Zuschnitt des Modells wird zu Beginn von Phase 11 entschieden,
nicht hier. **Entschieden am 2026-09-13:** `ReviewLog` mit genau diesen neun
Feldern plus Beziehung zur Karte — die Felder stehen in
[architecture.md §3](architecture.md#3-datenmodell), die Begründung für jedes
Nicht-Feld daneben.

### Produktregeln

- **`LearningStatus` und Versuchsergebnis bleiben getrennte Konzepte.** Ein
  einzelner Versuch ist eine Beobachtung, der Status ist eine Bewertung.
- **Mehrere wiederholte exakte Speech-Matches können als *potenzielle*
  positive Evidenz** in die Statusschätzung eingehen — aber weiterhin nie als
  Aussprache- oder Tonbewertung (harte Regel 7 gilt unverändert).
  **[ENTSCHIEDEN am 2026-09-13]:** Sie genügt allein — aber erst
  **wiederholt** (zwei saubere Erstversuche in Folge), und nur dafür, die
  Frage zu **überspringen**, nicht dafür, den Status zu heben. Ein einzelner
  Treffer trägt nichts. Regel in [learning-engine.md §12](learning-engine.md);
  die Zahlen sind Produktentscheidungen, keine Messungen (§12.5). Zu kalibrieren an realer Review-Historie **und insbesondere an den
  noch unbekannten False-Accept-Eigenschaften**: Der Phase-9-Benchmark wurde
  nach dem ersten Positivdurchgang abgebrochen, die 12 Negativversuche wurden
  nicht durchgeführt. Wie oft der Transcriber eine *andere* Äußerung
  ausgerechnet als den Zieltext erkennt, ist damit **nicht gemessen** — und
  genau das entscheidet, wie viel ein Match wert ist.
- Ein **Speech-Mismatch ist keine hinreichende negative Evidenz.** Grund:
  die oben festgehaltene Empfindlichkeit des exakten Vergleichs.
- **Keine automatische Verschlechterung** einer Karte allein aufgrund von ASR.
- **Die manuelle Bewertung des Nutzers hat Vorrang** — immer.

### Die Inferenz

Über ein **rollendes Fenster** mehrerer verwertbarer Reviews berechnet eine
**reine, testbare** Funktion einen

```text
SuggestedLearningStatus
```

Ausgangsidee sind ungefähr die letzten zehn verwertbaren Versuche.

**[ENTSCHIEDEN am 2026-09-13, aber ausdrücklich nicht kalibriert]:**
Fenstergröße 10, Schwelle zwei saubere Versuche, Rekalibrierung nach drei
automatischen Reviews, **keine** zeitliche Alterung. Gewichte gibt es nicht —
die Regel zählt einen Lauf, sie verrechnet nichts.

Der ursprüngliche Text lautete: *„Diese Werte willkürlich vorwegzunehmen wäre
dasselbe Muster, das beim Phase-9-Benchmark vermieden wurde: ein Kriterium
erfinden, bevor Daten vorliegen. Konkretisiert wird die Formel zu Beginn von
Phase 11, nachdem reale Review-Historie existiert."*

**Die zweite Hälfte ließ sich nicht einlösen, und das steht hier statt in
einer Fußnote:** Reale Review-Historie gibt es nicht, weil diese Phase sie
erst anlegt. Die Werte sind deshalb **entschieden statt gemessen**, jeder
einzeln begründet und im Code als Produktentscheidung gekennzeichnet. Die
Kalibrierung bleibt offen und ist ohne Schemaänderung nachholbar, weil ab
jetzt aufgezeichnet wird. **Und eine Korrektur an der ersten Fassung:** Die
Aktualität entsteht nicht durch das Fenster, sondern dadurch, dass der Lauf am
ersten nicht sauberen Versuch abbricht — das Fenster begrenzt nur, wie viel
Historie gelesen wird (§12.5).

### UX-Ziel

Bei ausreichend sicherer Evidenz soll nach einem erfolgreichen Versuch **kein**
Nochmal / Schwer / Gut / Sicher mehr nötig sein:

```text
eindeutiger erfolgreicher Versuch
  → ReviewLog aktualisieren
  → keine Neubewertung nötig
  → automatisch nächste Karte
```

Ist eine Neubewertung fällig oder die Evidenz unsicher:

```text
Review abschließen
  → Nochmal / Schwer / Gut / Sicher anzeigen
  → vorgeschlagene Stufe visuell hervorheben
  → Nutzer bestätigt oder wählt eine andere
```

**Sofort manuell bewerten lassen**, wo keine belastbare automatische Evidenz
besteht — insbesondere bei Speech-Mismatch, manuellem Aufdecken und fehlender
Spracherkennung.

**Der Vorschlag darf den Status niemals stillschweigend gegen die Entscheidung
des Nutzers ändern.** Ein Vorschlag ist eine Hervorhebung, kein Ergebnis.

Kein Gamification-Score, keine Streaks, keine Prozent-Mastery-Anzeige (harte
Regel 6 gilt unverändert).

### Akzeptanzkriterien

**Konkretisiert am 2026-09-13, zu Beginn der Umsetzung.** Der ursprüngliche
Satz lautete: „Erst zu Beginn von Phase 11 zu konkretisieren — zusammen mit
der Inferenzformel und auf Basis realer Review-Historie."

Die zweite Hälfte dieses Satzes ließ sich **nicht** einlösen, und das gehört
hierher statt in eine Fußnote: Reale Review-Historie gibt es nicht, weil
diese Phase sie erst anlegt. Die Formel ist deshalb nicht kalibriert worden,
sondern **entschieden** — konservativ, erklärbar und mit jedem freien Wert
ausdrücklich als Produktentscheidung gekennzeichnet
([learning-engine.md §12.5](learning-engine.md)). Eine Kalibrierung an echten
Daten bleibt offen und ist ohne Schemaänderung nachholbar, weil die Historie
ab jetzt aufgezeichnet wird.

- [x] Pro abgeschlossenem Versuch entsteht **genau ein** `ReviewLog`-Eintrag
      mit den Feldern aus [learning-engine.md §12.1](learning-engine.md).
- [x] Die Schemaerweiterung ist additiv: Ein mit dem Phase-10-Schema
      geschriebener Store öffnet mit dem Phase-11-Schema **ohne Verlust** und
      ohne Migrationsplan (Q7).
- [x] Die Inferenz liegt in `Learning/`, ist rein, deterministisch,
      Foundation-only und kennt weder `Card` noch `ModelContext`.
- [x] **Ein Speech-Mismatch senkt niemals einen Status und schlägt niemals
      einen Downgrade vor.**
- [x] **Ein einzelner Exact-Match trägt keine Statusaussage.**
- [x] Die manuelle Bewertung hat Vorrang: Der Vorschlag ändert nichts ohne
      Tipp des Nutzers, und ein abweichender Tipp gewinnt vollständig.
- [x] Bei ausreichend wiederholter sauberer Evidenz entfällt die
      Vierfachauswahl; bei Unsicherheit, Mismatch, manuellem Aufdecken,
      fehlender Spracherkennung, Retry und bei fälliger Rekalibrierung
      erscheint sie weiterhin.
- [x] Automatisches Weitergehen verändert den Lernstand **nicht**.
- [x] Fenstergröße, Schwelle und Rekalibrierungsintervall sind im Code und in
      der Dokumentation als Produktentscheidung benannt, nicht als Messung.
- [x] Die Phase-5-Regeln gelten unverändert: Übergangsmatrix (§6) und
      „Statusänderung nur einmal pro Mini-Batch" (§6.1).
- [x] Kein Score, keine Prozent-Mastery, keine Streaks, keine Aussage über
      Aussprache oder Töne.

### Stand am 2026-09-13 — implementiert

**580 Testfunktionen / 641 Einzelausführungen grün, 0 übersprungen**, Debug-Build
von null und Release-Build von null mit 0 Compilerdiagnosen. Ein unabhängiges
Code Review und ein unabhängiges Testaudit sind abgearbeitet.

**Q7 ist damit zum ersten Mal wirklich beantwortet** — für additive Änderungen:
Ein mit dem nachgebauten Phase-10-Schema geschriebener Store öffnet mit dem
Phase-11-Schema ohne Verlust und ohne Migrationsplan. Einzelheiten und Grenzen
unter Q7 in [apple-frameworks.md](apple-frameworks.md).

**Was die beiden Prüfungen gefunden haben und was daraus wurde:**

- **Ein Blocker aus dem Testaudit:** Der Eintrag des automatischen Pfads war
  durch keinen Test abgesichert — der Test las `card.reviews.first` auf einer
  ungeordneten Beziehung, deren geseedeter Eintrag dieselben Werte trug. „Gar
  keinen Eintrag schreiben" blieb grün. Jetzt wird gezählt und der neue
  Eintrag über seinen Zeitstempel ausgewählt; die Gegenmutation ist rot.
- **Zwei Produktivbefunde aus dem Review:** Eine von Hand auf *Neu*
  zurückgesetzte Karte behält ihre Historie — die App hätte dort sofort eine
  Beförderung hervorgehoben, also genau auf der Karte, die der Nutzer eben als
  ungelernt erklärt hat. Und `correctCount` stieg beim automatischen Weitergehen,
  ohne dass jemand bewertet hatte; das ist jetzt unterlassen und in
  [learning-engine.md §7.1](learning-engine.md) begründet.
- **Eine falsche Aussage über die eigene Regel:** Code und §12.5 beschrieben das
  Fenster als Recency-Mechanismus. Das ist es nicht — die Aktualität entsteht
  dadurch, dass der Lauf am ersten nicht sauberen Versuch abbricht; das Fenster
  begrenzt nur, wie viel Historie gelesen wird. Der Text sagt das jetzt, und der
  Test, der das Fenster zu prüfen vorgab, prüft nun den Abbruch.
- **Fünf Tests bestanden aus dem falschen Grund** (die Rekalibrierung oder das
  obere Leiterende erzwangen das Ergebnis statt der geprüften Regel) und sind
  isoliert worden; fünf fehlende Integrationstests sind dazugekommen, darunter
  das Zurücksetzen des Versuchszustands zwischen zwei Karten und ein
  automatisches Weitergehen auf der **letzten** Karte eines Batches.
- **Eine tote Bedingung** in `suggestedStatus` wurde von einer Gegenmutation
  aufgedeckt und entfernt.

**Gegenmutationen: dreizehn ausgeführt, alle greifen** — Schwelle 2→1,
`new`-Guard, Vorschlag bei `new`, Sauberkeitsprüfung im Lauf, Rekalibrierung,
`wasManualReveal`, Auto-Advance hebt den Status, `.cascade`→`.nullify`,
Eintrag im automatischen Pfad, `revealedByHand`-Reset, `usedSpeech`-Reset,
Historie falsch herum gelesen, plus die eine, die die tote Bedingung fand.

**Offen und benannt:** Der automatische Pfad ist produktiv **nur** über echte
Spracherkennung erreichbar und im Simulator nicht auslösbar. Ein gezielter
Gerätetest als **Entwicklungsbeleg** ist deshalb sinnvoll — insbesondere die
Frage, ob der Kartenwechsel ohne Rückmeldung zu abrupt wirkt. Er ist kein Gate
dieser Phase; die vollständige Abnahme steht am Ende der Roadmap.

---

## Phase 12 — Session-Sprachmodus

### Umbenannt am 2026-09-14, und warum

Diese Phase hieß **„Hands-free Speech Sessions"**. Der Name ist für den
umgesetzten Umfang irreführend: Zum Beenden einer Antwort ist weiterhin ein
Tap nötig, und was einen Tap braucht, heißt nicht freihändig.

**Ursprünglich vorgesehen war automatisches Endpointing** — die App sollte
selbst erkennen, wann der Lernende aufgehört hat zu sprechen, und die Aufnahme
von sich aus abschließen. Genau dafür wurde vor dem Produktcode gemessen
(Q11 in [apple-frameworks.md](apple-frameworks.md), Gerätespike am
2026-09-14 auf dem iPhone 16 Pro, iOS 26.6):

- **`SpeechDetector`** existiert seit iOS 26.0 als öffentliche VAD-API, lieferte
  aber mit `reportResults: true` über 45 Sekunden mit vier echten Äußerungen
  **null Ergebnisse und keinen Fehler**.
- **`SpeechTranscriber.isFinal`** stellte seine Ergebnisse **3,9 bis 6,6
  Sekunden** nach dem Ende des abgedeckten Audios zu — als Endpoint unbrauchbar,
  und nicht knapp.
- **Eigene Audioenergie** trennt Sprachspitzen grundsätzlich vom Grundrauschen
  (Faktor 10 bis 30), aber nicht auf Einzelmesspunktbasis: Leise Stellen echter
  Äußerungen liegen auf Stilleniveau, und ein Störimpuls erreichte Sprachpegel.

**Produktentscheidung daraus:** Der Umfang für die private v1 wird auf
**Auto-Start plus manuelles Ende** reduziert. Eine belastbare eigene Regel
bräuchte mindestens Schwelle, Hysterese, Mindestsprechdauer und Stillezeit —
alles abgeleitet aus **einem** Durchlauf in **einem** ruhigen Raum. Ein falsches
Endpointing, das mitten im Wort abschneidet oder ewig wartet, schadet mehr als
ein zusätzlicher Tap.

**Das ist keine Aussage darüber, dass automatische VAD unmöglich wäre** —
sondern darüber, was auf dieser iOS-Version auf diesem Gerät gemessen wurde.
Echtes Endpointing steht im Backlog.

### Ziel

Spracherkennung soll während einer Lernsession nicht für **jede einzelne
Karte** erneut manuell gestartet werden müssen. Ein Tap auf „Antwort
sprechen" aktiviert einen **Session-Sprachmodus**:

```text
neue unrevealed Karte
  → Aufnahme startet automatisch
  → Nutzer spricht
  → Nutzer beendet die Aufnahme mit einem Tap
  → Erkennung, finaler Text
  → bestehender Phase-9-Vergleich
  → bestehender Phase-11-Bewertungspfad
  → nächste Karte
  → Aufnahme startet automatisch
```

**Der Modus entscheidet nicht, wann der Lernende fertig ist.** Es gibt kein
Silence-Endpointing und keinen Timeout als Ersatz dafür — gespart wird der
Tap zum *Starten*, nicht der zum Beenden.

### Was das ausdrücklich nicht ist

**Kein dauerhaftes, ununterbrochenes Recording.** Die App hält einen
*Sessionmodus* aktiv und startet die eigentliche Mikrofonaufnahme passend zum
Karten-Lebenszyklus; beendet wird sie vom Lernenden.

**Und ausdrücklich nicht freihändig.** Siehe die Umbenennung oben.

Die Aufnahme pausiert oder endet bei:

- Reveal und finaler Verarbeitung
- Sprachausgabe über den Lautsprecher
- Sessionende
- App im Hintergrund
- Audio-Unterbrechung
- technischem Fehler

### Produktentscheidung: TTS beendet den Sprachmodus

Benutzt der Nutzer bewusst den Lautsprecher, wird der automatische
Sprachmodus **deaktiviert**. Ihn wieder zu aktivieren erfordert erneut einen
Mikrofon-Tap.

Der Grund ist derselbe, aus dem Phase 9 vor jeder Aufnahme die Sprachausgabe
stoppt: **keine parallele Sprachausgabe und Mikrofonaufnahme.** Wer zuhört,
spricht gerade nicht — und ein Modus, der nach dem Anhören sofort wieder
mitschneidet, nähme die Entscheidung darüber weg.

Ebenfalls ausgeschlossen: **keine Aufnahme im Hintergrund**, **keine
Speicherung von Roh-Audio**.

### Geklärt am 2026-09-14, vor dem Produktcode

Die vier offenen Punkte dieser Phase lauteten:

- zuverlässige Erkennung des **Äußerungsendes** (Endpointing)
- ob `SpeechAnalyzer` dafür eine ausreichende Finalisierung liefert oder eine
  zusätzliche Silence-Regel nötig ist
- UX bei „Nichts erkannt"
- Retry-Verhalten

**Die ersten beiden sind gemessen und beantwortet** (Q11): kein verwertbares
Apple-Signal, und eine eigene Regel wäre unkalibriert. Daraus folgte der
reduzierte Scope oben — das Endpointing entfällt, also entfällt auch die
Frage nach der Silence-Regel.

**Die letzten beiden sind damit entschieden:**

- **„Nichts erkannt"** zeigt den bestehenden Zustand aus Phase 9. Auf
  derselben Karte startet **keine** neue Aufnahme von selbst — sonst entstünde
  genau die Schleife aus Aufnehmen, Nichts, Aufnehmen. Der Modus bleibt aktiv,
  ein erneuter Versuch auf derselben Karte braucht einen Mikrofon-Tap.
- **Retry** ist damit immer ausdrücklich. Nach einer Bewertung und dem
  Kartenwechsel startet die nächste Karte wieder von selbst.

Wie in Phase 9 gilt: erst Spike und Dokumentation, dann Produktcode — und
diesmal hat der Spike den Umfang verändert.

### Akzeptanzkriterien

Formuliert am 2026-09-14 zu Beginn der Umsetzung — die Phase hatte bis dahin
keine, weil sie als Skizze geschrieben war.

- [x] Ein Mikrofon-Tap in Modus A armiert den Sprachmodus **und** startet die
      Aufnahme der aktuellen Karte.
- [x] Eine laufende Aufnahme wird vom Lernenden beendet; das Bedienelement
      sagt das („Aufnahme beenden").
- [x] Auf einer neuen unaufgedeckten Karte startet die Aufnahme von selbst,
      solange der Modus aktiv ist — **genau einmal** pro Karte.
- [x] Nach „Nichts erkannt" startet auf derselben Karte **keine** weitere
      Aufnahme von selbst; ein erneuter Versuch braucht einen Tap.
- [x] Während die Selbsteinschätzung auf eine Entscheidung wartet, läuft keine
      Aufnahme.
- [x] Eine Karte, die nach „Nochmal" unmittelbar wiederkommt, bekommt wieder
      eine Aufnahme.
- [x] Sprachausgabe, Hintergrund, Audio-Unterbrechung, technischer Fehler,
      dauerhaft nicht verfügbare Erkennung und Sessionende **deaktivieren** den
      Modus; danach gibt es keinen automatischen Neustart.
- [x] Manuelles Aufdecken bricht eine laufende Aufnahme ab, der Modus bleibt
      aktiv, und `wasManualReveal` erreicht den Phase-11-Pfad korrekt.
- [x] Es entsteht **kein** eigenes Endpointing: kein RMS, keine
      Noise-Floor-Kalibrierung, kein Silence-Timer, kein Timeout als Ersatz,
      kein `SpeechDetector`-Polling.
- [x] Keine neue Speech- oder Lernsemantik: kein Fuzzy Matching, keine
      Konfidenz, kein Score, `CApp/Learning/` und `ReviewLog` unverändert.
- [x] Modus B ist unverändert; Modus A bei ausgeschaltetem Sprachmodus
      verhält sich wie in Phase 11.
- [x] Nie zwei Aufnahmen gleichzeitig, und kein Aufnahmezustand überlebt einen
      Kartenwechsel.

### Stand am 2026-09-14 — implementiert

**603 Testfunktionen / 664 Einzelausführungen grün, 0 übersprungen**,
Debug-Build von null und Release-Build von null mit 0 Compilerdiagnosen. Ein
unabhängiges Code Review und ein unabhängiges Testaudit sind abgearbeitet.

**Was die beiden Prüfungen gefunden haben — zwei davon waren echte Fehler:**

- **Doppelstart auf dem Auto-Advance-Pfad.** `stopRecording` startete nach der
  Auswertung selbst eine Aufnahme, und der Kartenwechsel-Beobachter tat es noch
  einmal. `SpeechRecognitionService.startRecording()` setzt `phase = .recording`
  erst nach mehreren `await`, also kamen beide Aufrufe durch den Eingangsguard —
  zwei Mikrofonpfade gleichzeitig, oder ein erkannter Text, der stillschweigend
  verfiel. Behoben: **ein** Auslöser pro Kartenübergang.
- **Abbruch im Startfenster wirkte nicht.** `cancelRecording()` kehrt sofort
  zurück, solange noch keine Engine steht. Eine im Startfenster abgebrochene
  Aufnahme lief danach trotzdem an, gehörte keiner Karte und ihr Text wurde
  verworfen. Behoben über einen Generationszähler nach dem Muster, das der
  Service intern schon benutzt.
- **Wiedereinstreuung übersehen.** „Nochmal" auf der **letzten** Karte eines
  Batches legt dieselbe Karte zurück auf Position 0 — die Karten-ID ändert sich
  nicht, ein reiner ID-Beobachter verpasst das, und der Modus hätte still
  geschwiegen. Behoben über einen zusammengesetzten Schlüssel.
- **`.inactive` galt als Hintergrund.** Damit hätte der Mikrofon-Berechtigungs-
  dialog beim allerersten Tap den eigenen Versuch abgebrochen. Jetzt zählt nur
  `.background`, was auch dem Wortlaut der Roadmap entspricht.
- **Ein Test bewies nichts:** Er verglich zwei unabhängige UUIDs und war damit
  ein verkapptes Duplikat. Ersetzt durch echte Sequenztests über
  `SessionSpeechState`.
- Dazu: ein toter `.task`-Aufruf entfernt, ein nie ausgelöster Ereignisfall
  gestrichen, ein Modus-B-Guard am Sprachausgabe-Beobachter ergänzt, und
  dauerhaft nicht verfügbare Erkennung entwaffnet den Modus jetzt statt ihn
  in einer Senke stehen zu lassen.

**Gegenmutationen: zehn ausgeführt, alle greifen** — Schleifenschutz,
`isRevealed`-Guard, Richtungs-Guard, TTS entwaffnet nicht mehr,
`.noSpeechDetected` gilt als startbereit, Reveal bricht nicht ab,
Wiedereinstreuung öffnet keinen Versuch, Marker wird nie zurückgesetzt, Tap
armiert nicht, dauerhaft Unmögliches entwaffnet nicht.

**Offen und benannt:** Der Auto-Start ist hardwareabhängig und im Simulator
nicht auslösbar. Die reale Bedienung — Auto-Start beim Kartenwechsel, der
Berechtigungsdialog beim ersten Tap, Unterbrechung durch einen Anruf — gehört
in die [finale Geräte- und Release-Abnahme](#finale-geräte--und-release-abnahme)
und ist dort Teil des Abschnitts zum Audio-Lebenszyklus.

### Abhängigkeiten

Phase 9 (Erkennungspfad) und Phase 11 (Review- und Bewertungsverhalten). Ohne
Phase 11 würde ein Hands-free-Modus nach jeder Karte weiterhin eine manuelle
Bewertung verlangen und damit seinen eigenen Zweck verfehlen.

---

## Phase 13 — Lernflow & Assisted Classification UX

**Spezifiziert und implementiert am 2026-09-21.** Diese Phase ist vor dem
Produktcode vollständig ausgeschrieben worden — Flow, UI-Zustände, Regel,
Schemaänderung und Akzeptanzkriterien —, damit bei der Umsetzung keine
Designentscheidung implizit getroffen werden muss. Das hat gehalten: Bei der
Umsetzung ist keine Produktentscheidung neu aufgemacht worden. Was sich
geändert hat, steht unter „Stand am 2026-09-21" und ist jeweils eine Folge
schon getroffener Entscheidungen, nicht eine neue. Die verbindliche
Lernlogik steht in
[learning-engine.md §13](learning-engine.md#13-lernflow-und-assistierte-einstufung-phase-13);
hier steht, was gebaut wird und woran es gemessen wird.

### Ziel

Der Lernflow soll in der Hand liegen und nicht in vier Tasten. Zwei Probleme
sind gemeint:

1. **Die Vierfachauswahl ist die falsche Frage.** Phase 11 hat sie nur im
   sauberen Fall gespart; in jedem anderen Fall — Mismatch, Aufdecken, Retry,
   kein Mikrofon, Modus B, Rekalibrierung — stand sie weiter da. Und sie kommt
   **nach** dem Aufdecken: Der Unterschied zwischen *Schwer* und *Gut* ist
   dann eine Stimmung, keine Beobachtung.
2. **Der Aufnahmepfad hat keinen Abbruch.** Während einer Aufnahme gibt es nur
   „Aufnahme beenden", und das wertet aus. Ein verstolpertes „Moment, nochmal"
   kostet damit einen Versuch und ein Aufdecken.

Danach gilt: höchstens **eine binäre Frage** je Karte, und nur, wenn die App
für einen konkreten Schritt nach oben Evidenz hat. Sonst ein Knopf weiter.

### Scope

- Neuer Bedienfluss der Lernkarte in beiden Richtungen, inklusive Stop-Button
  und der Animation zwischen den beiden Aufnahmezuständen.
- *Antwort zeigen* wird in Modus A zu **Aufgeben** und übernimmt die Rolle,
  die bis Phase 12 „Nochmal" hatte — inklusive Wiedereinstreuung.
- Die vier `SelfAssessment`-Tasten verlassen den Lernflow.
- Neue assistierte Einstufung: *Weiter* oder „Neue Einstufung" mit *Ablehnen*
  / *Bestätigen*, `.new` eingeschlossen, Ablehnung berücksichtigt.
- **Eine** additive Schemaerweiterung auf `ReviewLog` für die Ablehnung.
- Verengung der Phase-12-Regel „Sprachausgabe entwaffnet den Sprachmodus".
- Dokumentation des Produktwunsches „chinesische Tastatur im Hanzi-Feld"
  und seiner Grenze (unten, Q12).

### Die UI-Zustände und ihre Übergänge

**Modus A, verdeckte Karte.** Zwei Zeilen. Zeile 2 ist immer der
Aufdeck-Knopf, Zeile 1 gehört dem Aufnahmepfad und hängt allein an
`SpeechRecognitionService.Phase` — dieselbe Tabelle wie in Phase 9, um einen
Zustand erweitert:

| Phase | Zeile 1 | Zeile 2 | Tap auf Zeile 1 |
| --- | --- | --- | --- |
| `idle`, `ready` | `[ Antwort sprechen ]` volle Breite | `[ Aufgeben ]` | startet Aufnahme **und** armiert den Sprachmodus (A39) |
| `recording` | `[ Fertig ][ ■ ]` | `[ Aufgeben ]` | *Fertig* beendet und wertet aus, *■* verwirft |
| `finalizing` | `[ Wird ausgewertet … ]`, inaktiv | `[ Aufgeben ]` | — |
| `preparing` | `[ Wird vorbereitet … ]`, inaktiv | `[ Aufgeben ]` | — |
| `downloading` | `[ Sprachmodell wird geladen … ]`, inaktiv, mit Apples `Progress` | `[ Aufgeben ]` | — |
| `noSpeechDetected` | `[ Antwort sprechen ]` + „Nichts erkannt. …" | `[ Aufgeben ]` | startet erneut (Tap nötig, A38) |
| `failed` | `[ Antwort sprechen ]` + Fehlertext | `[ Aufgeben ]` | startet erneut |
| `permissionDenied` | `[ Mikrofon nicht freigegeben ]` + Hinweis | `[ Aufgeben ]` | fragt erneut nach der Freigabe |
| `unavailable` | Zeile 1 entfällt, nur der Hinweissatz | `[ Aufgeben ]` | — |

**In Modus A heißt Zeile 2 in jedem dieser Zustände *Aufgeben*** — auch ohne
Mikrofonfreigabe und auf einem Gerät ohne Erkennung. Ein Bedienelement, das
sich je nach Mikrofonzustand umbenennt, ist schwerer zu lernen als eines, das
es nicht tut. Nur Modus B heißt weiter *Antwort zeigen*, weil das Aufdecken
dort der vorgesehene Schritt ist.

**Die Wiedereinstreuung hängt an einer eigenen, engeren Bedingung** und nicht
an der Beschriftung: Modus A **und** von Hand aufgedeckt **und** eine Aufnahme
war auf dieser Karte möglich, also die Phase war keine der beiden dauerhaft
unmöglichen. Ohne die dritte Bedingung würde auf einem Gerät ohne Erkennung
jede Karte wieder eingestreut und **jeder Batch doppelt so lang** — sieben
Karten würden zu vierzehn Fragen. Dass derselbe Knopf unsichtbar
unterschiedlich weiterplant, ist vertretbar, weil der Unterschied reine
Terminplanung ist: Er berührt weder Lernstand noch Evidenz noch irgendeine
Aussage an den Lernenden. Zwei Prädikate, eines für den Text, eines für die
Queue, beide rein und beide getestet
([learning-engine.md §13.5](learning-engine.md#135-wiedereinstreuung-aufgeben-ist-die-einzige-aussage-über-nichtwissen)).

**Die Animation.** `[ Antwort sprechen ]` → `[ Fertig ][ ■ ]`: Der breite
Knopf schrumpft nach rechts auf die Stop-Fläche, *Fertig* erscheint im frei
gewordenen Bereich. Rückweg umgekehrt. **Eine** Animation auf dem aus der
Phase abgeleiteten Zustand, nicht zwei unabhängige Übergänge — A33 steht für
genau diese Lektion. Zeile 2 bewegt sich dabei nicht; Zeile 1 behält ihre
Höhe.

**Was *■* tut und was nicht:** Es beendet oder verwirft **nur den laufenden
Aufnahmeversuch**. Keine Auswertung, kein Aufdecken, kein `ReviewLog`-Eintrag,
kein Zähler. Die Oberfläche animiert zurück zu `[ Antwort sprechen ]`, der
**Session-Sprachmodus bleibt aktiv**, und auf derselben Karte startet keine
Aufnahme von selbst — ein weiterer Anlauf braucht einen Tap (A38).

**Ist der Sprachmodus armiert und die nächste Karte startet ihre Aufnahme von
selbst, erscheint direkt `[ Fertig ][ ■ ]`** — nicht erst *Antwort sprechen*.
Das ergibt sich aus der Tabelle, weil der Zustand an der Phase hängt und nicht
daran, wer die Aufnahme gestartet hat; es ist trotzdem ein Akzeptanzkriterium,
weil es der sichtbare Kern des Zusammenspiels mit Phase 12 ist.

**Modus A, aufgedeckte Karte.** Die Antwort wie bisher
(`LearnRevealedAnswerView`, A34), darunter das Vergleichsergebnis aus Phase 9,
darunter genau einer von zwei Zuständen:

```text
kein Vorschlag                      Vorschlag liegt vor

[ Weiter ]                          Neue Einstufung
                                    Mittel → Gut

                                    [ Ablehnen ]  [ Bestätigen ]
```

*Bestätigen* ist der hervorgehobene Knopf, *Ablehnen* der gewöhnliche. **Kein
zusätzliches *Weiter* daneben:** *Ablehnen* **ist** der neutrale Ausgang, es
senkt nichts und ändert nichts. Keine Farbcodierung — ein Vorschlag ist kein
Urteil. Für VoiceOver wird der Pfeil ausgeschrieben („Neue Einstufung: von
Mittel auf Gut"), weil ein Pfeil kein Wort ist.

**Modus B.** Unverändert `nur Audio → [ Hanzi anzeigen ] → [ Antwort zeigen ]`,
danach `[ Weiter ]`. **Nie ein Vorschlag, nie eine Statusänderung, nie eine
Wiedereinstreuung** — ohne die vier Tasten gibt es dort kein
Correctness-Signal, und eine Ersatzheuristik wird nicht erfunden.

**Der Versuch ist mit dem Verlassen der Karte abgeschlossen** — mit *Weiter*,
*Bestätigen* oder *Ablehnen* —, und genau dann entsteht **genau ein**
`ReviewLog`-Eintrag. Das ist eine bewusste Präzisierung gegenüber „schreibt
den Review, deckt danach die Karte auf": Ausgewertet wird vor dem Aufdecken,
protokolliert beim Verlassen, weil der Eintrag tragen muss, wie die
Einstufungsfrage ausgegangen ist.

### Die neue Assisted-Classification-Regel

Vollständig in
[learning-engine.md §13.7](learning-engine.md#137-die-regel). Kurzfassung:

Ein **sauberer Versuch** ist unverändert Phase 11 — Sprache benutzt und Text
übereinstimmend, kein Retry, nichts vorher aufgedeckt. Neu ist, welche
Versuche in denselben Lauf gehören. Rückwärts vom laufenden Versuch, und nur
**vergleichbare**:

1. **gleiche Richtung** — ein Modus-B-Versuch wird übersprungen, nicht als
   Bruch gezählt;
2. **gleicher Ausgangsstatus** (`previousStatus == aktueller Status`) — das ist
   die Evidenz seit der letzten Statusänderung;
3. Abbruch am ersten unsauberen Versuch;
4. Abbruch an einer **Ablehnung**, die selbst nicht mitzählt.

Ab zwei vergleichbaren sauberen Versuchen gibt es einen Vorschlag: genau ein
Schritt nach oben über `StatusTransition.newStatus(from:for: .good)`, also die
*Gut*-Spalte der Matrix aus §6 — `Neu → Mittel`, `Schwach → Mittel`,
`Mittel → Gut`, `Gut → Sicher`, bei *Sicher* keiner.

**Regel 2 ist es, die `.new` freigibt.** Phase 11 hatte dort einen eigenen
Riegel, weil eine von Hand auf *Neu* zurückgesetzte Karte ihre Historie behält
und sofort eine Beförderung angeboten bekommen hätte. Der Riegel war richtig
aus dem falschen Grund — er prüfte den Status, wo die **Herkunft der Evidenz**
das Problem war. Regel 2 erledigt beides und entfällt damit.

**Ersetzte Phase-11-Regeln**, einzeln und mit Begründung in
[learning-engine.md §13.9](learning-engine.md#139-welche-phase-11-regeln-damit-ersetzt-sind):
`.ask` mit Vierfachauswahl, `.autoAdvance`, `autoAdvancesBeforeRecalibration`
(entfällt vollständig), der `.new`-Riegel, `ReviewSignal.isUsable`,
`cleanRunBeforeAutoAdvance` (umbenannt zu `cleanRunBeforeSuggestion`, Wert
unverändert 2). **Unverändert weiter gültig:** der saubere Versuch, alle
Verbote aus §12.4, „die Zahlen sind Produktentscheidungen, keine Messungen",
§7.1 und §6.1.

### Die Schemaänderung: zwei Felder

Vier Tatsachen müssen später ohne Raten auseinanderzuhalten sein: eine
**historische Selbsteinschätzung** aus dem alten Flow, eine **vorgeschlagene
Einstufung**, ihre **Annahme** und ihre **Ablehnung**.

**`assessment` ist dafür nicht verwendbar.** Das Feld bedeutet „der Lernende
hat eine der vier Selbsteinschätzungen abgegeben" und behält diese Bedeutung.
Eine Zustimmung zu einem Vorschlag der App dort hineinzuschreiben, weil sie
zufällig denselben Statusübergang erzeugt, würde die erste und die dritte
Tatsache ununterscheidbar machen — rückwirkend und ohne Weg zurück. **Der neue
Flow schreibt deshalb immer `assessment = nil`.**

Zwei additive, optionale Felder auf `ReviewLog`, im Store als RawValue wie
`previousStatusRaw`, beide Default `nil`:

| Feld | Typ | Bedeutung |
| --- | --- | --- |
| `suggestedStatusRaw` | `Int?` | der Status, den die App vorgeschlagen hat; `nil` = kein Vorschlag |
| `suggestionDecisionRaw` | `String?` | `SuggestionDecision`: `accepted` oder `declined`; `nil` = kein Vorschlag |

`SuggestionDecision` ist ein eigenes `nonisolated enum String` mit
ausgeschriebenen RawValues, weil sie Historie sind — dieselbe Regel wie bei
`SelfAssessment`, `SessionDirection` und `SpeechRate`. Die beiden Felder sind
immer gemeinsam gesetzt oder gemeinsam `nil`; das ist eine Invariante mit Test,
kein Vertrauen.

**Beide sind erforderlich**, nachgerechnet in
[learning-engine.md §13.10](learning-engine.md#1310-die-schemaänderung-zwei-felder-und-warum-genau-zwei):
Ohne `suggestedStatus` wäre der Vorschlag nur über die **heutige Fassung der
Regel** rekonstruierbar — eine Historie, deren Bedeutung an der aktuellen Regel
hängt, ist keine Historie; und §13.7 Regel 4 braucht genau diesen Status. Ohne
`suggestionDecision` wären Annahme und Ablehnung nicht unterscheidbar, denn der
Status der Karte liegt auf `Card` und wird vom nächsten Versuch überschrieben.
**Semantische Eindeutigkeit hat Vorrang vor der gesparten Property.**

`ReviewSignal` bekommt **nicht** beide Felder, sondern den einen abgeleiteten
Wert, den die Regel liest — `declinedSuggestion: LearningStatus?`, gebildet an
der Abbildungsgrenze wie `Card → CardSnapshot`. Die Annahme braucht die Regel
nicht: Ein angenommener Vorschlag hat den Status bewegt, sein Eintrag trägt
also einen anderen `previousStatus` und fällt schon durch Regel 2 heraus.

**Keine zweite Bewertungshistorie**, kein zweites Modell, nichts in den
`UserDefaults`: ein Versuch, ein Eintrag.

Das ist die **zweite** Schemaänderung des Projekts und die erste an einem
**bestehenden** Modell. Q7 ist für ein neues Modell plus Beziehung gemessen,
für neue Properties **nicht** — deshalb ist die Messung ein Akzeptanzkriterium
dieser Phase und Q7 hat dafür einen offenen Teil.

### Am 2026-09-21 entschieden — keine offenen Produktentscheidungen mehr

Diese sechs Punkte standen im Spezifikationsdurchgang zur Klärung und sind
**entschieden**. Sie werden bei der Umsetzung nicht neu aufgemacht:

1. **Modus A ohne verwertbare Speech-Evidenz und Modus B sind in Phase 13
   statusneutral.** Ohne sauberen Versuch gibt es keinen Vorschlag, also bewegt
   sich der Lernstand dort nicht von selbst. Das ist die angenommene Folge aus
   „keine neue Ersatzheuristik erfinden", keine Lücke. Die Rückfallebene liegt
   im Backlog und wird erst nach dem Alltagstest bewertet. **Nachtrag vom
   2026-09-21:** Dieser Punkt verwies ursprünglich auf das Setzen des Status in
   der Kartenübersicht — das Review hat gefunden, dass dieses Bedienelement nicht
   existierte, und es ist daraufhin nachgezogen worden. Siehe § *Der offene Punkt
   der Phase 13*.
2. **`Neu → Mittel` ist der erste Vorschlag** nach ausreichender sauberer
   Evidenz — die *Gut*-Spalte der Matrix aus §6, keine neue Leiter. *Schwach*
   wird dabei übersprungen, weil *Neu* laut §6 mit Stufe 1 verrechnet wird und
   zwei saubere Versuche mit *Schwach* zu belohnen wie eine Abwertung läse.
3. **Ein ASR-Mismatch bewirkt keine Wiedereinstreuung.** Er ist ausdrücklich
   keine negative Evidenz; ihn zur Wiederholungsentscheidung zu machen wäre
   eine Handlung auf ein Signal, dem die App nach eigener Aussage nicht traut.
4. **Nur *Aufgeben* streut wieder ein, und genau einmal pro Mini-Batch** —
   `maxReinserts` = 1, Position nach §5 unverändert, und nur, wenn eine
   Aufnahme auf dieser Karte möglich war.
5. **Die toten Produktionspfade `SessionQueue.assess` und `AssessmentOutcome`
   werden bei der Umsetzung entfernt** — sofern die Aufrufersuche bestätigt,
   dass sie nicht mehr gebraucht werden. Dasselbe gilt für
   `SelfAssessment.countsAsCorrect`, `keepsCardInBatch` und
   `AssistedAssessment.assessment(leadingTo:from:)`. **Die Queue- und
   Wiedereinstreuungssemantik bleibt dabei testgesichert:** Position hinter den
   ungesehenen Karten, Mindestabstand, Obergrenze und Batchende werden gegen
   die neue API erneut festgenagelt, nicht aufgegeben.
6. **Der Toolbar-Knopf der Session heißt *Beenden*** statt *Fertig* — sonst
   stünde „Fertig" zweimal mit zwei Bedeutungen auf demselben Bildschirm.

Offen bleibt ausschließlich der **Umfang von Phase 14**, und das ist keine
Phase-13-Entscheidung.

### Tasks

- **13.1** `SuggestionDecision` als eigenes `nonisolated enum String` anlegen;
  `ReviewLog` um `suggestedStatusRaw: Int?` und `suggestionDecisionRaw: String?`
  samt der beiden berechneten Properties erweitern; `ReviewSignal` um den
  abgeleiteten `declinedSuggestion`. `SchemaMigrationTests` um den Fall
  „Phase-12-Store öffnet mit Phase-13-Schema" erweitern, und die
  Gemeinsam-gesetzt-Invariante der beiden Felder festnageln.
- **13.2** `AssistedAssessment` auf die neue Regel umstellen: Entscheidung
  `.continueOnly` / `.propose(LearningStatus)`, Lauf nach §13.7,
  `cleanRunBeforeSuggestion`, `autoAdvancesBeforeRecalibration` und den
  `.new`-Riegel entfernen, `isUsable` durch die Richtungsregel ersetzen.
  `assessment(leadingTo:from:)` **entfällt** — es gibt keine Taste mehr, und
  *Bestätigen* wird ausdrücklich nicht als Selbsteinschätzung gespeichert.
- **13.3** `SessionQueue`: `assess(_:currentStatus:)` und `AssessmentOutcome`
  durch `closeCurrentCard(reinserting:)` und ein `AttemptOutcome` ohne
  `assessment`/`newStatus` ersetzen. Position, `maxReinserts` und
  „ungesehene zuerst" bleiben unverändert — nur der Auslöser ändert sich.
  `SelfAssessment.keepsCardInBatch` und `countsAsCorrect` verlieren damit ihre
  Aufrufer und entfallen (§13.9); `statusDelta` bleibt — es trägt die Matrix aus
  §6, aus der der Vorschlag gebildet wird.
- **13.4** Neue reine Regeln in `Features/Learn/LearnFlow.swift`: Beschriftung
  des Aufdeck-Knopfes (*Aufgeben* in Modus A immer, *Antwort zeigen* in Modus B)
  und — **davon getrennt** — „streut wieder ein" aus Richtung und
  Erkennungsphase. Zwei Prädikate, nicht eines: Die Beschriftung ist in Modus A
  konstant, die Wiedereinstreuung nicht. Keine dieser Bedingungen darf allein
  in einem `body` stehen.
- **13.5** `RecordAnswerButton` um den geteilten Zustand `[ Fertig ][ ■ ]`
  und einen `cancel`-Aufrufer erweitern, samt Animation. Symbol `stop.circle`
  wiederverwenden — kein neuer SF-Symbol-Name.
- **13.6** `SelfAssessmentBar` durch `RevealedDecisionBar` ersetzen:
  `[ Weiter ]` oder „Neue Einstufung" mit *Ablehnen* / *Bestätigen*,
  inklusive VoiceOver-Beschriftung des Übergangs.
- **13.7** `LearnSessionModel`: Aufdecken mit und ohne Aufgeben trennen, den
  Versuch beim Verlassen der Karte protokollieren — **immer mit
  `assessment = nil`** —, *Bestätigen* als `.accepted` plus den neuen Status,
  *Ablehnen* als `.declined`, beide mit `suggestedStatus`. `correctCount`
  bewegt sich auf keinem dieser Pfade. Wiedereinstreuung an die eigene,
  engere Bedingung hängen. Fehlerpfad wie bisher: `rollback()`, Karte bleibt
  aufgedeckt, **Vorschlag bleibt stehen**, dieselbe Entscheidung ist erneut
  möglich.
- **13.8** `SessionSpeechEvent` um den vom Lernenden abgebrochenen Versuch
  erweitern (Modus bleibt aktiv, Aufnahme wird verworfen, kein neuer Versuch
  auf derselben Karte) und die Sprachausgabe-Regel auf den verdeckten Zustand
  verengen. Die Reihenfolge **Sprachausgabe stoppen → Kartenwechsel → erst
  danach die automatische Aufnahme** bleibt an **einem** Beobachter je
  Kartenübergang und wird als Sequenz über `SessionSpeechState` geprüft; sie
  ist das Einzige, was nach der Verengung noch verhindert, dass Ton und
  Mikrofon aufeinandertreffen. Das Ereignis „Bewertung abgegeben" heißt jetzt inhaltlich
  „Versuch abgeschlossen" und wird entsprechend benannt.
- **13.9** Texte: der Toolbar-Knopf zum Beenden der Session heißt **Beenden**
  statt *Fertig* — sonst stünde „Fertig" zweimal mit zwei Bedeutungen auf dem
  Bildschirm. Hinweistexte, die auf *Antwort zeigen* verweisen, auf die neue
  Beschriftung bringen.
- **13.10** Tests: `LearnFlowTests` neu; `AssistedAssessmentTests`,
  `SessionQueueTests`, `LearnSessionModelTests`, `ReviewHistoryTests`,
  `SessionSpeechModeTests`, `SchemaMigrationTests` und die Wortlautprüfung in
  `SpeechRecognitionTests` erweitern. Die verbotenen Wortlaute gelten für
  jede neue sichtbare Zeichenkette — „Ton" ist als Teilwort verboten.
- **13.11** Dokumentation: `learning-engine.md` §13 (liegt vor),
  `architecture.md` §3, §9.1 und die Entscheidungstabelle, `apple-frameworks.md`
  Q7 und Q12, `README.md`, `CLAUDE.md`.

### Akzeptanzkriterien

**Flow und UI**

- [x] In Modus A stehen auf der verdeckten Karte zwei Zeilen, und Zeile 1
      folgt in allen zehn Erkennungsphasen der Tabelle oben.
- [x] Ein Tap auf *Antwort sprechen* startet die Aufnahme **und** armiert den
      Sprachmodus, und Zeile 1 zeigt danach `[ Fertig ][ ■ ]`.
- [x] *■* verwirft den Versuch: keine Auswertung, kein Aufdecken, **kein**
      `ReviewLog`-Eintrag, kein Zähler bewegt sich, der Sprachmodus bleibt
      aktiv, und auf derselben Karte startet keine Aufnahme von selbst.
- [x] *Fertig* finalisiert, vergleicht über den unveränderten Phase-9-Pfad und
      deckt die Karte auf.
- [x] *Aufgeben* während `finalizing` gewinnt: Das Ergebnis der laufenden
      Analyse erreicht die Karte nicht mehr, und der Versuch gilt als von Hand
      aufgedeckt.
- [x] Scheitert das Speichern bei *Bestätigen* oder *Ablehnen*, bleibt die
      Karte aufgedeckt **und der Vorschlag stehen**; dieselbe Entscheidung ist
      erneut möglich.
- [x] Startet die Aufnahme einer neuen Karte von selbst, erscheint direkt
      `[ Fertig ][ ■ ]` und nicht *Antwort sprechen*.
- [→] Der Übergang zwischen den beiden Aufnahmezuständen ist **eine**
      Animation; Zeile 2 bewegt sich dabei nicht. **In die
      [finale Geräte- und Release-Abnahme](#finale-geräte--und-release-abnahme)
      verschoben** (2026-09-21): Der Code hat genau ein `.animation` auf dem aus
      der Phase abgeleiteten Wert und Zeile 2 liegt außerhalb des animierten
      `HStack` — wie ein Übergang *wirkt*, erreicht aber kein Unit-Test. Das ist
      eine Darstellungsprüfung des fertigen Produkts, kein technisches Gate
      dieser Phase.
- [x] *Aufgeben* verwirft eine laufende Aufnahme, deckt auf, zählt als
      manueller Reveal, liefert **keine** positive Evidenz und verbessert
      **keinen** Status.
- [x] Die Vierfachauswahl erscheint in keinem Zustand des Lernflows mehr.
- [x] Nach dem Aufdecken steht entweder `[ Weiter ]` oder die Einstufungsfrage
      mit *Ablehnen* und *Bestätigen* — nie beides, nie ein drittes Element.
- [x] Modus B: `[ Weiter ]` nach dem Aufdecken, **nie** ein Vorschlag, **nie**
      eine Statusänderung, **nie** eine Wiedereinstreuung.
- [x] Zeile 2 heißt in Modus A in **jedem** Erkennungszustand *Aufgeben* —
      auch bei `permissionDenied` und `unavailable`. Nur Modus B heißt
      *Antwort zeigen*.
- [x] Wieder eingestreut wird genau dann, wenn in Modus A von Hand aufgedeckt
      wurde **und** eine Aufnahme auf dieser Karte möglich war — und dann
      **genau einmal** pro Mini-Batch (`maxReinserts`).
- [x] Auf einem Gerät ohne Erkennung wird **nichts** wieder eingestreut; ein
      Batch bleibt so lang wie seine Kartenzahl.
- [x] Läuft beim Verlassen der Karte noch eine Sprachausgabe, ist die
      Reihenfolge: **Sprachausgabe stoppen → Kartenwechsel → erst danach die
      automatische Aufnahme.** Nie Sprachausgabe und Mikrofon gleichzeitig,
      und **ein** Auslöser je Kartenübergang.
- [x] „Fertig" steht nicht zweimal mit zwei Bedeutungen auf dem Bildschirm.

**Regel**

- [x] Ein einzelner Exact-Match erzeugt keinen Vorschlag.
- [x] Ein Mismatch senkt nichts, schlägt nichts vor, beendet den Lauf und
      bewirkt **keine** Wiedereinstreuung.
- [x] Ein Retry ist keine positive Evidenz.
- [x] Manueller Reveal und *Aufgeben* sind keine positive Evidenz **und
      brechen den Lauf** — auch dann, wenn dabei weder Sprache benutzt noch
      eine Bewertung abgegeben wurde.
- [x] Es existiert **kein** Pfad, auf dem die App einen Status senkt.
- [x] Ohne Tap auf *Bestätigen* ändert sich kein Status.
- [x] Ein Vorschlag ist höchstens eine Stufe nach oben.
- [x] Eine Karte auf `.new` bekommt nach zwei sauberen Versuchen ihren ersten
      Vorschlag (`Neu → Mittel`).
- [x] Eine von Hand auf `.new` zurückgesetzte Karte bekommt **keinen**
      Vorschlag aus ihrer alten Historie.
- [x] Nach *Ablehnen* erscheint derselbe Vorschlag erst wieder, wenn nach der
      Ablehnung erneut die vollständige Schwelle sauberer Versuche erreicht
      ist — und das gilt **über einen App-Neustart hinweg**.
- [x] Nach *Bestätigen* braucht die nächste Stufe zwei frische saubere
      Versuche; zwei Beförderungen hintereinander sind unmöglich.
- [x] Ein Versuch in der anderen Richtung bricht den Lauf **nicht**.
- [x] Die Regel liegt vollständig in `Learning/`, ist rein, deterministisch,
      Foundation-only und kennt weder `Card` noch `ModelContext`.
- [x] Kein Score, kein Prozentwert, keine Konfidenz, keine Aussage über
      Aussprache oder Töne, keine Streaks.

**Persistenz**

- [x] Pro abgeschlossenem Versuch entsteht **genau ein** `ReviewLog`-Eintrag,
      geschrieben beim Verlassen der Karte.
- [x] Der neue Flow schreibt `assessment` **niemals** — auf keinem der drei
      Abschlusswege. Das Feld bleibt ausschließlich die historische
      Selbsteinschätzung des alten Flows.
- [x] `correctCount` bewegt sich auf **keinem** Pfad des neuen Flows, auch
      nicht bei *Bestätigen*.
- [x] *Weiter* ohne Vorschlag schreibt `suggestedStatus = nil` und
      `suggestionDecision = nil` und lässt `status` unberührt.
- [x] *Bestätigen* schreibt `suggestedStatus` = den Vorschlag,
      `suggestionDecision = .accepted` und den neuen Status auf die Karte.
- [x] *Ablehnen* schreibt `suggestedStatus` = den Vorschlag,
      `suggestionDecision = .declined` und lässt `status` unberührt.
- [x] Die vier Fälle — historische Selbsteinschätzung, Vorschlag angenommen,
      Vorschlag abgelehnt, Versuch ohne Vorschlag — sind aus einem einzelnen
      Eintrag **eindeutig** unterscheidbar, ohne eine Regel anzuwenden.
- [x] `suggestedStatus` und `suggestionDecision` sind immer gemeinsam gesetzt
      oder gemeinsam `nil`.
- [x] Die Ablehnung ist persistiert und nach einem Neustart wirksam.
- [x] Die Erweiterung ist additiv: Ein mit dem **Phase-12-Schema**
      geschriebener Store öffnet mit dem Phase-13-Schema ohne Verlust und ohne
      Migrationsplan — gemessen, nicht angenommen (Q7, neue Properties auf
      einem bestehenden Modell).
- [x] Es entsteht **keine** zweite Bewertungshistorie.

**Unverändert**

- [x] Gewichtung, Batch-Auswahl, Recency und Pool-Regeln sind unberührt.
- [x] Wiedereinstreuungsposition, `reinsertGap` und `maxReinserts` verhalten
      sich wie in §5 beschrieben, nur mit *Aufgeben* als Auslöser.
- [x] „Statusänderung nur einmal pro Mini-Batch" (§6.1) gilt und ist durch
      einen Test festgenagelt, obwohl sie strukturell folgt.
- [x] Der Phase-9-Erkennungspfad, `AnswerNormalization` und `SpeechCheck` sind
      unverändert; kein Fuzzy Matching, keine Konfidenz.
- [x] Phase 12 bleibt vollständig wirksam; geändert ist ausschließlich, dass
      Sprachausgabe den Modus nur bei verdeckter Karte entwaffnet.
- [x] Kein eigenes Endpointing, kein Timeout als Ersatz.
- [x] Keine externe Dependency, keine Analytics, kein Netzwerk.

### Der Produktwunsch „chinesische Tastatur im Hanzi-Feld"

**Wunsch:** Bekommt das Hanzi-Feld im Karteneditor den Fokus, soll möglichst
die chinesische Eingabe verwendet werden.

**Geprüft am 2026-09-21 gegen die Apple-Dokumentation — das ist so nicht
zulässig, und für SwiftUI gar nicht** (Q12 in
[apple-frameworks.md §10](apple-frameworks.md#10-offene-technische-fragen-zu-klären-vor-der-jeweiligen-phase)).
Kurz:

- Es gibt **keine setzende Input-Mode-API.** `UITextInputMode` ist in allen
  Membern lesend, `currentInputMode` ist seit iOS 7 deprecated, und die
  einzigen umschaltenden Symbole gehören zu einem Keyboard-Extension-Target —
  ausgeschlossen, weil diese App kein eigenes Keyboard baut.
- Dokumentiert möglich ist nur **Bevorzugen** pro Feld, durch Überschreiben
  von `UIResponder.textInputMode` in einer UIKit-Subklasse, und der Wert muss
  aus `UITextInputMode.activeInputModes` kommen — also aus den Tastaturen, die
  der Nutzer **selbst** hinzugefügt hat. Eine Tastatur hinzuzufügen kann keine
  App, und einen Deep Link in die Tastatur-Einstellungen gibt es nicht.
- **SwiftUI hat dafür nichts.** `.keyboardType` wählt den Stil, nicht die
  Sprache; `typesettingLanguage` betrifft die Darstellung.

**Konsequenz: In Phase 13 wird dazu nichts gebaut, und es wird nichts
versprochen.** Die Einschränkung ist dokumentiert, statt ein Verhalten
anzukündigen, das iOS nicht erlaubt. Der bestehende Weg bleibt der Weg: Die
Kette `Deutsch → Hanzi → Pinyin` erzeugt das Hanzi ohne chinesische Tastatur,
und wer von Hand tippen will, schaltet die Tastatur wie in jeder anderen App
um. Was **falls überhaupt** später in Frage kommt, steht im Backlog — in der
dort begründeten Reihenfolge und ausdrücklich ohne Erzwingen.

### Stand am 2026-09-21 — implementiert und verifiziert (READY)

**Verdict: READY.** Build, Tests und alle technischen Akzeptanzkriterien der
Phase sind erfüllt; die drei Darstellungs- und Interaktionsprüfungen stehen mit
`[→]` in der finalen Geräte- und Release-Abnahme und sind ausdrücklich **kein**
Gate dieser Phase — so sieht es die Regelung vom 2026-09-13 vor.

**649 Testfunktionen / 707 Einzelausführungen grün, 0 übersprungen**,
Debug-Build von null und Release-Build von null mit 0 Compilerdiagnosen. **Zwei**
unabhängige Code Reviews und **zwei** unabhängige Testaudits sind durchgeführt —
die zweite Runde geprüft die Nachlieferung der manuellen Korrektur — und ihre
Findings vollständig abgearbeitet, einschließlich des Blockers, der eine
Produktentscheidung verlangte und unten einzeln steht.

**Eine bewusste Abweichung von Task 13.3, und sie ist kleiner als geplant:**
Die Spezifikation sah vor, `AssessmentOutcome` durch ein `AttemptOutcome` ohne
`assessment`/`newStatus` zu ersetzen. Beim Umbau hatte dieses Objekt **keinen
Leser mehr**: Der Status wird nur bei *Bestätigen* geschrieben und kommt dort
aus dem Vorschlag, „erster Versuch im Batch" wird über
`reinsertCount(for:)` beantwortet, und das Batchende fragt der Aufrufer direkt
mit `isFinished` ab. `closeCurrentCard(reinserting:)` gibt deshalb nur
`Bool` zurück — ob überhaupt eine Karte geschlossen wurde. Ein zurückgegebener
Wert, den niemand liest, ist ein Versprechen ohne Deckung; die Regel steht
sonst unverändert.

**Was die Umsetzung an der Spezifikation korrigiert hat:**

- **Beschriftung und Wiedereinstreuung sind zwei Prädikate, nicht eines.** Die
  erste Fassung der Spezifikation hängte beides an dieselbe Bedingung. Der
  Nutzer hat entschieden, dass der Knopf in Modus A **in jedem** Zustand
  *Aufgeben* heißt — auch ohne Mikrofonfreigabe. Die Wiedereinstreuung darf
  dieser Beschriftung aber nicht folgen, sonst würde auf einem Gerät ohne
  Erkennung jeder Batch doppelt so lang. Zwei reine Prädikate, beide getestet
  (`LearnFlowTests.labelAndReinsertionAreDecoupled`).
- **`correctCount` bewegt sich auf *keinem* Pfad mehr**, auch nicht bei
  *Bestätigen*. Die Spezifikation hatte *Bestätigen* über
  `SelfAssessment.countsAsCorrect` noch zählen lassen; das fiel weg, sobald
  entschieden war, dass der neue Flow `assessment` **niemals** schreibt. Beides
  gehört zusammen, und §13.4 sagt es jetzt so.
- **`AssistedAssessment.assessment(leadingTo:from:)` entfällt.** Die
  Spezifikation ließ sie stehen, weil sie *Bestätigen* in einen Eintrag
  übersetzen sollte. Mit den zwei eigenen Feldern hat sie keinen Aufrufer mehr.

**Drei Testfehler, die die Suite gefunden hat und die alle in den Tests lagen:**

- **Ein Use-after-free im Test, und er hat den ganzen Testprozess
  mitgenommen.** Ein Helfer legte einen `ModelContainer` als lokale Konstante
  an und gab die `Card` zurück; der Container wurde beim Verlassen freigegeben,
  und der Zugriff auf die Karte danach war ein Zugriff auf einen freigegebenen
  Backing Store. Im parallelen Lauf sah das aus wie „500 Tests fehlgeschlagen",
  weil der Crash den Worker riss — alle mit `0.000 seconds`, also nie gelaufen.
  Erst ein serieller Lauf zeigte den einen echten Verursacher. Jetzt werden die
  Zähler **innerhalb** des Helfers gelesen, solange der Container lebt.
- **Ein zweiter Fall derselben Klasse:** `@Model`-Prüfobjekte, die in keinem
  Context lagen. Sie liegen jetzt in einem eigenen In-Memory-Container.
- **Ein Test mit gefrorener Uhr las eine ungeordnete Historie.** Mehrere
  Einträge mit identischem `reviewedAt` machen „neueste zuerst" undefiniert —
  ein Test, der nach Glück bestanden hätte. Er benutzt jetzt eine laufende Uhr.
- **Ein Test, der nicht fehlschlagen konnte,** ist ersetzt worden: Er wollte
  zeigen, dass der Aufgeben-Merker nicht zwischen Karten überläuft, prüfte das
  aber über die Queue, wo `wasManualReveal` die Bedingung ohnehin dominiert. Die
  neue Fassung prüft, was wirklich kaputtgehen kann — dass der Merker pro
  Versuch **übernommen** und nicht akkumuliert wird.

**Gegenmutationen: einundzwanzig ausgeführt, alle greifen.** Jede wurde einzeln
angewandt, die betroffenen Suiten liefen, und die Mutation wurde
zurückgenommen:

| # | Mutation | rot geworden (Beispiel) |
| --- | --- | --- |
| 1 | Schwelle 2 → 1 | 32 Tests, u. a. `withoutSpeechNothingIsOffered` |
| 2 | Gleichstatus-Regel gestrichen | `manualResetDiscardsOldEvidence` (beide Suiten) |
| 3 | Ablehnung bricht den Lauf nicht mehr ab | `declineResetsTheEvidence`, `declineSurvivesARestart` |
| 4 | andere Richtung bricht statt zu überspringen | `otherDirectionIsSkippedNotCounted` |
| 5 | Wiedereinstreuung ignoriert „Aufnahme war möglich" | 11 Tests, u. a. `storedBatchSizeIsUsed` |
| 6 | Wiedereinstreuung ignoriert den manuellen Reveal | `aFinishedAttemptDoesNotReinsert` |
| 7 | *Bestätigen* wird als Selbsteinschätzung gespeichert | `acceptingWritesTheOfferedStatus` |
| 8 | *Bestätigen* hebt `correctCount` | `correctCountNeverMovesAgain` |
| 9 | Sprachausgabe entwaffnet auch auf der aufgedeckten Karte | `ordinaryEventsKeepTheMode`, `everyEventIsDecided` |
| 10 | *Stop* öffnet einen neuen automatischen Versuch | `cancellingKeepsTheModeAndTheLoopGuard` |
| 11 | die Stop-Zeile überlebt bis in `finalizing` | `stopControlIsDerivedFromThePhase` |
| 12 | Modus A verliert die Beschriftung *Aufgeben* | 13 Tests, u. a. `modeAAlwaysSaysAufgeben` |
| 13 | der Vorschlag springt zwei Stufen | 25 Tests, u. a. `declineResetsTheEvidence` |
| 14 | die Queue ignoriert den Wiedereinstreuungswunsch | 24 Tests, u. a. `fullBatchLengthMatchesThePromise` |
| 15 | die Evidenzgrenze wird ignoriert | 8 Tests, u. a. `newReviewsCountAgain` |
| 16 | eine Korrektur setzt keine Grenze | 9 Tests, u. a. `theBoundaryIsStrict` |
| 17 | dieselbe Stufe erneut zu wählen ist kein No-op mehr | `samePickIsANoOp` |
| 18 | die Korrektur zählt als Review (`reviewCount`, `lastReviewedAt`) | `correctionIsNotAnAnswer` |
| 19 | die Korrektur speichert nicht | `correctionIsPersisted` |
| 20 | die Grenze wird nicht persistiert (`@Transient`) | `evidenceBoundaryMigratesLightly`, `storeContainsExactlyTheDocumentedAttributes` |
| 21 | ein veralteter Vorschlag bleibt gültig | 6 Tests, u. a. `aCorrectionExpiresAStandingOffer` |

Die letzten vier hat das Testaudit als fehlend benannt — drei davon deckten
vorhandene Tests ab, ohne ausgeführt worden zu sein, und die vierte prüft den
Guard, den das Code Review erzwungen hat.

**Eine Warnung für den nächsten Durchgang, teuer gelernt:** Ein
Mutationsskript, das die Datei mit `git checkout --` zurücksetzt, wirft bei
einer **uncommitteten** Phase die ganze Arbeit an dieser Datei weg — hier zwei
Dateien der Lernschicht, die aus dem Kontext wiederhergestellt werden mussten.
Zurückgenommen wird eine Mutation aus einer **Byte-Kopie** der Datei, nie aus
Git.

### Der offene Punkt der Phase 13 — am 2026-09-21 entschieden und eingelöst

**Das Code Review hat einen echten Widerspruch gefunden**, und er war im Code
nachgeprüft: `card.status` wurde in der gesamten App an genau einer Stelle
geschrieben, und es gab **kein** Bedienelement, um einen Lernstand von Hand zu
setzen. Die Kartenübersicht zeigte ihn als Punkt und filterte danach, der Picker
im Editor ist seit Phase 6 (Task 6.10) entfernt, und das in
[learning-engine.md §6.2](learning-engine.md) seit Phase 1 spezifizierte Setzen
war nie gebaut worden.

Bis Phase 12 war das folgenlos, weil *Nochmal* (−2) und *Schwer* (−1) nach unten
führten. Phase 13 entfernte beide und verwies für die Korrektur auf ein
Bedienelement, das es nicht gab — also gab es überhaupt keinen Weg nach unten
mehr, auch nicht für eine Karte, die zwei zufällige Erkennungstreffer nach oben
getragen haben. Wie oft ein Treffer zufällig entsteht, ist **ungemessen**; genau
das war der Grund, einem einzelnen Treffer nichts zu glauben.

**Entschieden: das Bedienelement wird nachgezogen** — keine Umformulierung, keine
Rückkehr der Selbsteinschätzung, sondern die Einlösung dessen, was §6.2 seit
Phase 1 beschreibt. Umgesetzt als Kontextmenü auf der Kartenzeile, *Lernstand
setzen* mit den fünf Stufen und dem aktuellen markiert; die Auswahl schreibt und
persistiert sofort, ohne Bestätigungsdialog, und dieselbe Stufe erneut zu wählen
ist ein No-op.

**Der schwierige Teil war nicht das Setzen, sondern die Evidenzgrenze.** Eine
Karte, die *Mittel → Sicher* gegangen ist und von Hand auf *Mittel*
zurückgesetzt wird, trägt ihre alten *Mittel*-Reviews — die nach der
Gleichstatus-Regel wieder vergleichbar sind, sodass der nächste saubere Versuch
sofort erneut *Mittel → Gut* anbieten würde. Deshalb setzt die Korrektur
`Card.classificationEvidenceResetAt`, und danach zählt nur, was **nach** dieser
Linie liegt. Die Historie wird nicht gelöscht; die Linie verschiebt sich.

Ein eigenes Feld, weil vorher geprüft wurde, ob ein vorhandenes die Semantik
trägt: `lastReviewedAt` bewegt sich bei jedem Review und würde auch die frischen
Versuche ausschließen, `createdAt` bewegt sich nie, die Zähler sind Zähler, die
`…WasEditedManually`-Merker gehören zum Text, und `ReviewLog.previousStatus` ist
das Feld, an dem der Fall scheitert. Vollständig in
[learning-engine.md §13.13](learning-engine.md#1313-die-manuelle-korrektur-und-ihre-evidenzgrenze).

**Zusätzliche Akzeptanzkriterien dieser Nachlieferung, alle erfüllt:**

- [x] Eine Karte lässt sich auf **jeden** der fünf Stufen setzen, und die
      Markierung des aktuellen Stands wird von VoiceOver ausgesprochen, nicht nur
      gezeichnet.
- [→] Dass das **Kontextmenü** aufgeht, den Haken zeigt und mit Tap und Swipe
      koexistiert: **in die
      [finale Geräte- und Release-Abnahme](#finale-geräte--und-release-abnahme)
      verschoben** (2026-09-21). Ein Long-Press auf eine Zeile, in der ein
      `Button` die halbe Breite einnimmt, ist genau die A27-Anordnung, die in
      Phase 6 zwei Geräterunden gekostet hat — eine Interaktionsprüfung des
      fertigen Produkts, kein technisches Gate dieser Phase.
- [x] Die Auswahl schreibt und persistiert sofort.
- [→] Dass **kein Bestätigungsdialog** dazwischenliegt: **in die
      [finale Geräte- und Release-Abnahme](#finale-geräte--und-release-abnahme)
      verschoben** (2026-09-21). Strukturell belegt durch das Fehlen eines
      Bestätigungszustands — das Löschen hat mit `cardPendingDeletion` einen —,
      aber kein Test sieht einen Dialog.
- [x] Dieselbe Stufe erneut zu wählen ist ein No-op — und setzt **auch keine**
      Evidenzgrenze.
- [x] Der Statuspicker kommt **nicht** in den Karteneditor zurück.
- [x] Eine Korrektur schreibt keinen `ReviewLog`, bewegt weder `reviewCount` noch
      `correctCount` noch `lastReviewedAt` und streut keine Karte wieder ein.
- [x] Die bestehende Review-Historie wird nicht gelöscht.
- [x] Reviews von **vor** der Korrektur liefern keine Evidenz mehr; ein Review
      mit demselben Zeitstempel zählt nicht.
- [x] Reviews **nach** der Korrektur zählen normal, und nach zwei sauberen
      Versuchen — dem protokollierten und dem laufenden — darf wieder
      *Mittel → Gut* vorgeschlagen werden.
- [x] Der Wechsel auf `.new` verhält sich wie jede andere Korrektur.
- [x] Status und Grenze überleben einen Neustart.
- [x] Die Erweiterung ist additiv: Ein mit dem **Phase-13-Schema** geschriebener
      Store öffnet ohne Migrationsplan, jeder Wert unverändert, die neue Property
      als `nil` — gemessen, nicht angenommen (Q7, dritter additiver Fall).

### Was nur strukturell gilt, und nicht behauptet wird

Vier Akzeptanzkriterien sind **nicht** durch einen Test gedeckt, und das steht
hier statt in einer Fußnote:

| Kriterium | warum kein Test, und worauf es ruht |
| --- | --- |
| „■ schreibt keinen Eintrag und bewegt keinen Zähler" | Der Abbruch erreicht das Model gar nicht — `cancelRecordingByLearner()` berührt nur `speechState`. Es gibt keinen Eingang, über den ein Eintrag entstehen könnte |
| „Speicherfehler: Karte bleibt aufgedeckt, Vorschlag bleibt stehen" | Der Fehlerpfad ist im Testbundle nicht provozierbar (seit Phase 2 begründet). Gepinnt ist die tragende Eigenschaft: `SessionQueueTests.advancingACopyDoesNotAffectTheOriginal` |
| „Sprachausgabe stoppen → Kartenwechsel → Auto-Aufnahme" | Die **eine Hälfte** ist prüfbar und geprüft (`LearnFlowTests.theCycleKeyChangesOncePerTransition`); dass `speech.stop()` zuerst läuft, liegt in einem `body`. Es ruht auf zwei Stellen, nicht auf einer Anweisungsreihenfolge |
| „Eine Animation, Zeile 2 bewegt sich nicht" | Wie ein Übergang wirkt, erreicht kein Unit-Test |
| „Das Kontextmenü geht auf und zeigt den Haken" | `.contextMenu` sitzt am `HStack`, in dem ein `Button` die halbe Zeile einnimmt (A27). Getestet sind die Stufenliste, das gesprochene Label und die Modellschicht — nicht die Gestik |
| „Kein Bestätigungsdialog" | Belegt durch das Fehlen eines Bestätigungszustands, nicht durch einen Test |
| „Eine Korrektur streut keine Karte wieder ein" | `LearningStatusCorrection` sieht weder `SessionQueue` noch `LearnSessionModel` — es gibt keinen Eingang, über den es geschehen könnte |

**Drei davon sind mit `[→]` gekennzeichnet** — Animation, Kontextmenü-Gestik,
Dialogfreiheit. Sie sind **weder erfüllt noch offen gegen diese Phase**, sondern
am 2026-09-21 in die
[finale Geräte- und Release-Abnahme](#finale-geräte--und-release-abnahme)
verschoben: Es sind Darstellungs- und Interaktionsprüfungen des fertigen
Produkts, und seit dem 2026-09-13 gehört genau diese Klasse in das gemeinsame
Gate am Ende statt in das Gate einer einzelnen Phase. Ein Kästchen, das Prüfung
behauptet, bekommen sie damit nicht — sie stehen dort als Punkte.

Die vierte Zeile der Tabelle, die Wiedereinstreuung, ist durch die fehlende
Schnittstelle strukturell dicht und bleibt abgehakt.

**Korrigiert am 2026-09-21:** Die erste Fassung von §13.12 behauptete, die
Reihenfolge sei „über `SessionSpeechState` als Sequenz prüfbar, ohne View". Das
Testaudit hat gezeigt, dass das nicht stimmt — `SessionSpeechState` kennt kein
Sprachausgabe-Ereignis. Eine Spezifikation, die eine Abdeckung behauptet, die es
nicht gibt, ist schlimmer als eine benannte Lücke; §13.12 sagt es jetzt richtig,
und die prüfbare Hälfte ist aus dem `body` herausgezogen und getestet.

**Nicht durch einen Unit-Test gedeckt, und benannt statt behauptet:** Die
Reihenfolge „Sprachausgabe stoppen → Kartenwechsel → automatische Aufnahme"
liegt in einem `onChange` in `LearnSessionView`, und kein Unit-Test erreicht
einen `body`. Sie ruht auf **zwei** strukturellen Zusicherungen: dem einen
Beobachter je Kartenübergang, dessen erste Anweisung `speech.stop()` ist, und
darauf, dass `startRecording(for:)` selbst mit `speech.stop()` beginnt. „Nie
Sprachausgabe und Mikrofon gleichzeitig" hängt damit nicht allein an der
Anweisungsreihenfolge im Beobachter. Der reale Beleg gehört auf die
Geräteliste.

### Abhängigkeiten

Phase 9 (Erkennungspfad, unverändert benutzt), Phase 11 (Historie und
Bewertungspfad, hier ersetzt) und Phase 12 (Sprachmodus, hier an einer Stelle
verengt).

### Ausdrücklich nicht in dieser Phase

- **Kein automatischer Downgrade** und keine negative Evidenz aus ASR, auch
  nicht aus mehreren Mismatches.
- **Keine Ersatzheuristik für Modus B** und keine für Modus A ohne Mikrofon.
  Dort bewegt sich der Lernstand nicht, und das ist die benannte Folge, keine
  Lücke ([learning-engine.md §13.11](learning-engine.md#1311-was-das-kostet)).
  Das Setzen des Lernstands in der Kartenübersicht war hier zunächst als **nicht
  gebaut** geführt; es ist am 2026-09-21 nachgezogen worden, weil es der einzige
  Weg nach unten ist — siehe § *Der offene Punkt der Phase 13*.
- **Kein Endpointing**, kein Silence-Timer, kein `SpeechDetector`-Polling.
- **Keine Kalibrierung** der Schwelle an realer Historie — sie wird durch die
  aufgezeichneten Ablehnungen erst möglich und bleibt offen.
- **Keine Tastatur-Umschaltung** und kein Lesen von `activeInputModes` (das
  wäre „required reason API" und zöge ein Privacy-Manifest nach sich, für eine
  Bequemlichkeit).
- Keine Statistiken, keine Fortschrittsanzeige, keine Streaks.
- Keine AI-Funktion — die ist Phase 14.

---

## Phase 14 — AI-Erklärung zu einer Karte

**Spezifiziert, gemessen und zugeschnitten am 2026-09-21. Noch nicht
implementiert.**

Die Phase begann mit zwei Produktfällen und endet mit einem. **Fall B — eine
kurze, deutsche Erklärung zu einer vorhandenen Karte — ist gebaut worden, weil
die Messung ihn trägt. Fall A — Bulk-Kartenentwürfe aus einer Beschreibung — ist
an der vorab festgelegten No-Go-Bedingung gescheitert** und wird nicht gebaut.
Der Befund steht unten und ist der Grund, warum diese Phase so klein ist wie sie
ist.

Das ist die Reihenfolge, die dieses Projekt seit Phase 9 hat: **erst messen, dann
behaupten.** Sie hat damals eine Produktaussage kassiert, bevor sie im Produkt
stand, und sie kassiert hier ein ganzes Feature. Die vollständige Gerätemessung
steht in
[apple-frameworks.md §12](apple-frameworks.md#12-foundationmodels--gerätemessung-vom-2026-09-21-q13-messteil),
die geklärte API-Oberfläche in
[§11](apple-frameworks.md#11-foundationmodels--geklärte-api-oberfläche-für-phase-14-2026-09-21),
Q13 ist damit geschlossen.

### Ziel

**Eine Karte erklärt sich nicht selbst.** `一点` heißt „ein bisschen", aber wann
man es benutzt, wie ein Satz damit aussieht und was daran besonders ist, steht
nirgends. Das gebündelte Wörterbuch liefert die Lesung, nicht den Gebrauch — es
führt nicht einmal Bedeutungen, nur Lesungen, Ambiguitätsmarker und Grundtöne.

Die Phase schließt diese Lücke für den Moment des Lernens und des Durchsehens:
ein kurzer Text auf Abruf, sichtbar als erzeugt gekennzeichnet, nicht
gespeichert.

**Was sie ausdrücklich nicht will:** am Lernen mitreden. Der Lernstand gehört dem
Lernenden (Phase 13), die Bewertung ist textuell und behauptet nichts (harte
Regel 7), und ein Modell, dem Apple selbst „Reasoning: Not supported"
bescheinigt, ist der letzte Kandidat für eine Einstufungsentscheidung.

### Scope

- **Fall B — Erklärung zu einer bestehenden Karte.** Bedeutung, Gebrauch,
  höchstens zwei Beispiele. Strukturiert über `@Generable`, deutsch,
  gekennzeichnet, **nicht persistiert**.
- **Zwei Einstiege, ein Sheet** (P5): Kontextmenü der Kartenliste und
  **aufgedeckte** Lernkarte.
- **Verfügbarkeits- und Fallback-UX** für die fünf Zustände aus §11.2, dazu eine
  Zustandszeile in den Einstellungen (P6).
- **Prompt-Versionierung** und die Aufzeichnung, gegen welche OS- und
  Modellversion gemessen wurde.

Das ist alles. Es gibt in dieser Phase **keinen neuen Datentyp, kein neues
Attribut, keine Migration und keinen einzigen Schreibzugriff auf den Store.**

### Ausdrücklich nicht in dieser Phase

- **Keine Bulk-Kartenentwürfe.** Gemessen gescheitert, Begründung im nächsten
  Abschnitt. Nicht „später in dieser Phase", nicht „in abgespeckter Form".
- **Keine Aussprachebewertung durch das Modell.** Harte Regel 7 gilt unverändert.
  Kein Score, kein Prozentwert, kein Ton-Feedback — auch nicht im Erklärtext.
- **Kein Einfluss auf den Lernstand.** Das Modell liest `LearningStatus` nicht
  und schreibt ihn nicht, schreibt keinen `ReviewLog`, keinen `reviewCount`,
  keinen `correctCount`. Die assistierte Einstufung aus Phase 13 bleibt
  vollständig regelbasiert und unberührt. **`CApp/Learning/` bleibt unverändert**
  — dieselbe Zusage wie in Phase 9, am Diff nachprüfbar.
- **Kein Schreibzugriff, gar keiner.** Fall B liest eine Karte und schreibt
  nichts. Kein Insert, kein Save, kein Delete.
- **Kein Tool Calling** (§11.11), **keine agentische Werkzeugkette, keine
  Websuche, kein Chatbot.**
- **Kein Pinyin aus dem Modell.** Die an 372 Fällen gemessene
  `ChineseLexicon`/`ToneSandhi`-Kette bleibt die Quelle.
- **Kein externer Dienst, kein API-Key, kein Backend, keine Private Cloud
  Compute.** `PrivateCloudComputeLanguageModel` wird nirgends importiert oder
  erwähnt (§11.8).
- **Kein Anheben des Deployment Targets.** Es bleibt iOS 26.0; §11.7 nennt den
  Preis, der sonst fällig wäre.
- **Kein Asset- oder Download-Management** (P6). Das Framework gibt es nicht her
  (§11.9), anders als Phase 9.

### Warum Fall A nicht gebaut wird — der gemessene Befund

Die Go/No-Go-Regeln standen **vor** der Messung in diesem Dokument und sind nach
ihr nicht angefasst worden. Für Fall A lauteten sie:

> **Go**, wenn in beiden Wortthemen die deutliche Mehrheit der Einträge brauchbar
> ist, die Hanzi in Han-Schrift und vereinfacht kommen und die bestehende
> Pinyin-Kette sie auflöst.
>
> **No-Go**, wenn Einträge unbrauchbar sind, ohne dass man es in der Vorschau
> erkennen kann — falsche Bedeutung bei unauffälligem Hanzi.

**Die Go-Bedingungen sind erfüllt.** 50 von 50 Hanzi kamen in Han-Schrift, die
Pinyin-Kette löste alle auf, die erbetene Anzahl wurde in allen sechs Läufen
exakt getroffen, und rund 40 der 50 Einträge sind klar brauchbar. Die Mechanik
funktioniert also — und zwei Regeln der Spezifikation haben sich an echten Daten
bewährt: Die **Dublettenprüfung** fing `火车` („Zug" und „Bahn") und `锅`/`碗`
(beide „Töpfe"), je über einen anderen Schlüssel, und das **Anzahl-Schema** setzte
sich mit exakt 10 gegen einen Prompt durch, der 100 verlangte.

**Die No-Go-Bedingung ist ebenfalls erfüllt.** Sie ist keine Zählgrenze, sondern
eine Existenzaussage, und diese Einträge existieren — vier von fünfzig:

| Entwurf | Tatsächliche Bedeutung |
| --- | --- |
| `Abbruch \| 结账` | abrechnen, die Rechnung bezahlen |
| `Speisekarte \| 菜谱` | Kochbuch, Rezept — die Speisekarte ist 菜单 |
| `Toast \| 面包` | Brot |
| `Töpfe \| 碗` | Schüssel, Schale |

**Warum das schwerer wiegt als die guten vierzig.** Diese Karten sehen richtig
aus. Das Hanzi ist korrekt geschrieben, das Pinyin löst sauber auf, das deutsche
Wort ist ein echtes deutsches Wort. Die Vorschau zeigt Deutsch, Hanzi und
Pinyin — bei allen vier ist alles davon unauffällig. Und wer eine Karte für
`结账` anlegt, kennt `结账` nicht; sonst bräuchte er sie nicht. **Der Fehler wäre
nicht abwählbar, sondern unsichtbar**, und das Ergebnis wäre falsches
Lernmaterial, das über Monate abgefragt wird.

Eine Zählung, kein Versprechen: **vier von fünfzig an einer benannten
Stichprobe.** Daraus wird keine Prozentzahl als allgemeine Qualitätsaussage
abgeleitet, und schon gar keine Beruhigung — die Stichprobe sagt nichts über den
nächsten Lauf.

**Was hier nicht passiert ist:** Die Grenze wurde nicht verschoben, nachdem die
Ergebnisse vorlagen. Es ist kein externer Dienst an die Stelle getreten, kein
Plan B, keine abgeschwächte Variante. Fall A ist gescheitert und bleibt
ungebaut.

### Die Entscheidung „auf dem Gerät oder über einen Dienst" — sie war keine Wahl

Der ursprüngliche Platzhalter führte sie als offene Frage. Sie folgt aus den
bestehenden Regeln: Harte Regel 2 verbietet Laufzeit-SDKs und Backends, harte
Regel 8 Server und Telemetrie, und ein kompilierter Schlüssel ist kein Geheimnis,
sondern eine Zeile in einer Binärdatei. `FoundationModels` ist ein
**Systemframework** und damit keine externe Dependency — dieselbe Einordnung wie
`Speech`, `Translation` und `AVFoundation`.

**Das Risiko dieser Festlegung ist in dieser Phase eingetreten**, und zwar
sichtbar: Es gab keinen Plan B für Fall A, also gibt es Fall A nicht. Das ist der
Preis des local-first-Anspruchs, und er wird hier bezahlt statt umgangen.

### Fall B — der Flow

**Zwei Einstiege, ein Sheet** (P5):

1. das **Kontextmenü der Kartenliste**, das seit Phase 13 ohnehin existiert, mit
   einem Eintrag *Erklärung anzeigen*;
2. die **aufgedeckte** Lernkarte — und nur die aufgedeckte. Bei verdeckter Karte
   wäre die Erklärung die Antwort, die gerade abgefragt wird.

Beide Male **dasselbe Sheet mit demselben temporären Text**. Nicht im Editor:
Dort wäre er eine Aussage über etwas noch nicht Gespeichertes, derselbe Grund,
aus dem das Pinyin dort an ausdrücklichen Nutzeraktionen hängt.

**Was der Einstieg aus dem Lernflow nicht anfassen darf**, und deshalb steht er
hier einzeln: Das Sheet ist ein Nachschlagen, kein Lernschritt. Es wertet nichts
aus, deckt nichts auf, schreibt keinen `ReviewLog`, bewegt keinen Zähler und
ändert die Wiedereinstreuung nicht. Nach dem Schließen ist der Sessionzustand
exakt derselbe wie vorher — inklusive eines noch offenen Einstufungsvorschlags
und der Armierung des Sprachmodus.

**Inhalt**, strukturiert statt als Textblock: eine **Bedeutung**, ein
**Gebrauch**, höchstens **zwei Beispiele** (`@Guide(.maximumCount(2))`).

**Ein Beispiel ist ein eigener `@Generable`-Typ mit zwei Feldern — `chinese` und
`german` —, kein String.** Das ist ein Messbefund, nicht Geschmack: Mit
`examples: [String]` hat das Modell in drei von fünf Fällen **Slot 1 chinesisch
und Slot 2 deutsch** gefüllt, also *ein* Beispiel als zwei Einträge
(`吃早餐` / `Frühstück essen`), und in den beiden anderen beides in einen String
gepackt (`我想吃点东西 - Ich möchte etwas essen.`). Zwei Felder machen die Absicht
für das Modell eindeutig und erlauben der Oberfläche, die Teile getrennt zu
setzen — was sie für die Sprachauszeichnung ohnehin braucht.

**Kennzeichnung, nicht verhandelbar:** Über dem Text steht, dass er automatisch
erzeugt ist und Fehler enthalten kann. Die Messung gibt dem Gewicht: Die
Erklärungen waren deutsch, knapp und ohne erfundene Grammatikregel, aber eine
enthielt kaputtes Deutsch („einen Obstsorten namens Apfel") und eine ein
erfundenes Wort („Gegenstandsfähigkeit"). Ein ungekennzeichneter Erklärtext in
einer Lern-App wäre eine Autoritätsbehauptung, die niemand gedeckt hat.

**Chinesische Anteile** laufen durch `ChineseText` — VoiceOver-Sprachauszeichnung
und Dynamic Type, wie seit Phase 10 für jeden chinesischen Text in dieser App.

**Nicht persistiert**, und das ist eine Entscheidung mit Gründen:

- Das Systemmodell **ändert sich mit OS-Updates** („as part of regular OS
  updates", §11.9). Ein gespeicherter Text wäre die Antwort eines Modells, das es
  nicht mehr gibt, ohne Kennzeichnung dieses Umstands.
- Es wäre die **zweite** Schemaerweiterung nach Phase 11 — für einen Text, den
  man einmal liest.
- Regenerierbarkeit kostet nichts: Das Sheet erzeugt beim Öffnen neu, und *Neu
  erzeugen* ist ein Knopf.

**Genau eine Modellanfrage je Nutzeraktion.** Das ist gemessen begründet, nicht
sparsam gemeint: Auf dem Gerät gelang in Folge nur die erste Anfrage je Prozess,
alle weiteren scheiterten an `rateLimited` — auch nach dreieinhalb Minuten Warten
(§12.1). Ein Sheet, das automatisch nachlädt oder beim Öffnen zwei Anfragen
stellt, läuft in genau diesen Fehler. Der Erzeugen-Knopf hängt an `isResponding`:
**Überlappung wird verhindert, nicht abgefangen** (§11.5).

### Verfügbarkeit und Fallback — die fünf Zustände

`availability` wird **bei jedem Öffnen neu** abgefragt und **nie gecacht**: Das
System kann den Zustand hinter dem Rücken der App ändern (§11.2), und dieselbe
Begründung steht seit Phase 9 für `AssetInventory.status(forModules:)`. Dazu die
Sprachprüfung über `supportsLocale(_:)` für `de_DE` **und** `zh_CN` — synchron und
kostenlos, also vor dem Anbieten.

**Gemessen und deshalb hier ausdrücklich:** `Locale.current` ist auf dem Testgerät
`en_DE`. Eine Prüfung über `Locale.current` hätte zufällig `true` ergeben und
trotzdem die falsche Frage gestellt. Es werden **beide Ziel-Locales namentlich**
geprüft.

| Zustand | Einstiegspunkt | Begründung |
| --- | --- | --- |
| `.available`, beide Locales unterstützt | sichtbar und nutzbar | gemessen der Fall auf dem Testgerät |
| `.unavailable(.deviceNotEligible)` | **ausgeblendet** | für den Nutzer nicht behebbar; ein dauerhaft toter Eintrag ist Ärger ohne Gegenwert — dieselbe Wahl wie beim Lautsprecher ohne `zh-CN`-Stimme in Phase 7 |
| eine der beiden Locales nicht unterstützt | **ausgeblendet** | ebenfalls nicht behebbar |
| `.unavailable(.appleIntelligenceNotEnabled)` | **sichtbar, deaktiviert, mit Erklärung** | behebbar in den iOS-Einstellungen; Ausblenden würde eine einschaltbare Funktion verschweigen |
| `.unavailable(.modelNotReady)` | **sichtbar, deaktiviert, mit Erklärung** | vorübergehend; beim nächsten Öffnen neu geprüft |

Dazu **eine Zeile in den Einstellungen** (P6), die den aktuellen Zustand **samt
verständlichem Grund** nennt. Sie ist der Grund, warum ein Ausblenden erklärbar
bleibt. **Kein Asset- oder Download-Management, kein Fortschritt** — das
Framework gibt es nicht her (§11.9).

**Fehler während der Erzeugung** bleiben im Sheet: eine Meldung, ein erneuter
Versuch, und nichts geschrieben. Die relevanten `GenerationError`-Fälle gehen
über `AppError` in die Fehlermatrix in
[architecture.md §7](architecture.md#7-fehlerbehandlung); `debugDescription` wird
**nie** nutzersichtbar. `rateLimited` braucht dabei einen echten Pfad und keine
Fußnote — es ist gemessen aufgetreten, im Vordergrund (§11.6).

### Modelloutput ist keine Datenbankmutation — in dieser Phase trivial erfüllt

Der ursprüngliche Entwurf brauchte dafür sechs Nähte, weil Fall A Karten anlegte.
Nach dem Zuschnitt bleibt die stärkste Form der Zusage:

1. **Diese Phase schreibt überhaupt nicht.** Kein Insert, kein Save, kein Delete,
   kein `ModelContext`-Zugriff außer dem Lesen der einen Karte, die erklärt wird.
2. **Das Modell liefert ausschließlich Wertetypen.** Die `@Generable`-Structs sind
   keine `@Model`-Typen; sie *können* nicht eingefügt werden. Der Compiler trägt
   diese Grenze, nicht die Disziplin.
3. **Kein Tool Calling.** `tools:` bleibt leer — es wäre der einzige Weg, auf dem
   das Modell selbst schreiben könnte.
4. **Karte, `ReviewLog` und `LearningStatus` bleiben unberührt**, auch beim
   Einstieg aus einer laufenden Session.
5. **Ein Fehler lässt den Store unverändert** — was hier folgt, weil nie etwas
   geschrieben wird, und was trotzdem geprüft wird.

### Prompt-Versionierung

Die Instructions liegen als benannte Konstanten in **einer** Datei,
`CApp/Services/AIPrompts.swift`, zusammen mit einem `promptRevision: Int`.

**Wer eine Instruction ändert, erhöht `promptRevision` und trägt eine neue
Messzeile in [apple-frameworks.md §12](apple-frameworks.md#12-foundationmodels--gerätemessung-vom-2026-09-21-q13-messteil)
ein** — mit Datum, Gerät, OS-Version und dem, was sich am Ergebnis geändert hat.

Warum überhaupt eine Version, wenn nichts persistiert wird: Weil die
Messergebnisse sonst an nichts hängen. Apple nennt selbst drei Modellversionen
mit unterschiedlichem Verhalten (26.0–26.3, 26.4, 27.0). Eine Messung ohne
Angabe, welcher Prompt sie erzeugt hat, ist eine Anekdote. Warum ein `Int` und
kein Vorlagensystem: Es ist **eine** Instruction in einer privaten App.

**Die Instruction nagelt die Antwortsprache fest** und enthält Apples exakte
Phrase `The person's locale is de_DE.` (§11.3). Gemessen wirksam: Ein Prompt, der
ausdrücklich Suaheli verlangte, hat die festgelegte Sprache **nicht** umbiegen
können (§12.6).

### Architektur

Keine neue Schicht, kein Container, keine Protokolle. Vier neue Dateien und drei
Ergänzungen:

| Datei | Inhalt |
| --- | --- |
| `Services/AIPrompts.swift` | die Instruction und `promptRevision` |
| `Services/AIAvailability.swift` | **reine** Abbildung aus `availability` plus beiden `supportsLocale`-Prüfungen auf die fünf UI-Zustände — testbar ohne Modell |
| `Services/CardExplanationGenerator.swift` | die `@Generable`-Typen und die eine `async`-Funktion; erzeugt und verwirft die Session |
| `Features/Cards/CardExplanationSheet.swift` | das Sheet, für beide Einstiege dasselbe |
| `Features/Cards/CardListView.swift` (Ergänzung) | Kontextmenü-Eintrag |
| `Features/Learn/…` (Ergänzung) | Einstieg auf der aufgedeckten Karte |
| `Support/AppError.swift` (Ergänzung) | Fälle für die Generierung |
| `Features/Settings/…` (Ergänzung) | die Zustandszeile |

Zwei bewusste Nicht-Entscheidungen:

- **Kein `AIService` in der Environment.** `SpeechSynthesisService` muss eine
  Instanz halten, weil `AVSpeechSynthesizer` es verlangt. Hier gilt das
  Gegenteil: Sessions sind Einwegware (§11.5), und `SystemLanguageModel.default`
  ist bereits eine geteilte, `Observable` Instanz, die Apples eigenes Beispiel
  direkt in der View hält. Ein Service, der nichts hält, wäre eine Schicht um des
  Symmetriegefühls willen.
- **Kein gemeinsamer Obertyp** für Generator und Verfügbarkeitsprüfung. Sie
  teilen nichts außer dem Framework.

`CApp/Learning/` wird **nicht angefasst**.

### Tasks

| # | Task | Abhängig von |
| --- | --- | --- |
| 14.0 | ~~Messung am Gerät~~ **erledigt am 2026-09-21**, Ergebnis in [§12](apple-frameworks.md#12-foundationmodels--gerätemessung-vom-2026-09-21-q13-messteil), Q13 geschlossen, Spike entfernt | — |
| 14.1 | `AIPrompts` und `AIAvailability` — **mit Tests, vor jeder Oberfläche** | — |
| 14.2 | Zustandszeile in den Einstellungen | 14.1 |
| 14.3 | `CardExplanationGenerator` samt `@Generable`-Typen (Beispiel = zwei Felder) | 14.1 |
| 14.4 | `CardExplanationSheet`, Einstieg über das Kontextmenü der Kartenliste | 14.3 |
| 14.5 | Einstieg über die **aufgedeckte** Lernkarte, ohne Eingriff in den Sessionzustand | 14.4 |
| 14.6 | `AppError`-Fälle und Fehlermatrix in [architecture.md §7](architecture.md#7-fehlerbehandlung) | 14.4, 14.5 |
| 14.7 | Entscheidungen in [architecture.md §10](architecture.md#10-zusammenfassung-der-architekturentscheidungen) eintragen | 14.6 |
| 14.8 | Review, Testaudit, Gegenmutationen | alle |

**14.1 kommt vor allem anderen.** `AIAvailability` ist der einzige Teil dieser
Phase, der ohne Modell vollständig prüfbar ist — genau wie `LearnFlow` in
Phase 13 zuerst kam.

### Akzeptanzkriterien

**Messung und Abschluss des Messteils**

- [x] Alle elf Messblöcke sind auf dem iPhone 16 Pro (iOS 27.0, Build 24A437)
      gelaufen; die Ergebnisse stehen mit Gerät, OS-Version und Datum in §12.
- [x] `supportsLocale` für `de_DE` und `zh_CN` ist **gemessen** protokolliert,
      nicht aus Apples Sprachliste geschlossen.
- [x] Die fachliche Bewertung steht als **Zählung an einer benannten Stichprobe**
      im Dokument; **keine Prozentzahl als allgemeines Qualitätsversprechen** —
      nicht im Dokument, nicht in der App, nicht in einem Hinweistext.
- [x] Das Go/No-Go ist je Fall dokumentiert und **nach** der Messung nicht
      verändert worden.
- [x] Fall A ist als blockiert dokumentiert, mit den vier Belegfällen.
- [x] Die Spike-Datei ist entfernt.

**Fall B**

- [ ] Der Eintrag steht im Kontextmenü der Kartenliste **und** auf der
      **aufgedeckten** Lernkarte; bei verdeckter Karte gibt es ihn nicht.
- [ ] Beide Einstiege zeigen **dasselbe** Sheet.
- [ ] Der Einstieg aus dem Lernflow lässt den Sessionzustand unverändert: kein
      `ReviewLog`, kein Zähler, keine Wiedereinstreuung, ein offener
      Einstufungsvorschlag bleibt offen, der Sprachmodus bleibt wie er war —
      durch einen Test belegt.
- [ ] Ein Beispiel ist ein `@Generable`-Typ mit `chinese` und `german`;
      `[String]` kommt nicht vor.
- [ ] Höchstens zwei Beispiele, und die Grenze steht im Schema
      (`@Guide(.maximumCount(2))`).
- [ ] Die Erklärung ist sichtbar als automatisch erzeugt gekennzeichnet und als
      möglicherweise fehlerhaft.
- [ ] Chinesische Anteile laufen durch `ChineseText`.
- [ ] Der Text wird **nicht persistiert**: keine Schemaänderung, kein neues
      Attribut, und nach dem Schließen ist er weg.
- [ ] *Neu erzeugen* funktioniert und schreibt ebenfalls nichts.
- [ ] **Eine** Modellanfrage je Nutzeraktion; kein automatisches Nachladen, kein
      zweiter Aufruf beim Öffnen.
- [ ] Der Erzeugen-Knopf ist an `isResponding` gebunden; zwei gleichzeitige
      Anfragen sind **nicht möglich**.

**Verfügbarkeit, Sicherheit, Regeln**

- [ ] Die fünf Zustände der Tabelle sind umgesetzt; `availability` wird bei jedem
      Öffnen neu abgefragt und **nirgends gecacht**.
- [ ] Geprüft werden `de_DE` und `zh_CN` **namentlich**, nicht `Locale.current`.
- [ ] Die Einstellungen nennen den Zustand **samt verständlichem Grund**; es gibt
      **kein** Asset- oder Download-Management.
- [ ] `rateLimited` hat einen nutzersichtbaren Pfad, der nichts kaputt macht.
- [ ] `debugDescription` eines `GenerationError` erscheint **nie** in der
      Oberfläche.
- [ ] Die Instruction nagelt die Antwortsprache fest und enthält Apples exakte
      Locale-Phrase — durch einen Test belegt.
- [ ] `promptRevision` existiert, und die Messzeile im Dokument nennt sie.
- [ ] `tools:` wird nirgends gesetzt.
- [ ] `PrivateCloudComputeLanguageModel` kommt im Projekt **nicht vor** — durch
      eine Suche über das Repository belegt.
- [ ] Kein neuer Info.plist-Schlüssel, kein Entitlement, kein API-Key, keine
      Netzwerkanfrage der App.
- [ ] Die Phase führt **keinen einzigen Schreibzugriff** auf den Store ein —
      durch einen Test belegt, der Kartenzahl und Inhalte vor und nach einer
      Erklärung vergleicht.
- [ ] **`CApp/Learning/` ist unverändert** — am Diff nachprüfbar.
- [ ] Kein Pfad ändert `Card`, `LearningStatus`, `reviewCount`, `correctCount`
      oder schreibt einen `ReviewLog`.
- [ ] Nirgends eine Aussprachebewertung, ein Score, ein Prozentwert oder eine
      Konfidenz — auch nicht im Erklärtext.
- [ ] Keine Bulk-Kartenerstellung, auch nicht in abgespeckter Form.
- [ ] Deployment Target unverändert **iOS 26.0**; `project.pbxproj` unberührt.
- [ ] Build und Tests grün, **null Compilerwarnungen** auf einem Debug- und einem
      Release-Build von null.

### Die sechs Produktentscheidungen vom 2026-09-21

Alle sechs sind getroffen. **Vier davon betreffen den blockierten Fall A und
werden in Phase 14 nicht umgesetzt** — sie stehen hier, weil eine getroffene
Entscheidung nicht verloren gehen soll, nicht weil etwas davon gebaut wird.

| # | Entschieden | Gilt für |
| --- | --- | --- |
| **P1** | 5 bis 15 Karten je Bulk-Lauf, Standard 10 | **Fall A — blockiert, nicht implementiert** |
| **P2** | Vorschau inline editierbar für Deutsch und Hanzi, dazu an-/abwählen und löschen; kein vollständiger `CardEditor` je Entwurf | **Fall A — blockiert, nicht implementiert** |
| **P3** | Exakte Deutsch-und-Hanzi-Dublette vorab abgewählt und markiert, bewusst wieder aktivierbar; Teildubletten nur markiert | **Fall A — blockiert, nicht implementiert** |
| **P4** | Eine optionale Kategorie für die gesamte Generierungsrunde; keine Kategorienverwaltung je Entwurf | **Fall A — blockiert, nicht implementiert** |
| **P5** | Dieselbe temporäre Erklärung aus der Kartenliste **und** von einer aufgedeckten Lernkarte, nicht persistiert | **Fall B — Scope dieser Phase** |
| **P6** | Einstellungen zeigen den On-Device-Verfügbarkeitsstatus samt verständlichem Grund; kein Asset-/Download-Management | **Fall B — Scope dieser Phase** |

**P5 hat meinen eigenen Vorschlag umgekehrt**, und das ist vermerkt, damit die
Begründung nicht später als meine gelesen wird: Ich hatte den Lernflow
ausgeschlossen, weil Phase 13 dort gerade Prosa abgebaut hat. Die Entscheidung
lautet anders und ist eng gezogen — nur bei aufgedeckter Karte, wo nichts mehr zu
verraten ist, und als dasselbe temporäre Sheet ohne eigenen Zustand.

Die Entscheidung **on-device statt Dienst** stand nie zur Wahl; sie folgt aus den
harten Regeln 2 und 8.

### Was ein späterer Anlauf auf Fall A bräuchte

**Nicht in dieser Phase, und nicht als Variante davon.** Der Vollständigkeit
halber, weil die No-Go-Begründung selbst darauf zeigt: Sie lautet „keine
Oberfläche kann ihn auffangen", und das ist für die spezifizierte Oberfläche
gemessen wahr — Deutsch, Hanzi und Pinyin sind in allen vier Fehlerfällen
unauffällig. Eine **unabhängige Bedeutungsquelle** neben dem Modellvorschlag
würde genau diese Fälle sichtbar machen; `菜谱 → recipe; cookbook` neben
„Speisekarte" fällt sofort auf.

Das wäre ein **anderer Ansatz und eine eigene Phase**: Das gebündelte Asset führt
heute keine Bedeutungen, die CC-CEDICT-Quelle hat englische Definitionen, und die
Rohquelle liegt nicht im Repository. Er müsste neu spezifiziert und **neu
gemessen** werden, gegen neu festgelegte Kriterien. Der Eintrag steht im
[Backlog](#backlog-ausdrücklich-nicht-im-mvp).

---

## Finale Geräte- und Release-Abnahme

**Kein Feature und keine Produktphase, sondern das abschließende Gate der
gesamten Roadmap.** Hier wird nicht entwickelt; hier wird das fertige Produkt
auf dem echten Gerät geprüft und abgenommen.

**Warum es diesen Abschnitt gibt.** Bis zum 2026-09-13 hatte jede Phase ihre
eigene Geräteprüfung, und der mehrtägige Alltagstest hing an Phase 10. Das
führt nach Phase 11 und 12 zu einer Dokumentation, die sich selbst
widerspricht: „Phase 12 implementiert, Phase-10-Gerätetest noch offen". Die
Phasen danach verändern das Produkt real — Phase 11 bringt die erste
Schemaänderung überhaupt, Phase 12 greift in den Audio-Lebenszyklus ein —,
also wäre ein Stabilitätsbeleg für einen Zwischenstand am Ende wertlos. Die
vollständige Prüfung wandert deshalb ans Ende, wo sie das misst, was
ausgeliefert wird.

**Verhältnis zu den Gerätetests aus den Phasen.** Die bisherigen physischen
Tests — Phase 3+4, 4.5, 6, 6.5, 7, 8, 9 und die beiden aus Phase 10 — bleiben
vollständig dokumentiert und gültig. Sie sind **Entwicklungs-/Zwischentests**:
Sie belegen namentlich genannte Pfade auf dem jeweiligen Stand. Sie sind nicht
die Abnahme des fertigen Produkts und waren es rückblickend auch nie.

**Voraussetzung:** alle Implementierungsphasen abgeschlossen, verifiziert und
auf `main` committet — **einschließlich der Phasen 13 und 14**. Am 2026-09-21
ist dieses Gate ein zweites Mal nach hinten gerückt, aus demselben Grund wie
beim ersten Mal: Phase 13 baut den Bedienfluss der Lernkarte um und ändert das
Schema, und Phase 14 ist im Umfang noch offen. Die Begründung steht oben in der
Einleitung; die bisherigen Gerätetests bleiben als Entwicklungsbelege
unverändert dokumentiert.

### Vorbereitung

- [ ] `main` ist final verifiziert: gesamte Testsuite grün, Debug-Build von
      null, Release-Build von null, 0 Compilerwarnungen
- [ ] Der Build für die Abnahme wird **aus diesem `main`** erzeugt und auf dem
      primären iPhone installiert
- [ ] Ab hier keine Codeänderung mehr, bis die Abnahme durch ist

### 1. Vollständiger Regressionstest auf dem primären iPhone

- [ ] App-Start, App-Icon, Launch-Screen
- [ ] Karten anlegen, bearbeiten, löschen
- [ ] Kategorien anlegen, umbenennen, löschen, zuordnen
- [ ] Suche, Filter, Sortierung
- [ ] beide Lernrichtungen (Deutsch → Chinesisch, Audio → Deutsch)
- [ ] Session- und Batch-Verhalten, Wiedereinstreuung, Statusübergänge
- [ ] Einstellungen und ihre Persistenz über einen Neustart
- [ ] Sprachausgabe (TTS)
- [ ] Spracherkennung
- [ ] Verwaltung der Sprachmodelle
- [ ] alle Funktionen aus Phase 11
- [ ] alle Funktionen aus Phase 12
- [ ] der Lernflow aus Phase 13: Stop im Aufnahmepfad, *Aufgeben* samt
      Wiedereinstreuung, *Weiter*, *Bestätigen*, *Ablehnen* — und die
      Ablehnung, die einen App-Neustart überlebt
- [ ] die **Korrektur des Lernstands von Hand** — die drei aus Phase 13 hierher
      verschobenen Punkte (dort mit `[→]` gekennzeichnet): Long-Press auf eine
      Kartenzeile öffnet das Kontextmenü, ohne den Aufklapp-Tap oder die
      Swipe-Aktion zu beschädigen (A27); der aktuelle Stand ist markiert **und**
      wird von VoiceOver als solcher angesagt; die Auswahl schreibt **ohne
      Bestätigungsdialog**; bei aktivem Statusfilter verschwindet die Zeile
      danach aus der Liste, was gewollt ist
- [ ] die **Animation im Aufnahmepfad** (ebenfalls aus Phase 13 verschoben):
      `[ Antwort sprechen ]` → `[ Fertig ][ ■ ]` ist **eine** Bewegung — der
      breite Knopf schrumpft nach rechts auf die Stop-Fläche, *Fertig* erscheint
      links, und die Zeile darunter bewegt sich **nicht** mit
- [ ] ein **Vorschlag, der während einer laufenden Session von Hand überholt
      wird**: Karte aufgedeckt stehen lassen, im Karten-Tab denselben Lernstand
      ändern, zurückwechseln — das Angebot muss verschwunden sein, nicht die
      Korrektur zurücknehmen
- [ ] alle Funktionen aus Phase 14, sobald deren Umfang entschieden ist

### 2. Persistenz und Migration

Der kritischste Punkt der ganzen Abnahme, weil er als einziger Daten des
Nutzers vernichten kann.

- [ ] Einen **real bestehenden privaten Store** mit dem finalen Schema öffnen
      — kein frisch angelegter, kein Simulator-Store
- [ ] Keine bestehenden Karten, Kategorien oder Lernstände gehen verloren
- [ ] Alle bis dahin hinzugekommenen Modelle und Migrationen prüfen,
      insbesondere `ReviewLog` aus Phase 11 mit seiner Beziehung zu `Card` und
      die in Phase 13 ergänzten Properties: `suggestedStatusRaw` und
      `suggestionDecisionRaw` auf `ReviewLog` und
      `classificationEvidenceResetAt` auf `Card` — die erste neue Property auf
      `Card` überhaupt
- [ ] Damit ist auch **Q7** fällig
      ([apple-frameworks.md §10](apple-frameworks.md#10-offene-technische-fragen-zu-klären-vor-der-jeweiligen-phase)):
      ob die automatische SwiftData-Migration reicht, entscheidet sich hier
      und nirgends sonst

### 3. Offline

Nach einmalig installierten Assets, im Flugmodus:

- [ ] Kartenverwaltung
- [ ] Pinyin-Erzeugung
- [ ] Lernmodus, beide Richtungen
- [ ] Sprachausgabe
- [ ] Spracherkennung
- [ ] **AI-Funktionen aus Phase 14, falls gebaut** — Apples „Works offline ✅"
      ist zitiert, nicht gemessen; hier wird es im eigenen Haus geprüft
      ([apple-frameworks.md §11.8](apple-frameworks.md#118-privatsphäre-der-cloud-pfad-ist-ein-anderer-typ-dreifach-verriegelt))
- [ ] alle sonstigen als offline deklarierten Funktionen

### 4. Accessibility und Darstellung

- [ ] Dynamic Type bis zu den Accessibility-Größen
- [ ] VoiceOver, einschließlich der chinesischen Sprachauszeichnung
- [ ] Dark Mode
- [ ] lange chinesische Sätze (Umbruch, Abschneiden, Lesbarkeit)
- [ ] alle final hinzugekommenen Screens

### 5. Performance

- [ ] mehrere hundert Karten im realen Bestand
- [ ] Suche
- [ ] Filter
- [ ] Session-Start
- [ ] Review-History und die übrige Phase-11-Logik, soweit sie mit dem
      Bestand wächst

### 6. Audio- und Speech-Lebenszyklus

Die Fehlerklasse, die in den Phasen 7 und 9 die meisten Gerätebefunde
erzeugt hat.

- [ ] Erkennung → Sprachausgabe unmittelbar danach
- [ ] Sprachausgabe → Erkennung unmittelbar danach
- [ ] Kartenwechsel während laufender Sprachausgabe oder Aufnahme
- [ ] Wechsel in den Hintergrund und zurück
- [ ] Unterbrechungen (Anruf, andere App, Stummschalter, Kopfhörer)
- [ ] alle Freihand-Pfade aus Phase 12, falls implementiert

### 7. Mehrtägiger Alltagstest

Der **unveränderte** Release-Kandidat wird mehrere Tage real benutzt.

- [ ] keine Abstürze
- [ ] kein Datenverlust
- [ ] keine festhängenden Audio- oder Spracherkennungszustände
- [ ] keine dauerhaft falschen UI- oder Modellzustände
- [ ] persistierte Einstellungen bleiben korrekt
- [ ] die Kernlernabläufe werden real benutzt, nicht nur angetippt

**Regel für Änderungen währenddessen:** Jede Änderung am **Laufzeitverhalten**
startet diesen Alltagstest **neu** — Produktivcode, Assets, Buildeinstellungen.
Reine Dokumentationsänderungen tun das nicht.

### Ergebnis

- [ ] **Finale Abnahme erteilt.** Erst dann gilt die Roadmap als
      abgeschlossen und das Produkt als abgenommen.

**Solange dieser Abschnitt offene Punkte hat, lautet der Projektstatus
`Finale Roadmap-Abnahme: ausstehend`** — unabhängig davon, wie viele Phasen
als implementiert gelten.

---

## Backlog (ausdrücklich nicht im MVP)

Sammelstelle für Ideen, die während der Umsetzung auftauchen. Nichts hiervon
wird vor Abschluss von Phase 10 begonnen.

**Bulk-Kartenentwürfe mit unabhängiger Bedeutungsprüfung**

**Entstanden aus dem gemessenen No-Go von Phase 14 am 2026-09-21.** Aus einer
Beschreibung („15 häufige Wörter zum Thema Restaurant") entstehen Entwürfe, die
vor der Vorschau gegen eine **unabhängige Bedeutungsquelle** geprüft werden —
naheliegend die englischen Definitionen von CC-CEDICT, die die Quelle führt und
das gebündelte Asset heute nicht.

**Warum es nicht Phase 14 ist.** Dort war der Fall gemessen gescheitert: Vier von
fünfzig Einträgen trugen eine falsche Bedeutung bei unauffälligem Hanzi
(`Abbruch|结账`, `Speisekarte|菜谱`, `Toast|面包`, `Töpfe|碗`), und die
spezifizierte Vorschau — Deutsch, Hanzi, Pinyin — kann das nicht sichtbar machen.
Die Grenze wurde nicht gelockert; der Fall wurde gestrichen.

**Was daran neu wäre, und warum es eine eigene Phase braucht:** ein erweitertes
Datenasset samt Lizenz- und Herkunftsdokumentation, eine Vergleichsschicht
zwischen deutschem Modellvorschlag und englischer Wörterbuchdefinition, und eine
Oberfläche, die eine Abweichung verständlich zeigt, ohne ein Urteil zu behaupten.
Das ist ein anderer Ansatz, nicht eine Variante — er müsste **neu spezifiziert
und neu gemessen** werden, gegen vorab festgelegte Kriterien.

**Was aus Phase 14 dafür schon belegt ist:** Die Mechanik trägt. Anzahl exakt
getroffen, 50 von 50 Hanzi in Han-Schrift, Pinyin-Kette löst alles auf, das
Anzahl-Schema setzt sich gegen einen widersprechenden Prompt durch, und die
deterministische Dublettenregel hat an echten Daten gegriffen — beide Zweige.
Die Entscheidungen P1 bis P4 aus Phase 14 gelten als getroffen und sind dort
dokumentiert.

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
- **Manuelle Vierfachbewertung als optionale Rückfallebene.** Phase 13 nimmt
  sie aus dem Lernflow; damit bewegt sich in Modus B und in Modus A ohne
  Mikrofon kein Lernstand mehr von selbst. Wieder aufnehmen, wenn sich im
  Alltagstest zeigt, dass die Kartenliste als einziger Weg nicht reicht — dann
  aber als ausdrückliche Einstellung, nicht als Rückfall in den Standardflow.
- **Kalibrierung der Einstufungsschwelle an realer Historie**, jetzt
  einschließlich der Annahmequote: Phase 13 zeichnet Ablehnungen auf, also ist
  erstmals messbar, wie oft ein Vorschlag angenommen wird
  ([learning-engine.md §13.10](learning-engine.md#1310-die-schemaänderung-zwei-felder-und-warum-genau-zwei)).
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
- **Automatisches Speech-Endpointing / kalibrierte VAD.** In Phase 12 gemessen
  und zurückgestellt (Q11): `SpeechDetector` lieferte auf iOS 26.6 keine
  Ergebnisse, `isFinal` kam 3,9–6,6 s zu spät, und eine eigene Energieregel
  wäre aus einem einzigen ruhigen Setting geraten. Wieder aufnehmen, sobald
  **entweder** eine funktionierende System-API vorliegt — etwa wenn Apple
  `SpeechDetector.speechDetected` tatsächlich befüllt — **oder** genug reale
  Messdaten aus verschiedenen Umgebungen existieren, um Schwelle, Hysterese
  und Stillezeit zu kalibrieren statt zu raten.
- Echte Aussprachebewertung inklusive Tonanalyse
- Phonetischer Ähnlichkeitsvergleich statt exaktem Textvergleich

**Eingabe**
- **Chinesische Tastatur im Hanzi-Feld.** Am 2026-09-21 gegen die
  Apple-Dokumentation geprüft (Q12): Es gibt keine setzende Input-Mode-API,
  und SwiftUI hat dafür überhaupt nichts. Dokumentiert möglich ist nur
  *Bevorzugen* pro Feld über `UIResponder.textInputMode` in einer
  UIKit-Subklasse, begrenzt auf Tastaturen, die der Nutzer selbst hinzugefügt
  hat. Falls es überhaupt kommt, in dieser Reihenfolge und nicht anders:
  (1) `textInputContextIdentifier`, damit sich das Feld die dort zuletzt
  benutzte Tastatur merkt — keine Sprachannahme, kein Erzwingen;
  (2) ein Hinweis, wenn keine chinesische Tastatur aktiv ist — braucht
  `activeInputModes`, also ein Privacy-Manifest; (3) der
  `textInputMode`-Override zuletzt und nur mit einem Messwert dafür, was eine
  chinesische Tastatur als `primaryLanguage` meldet. Erzwingen ist belegt
  unmöglich und bleibt es.

**Technik**
- iCloud-Synchronisation
- iPad-Layout
- Widgets
- Bewertung von iOS 27 als Deployment Target
