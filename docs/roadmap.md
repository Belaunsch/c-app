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
[A27](architecture.md#anhang-entscheidungen-und-begründungen) hinterlegten
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
  eine Karte in zwei Kategorien liegt. Die **Kartenliste behält UND**; die
  beiden Bildschirme stellen verschiedene Fragen, Begründung in
  [architecture.md A26](architecture.md#anhang-entscheidungen-und-begründungen).
  Der Kartentyp bleibt außerhalb dieser Regel — Wörter und Sätze mischen sich
  nie.
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
  [A27](architecture.md#anhang-entscheidungen-und-begründungen), weil sie über
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
  [A28](architecture.md#anhang-entscheidungen-und-begründungen)/[A30](architecture.md#anhang-entscheidungen-und-begründungen)
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

### Gerätebenchmark, Voraussetzung für READY

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
