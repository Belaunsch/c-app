# Claude-Code-Entwicklungsworkflow

Wie dieses Projekt mit Claude Code entwickelt wird: welche Rollen es gibt,
wer was darf, und wann eine Phase als abgeschlossen gilt.

Leitgedanke, analog zur App-Architektur: **so wenig Struktur wie möglich, so
viel wie nötig.** Ein Subagent existiert nur dort, wo Kontextisolation oder
eine unabhängige zweite Meinung einen echten Vorteil bringt.

---

## 1. Rollen

### Hauptagent — Implementierer und Koordinator

Der Hauptkontext schreibt den produktiven Code. Er versteht die aktuelle
Roadmap-Phase, trifft Entscheidungen, die Kontext aus mehreren
Projektbereichen brauchen, führt Änderungen zusammen und reagiert auf
Nutzerfeedback.

Implementierungsarbeit wird **nicht** pauschal an einen Subagenten
delegiert. Planung, Implementierung, Test und Korrektur hängen bei einem
Projekt dieser Größe eng zusammen; sie zu trennen kostet mehr Kontext, als
die Isolation einspart.

### Skills — kodierte Arbeitsabläufe

Ein Skill ist ein wiederverwendbarer Ablauf, der im Hauptkontext läuft. Er
ersetzt das immer wieder neu formulierte „lies erst die Roadmap, dann …".

| Skill | Zweck |
| --- | --- |
| `/implement-phase` | eine Roadmap-Phase umsetzen — Preflight, Implementierung, Tests, Review, Akzeptanzprüfung |
| `/verify-phase` | eine implementierte Phase prüfen, ohne Features zu bauen; endet mit READY / NOT READY |
| `/apple-api-spike` | eine offene Apple-API-Frage (Q1–Q7) belegt klären und das Ergebnis dokumentieren |

### Subagents — isolierte Spezialaufgaben

Ein Subagent läuft in eigenem Kontext und gibt nur eine Zusammenfassung
zurück. Alle drei sind **nicht schreibberechtigt** für Produktivcode.

| Subagent | Zweck | Werkzeuge |
| --- | --- | --- |
| `apple-api-researcher` | Apple-Dokumentation recherchieren, Verfügbarkeit, Permissions und Offline-Verhalten belegen | WebFetch, WebSearch, Read, Grep, Glob, Bash |
| `code-reviewer` | abgeschlossene Phase unabhängig gegen die Projektdokumente prüfen | Read, Grep, Glob, Bash |
| `test-auditor` | Tests und Akzeptanzkriterien unabhängig prüfen, Build und Tests ausführen | Read, Grep, Glob, Bash |

Alle drei nutzen `model: inherit`, laufen also auf dem Modell der laufenden
Sitzung. Grund: Alle drei treffen Urteile, die in ein Phase-Gate einfließen —
ein schwächeres Modell würde dort falsche Sicherheit erzeugen. Bewusst
einfach gehalten und leicht änderbar.

### Rules — pfadgebundene Detailregeln

`.claude/rules/learning-layer.md` lädt nur, wenn Claude eine Datei unter
`Learning/**` liest. Dort stehen die Detailregeln dieser Schicht (nur
`Foundation`, keine Persistenzobjekte, injizierter Zufall, Pflichttests) —
Detail, das in `CLAUDE.md` nur Platz kosten würde, weil es die restlichen
90 % der Arbeit nicht betrifft.

Die zugehörige harte Regel bleibt in `CLAUDE.md`. Die Rule trägt die
Ausführung, nicht die Regel selbst.

---

## 2. Normaler Phase-Workflow

```
Roadmap Phase
    ↓
Preflight            Git-Status, CLAUDE.md, Phase, Architektur, Abhängigkeiten
    ↓
ggf. API Spike       /apple-api-spike → apple-api-researcher
    ↓
Implementation       im Hauptagenten, nur Scope dieser Phase
    ↓
Tests                schreiben, Build, Tests
    ↓
Code Reviewer        Subagent, unabhängig, ändert nichts
    ↓
Test Auditor         Subagent, führt Build und Tests aus, prüft Kriterien
    ↓
Fixes                im Hauptagenten
    ↓
Verification         /verify-phase → READY / NOT READY
    ↓
Device Check         nur der Nutzer, auf dem echten iPhone
    ↓
Commit               Hauptagent
```

Code Reviewer und Test Auditor sind voneinander unabhängig und dürfen
parallel laufen. Sie sind die einzige Parallelität in diesem Workflow.

---

## 3. Delegationsregeln

**Delegieren, wenn:**

- eine abgegrenzte Apple-API-Frage geklärt werden muss und die Recherche
  viel Ausgabe produziert, die später nicht mehr gebraucht wird
  → `apple-api-researcher`
- eine Phase fertig ist und eine unabhängige Meinung gebraucht wird, die
  den Implementierungsverlauf *nicht* gesehen hat → `code-reviewer`
- Tests und Akzeptanzkriterien systematisch abgeglichen werden müssen
  → `test-auditor`

**Nicht delegieren, wenn:**

- produktiver Code geschrieben oder geändert wird
- die Aufgabe Kontext aus mehreren Projektbereichen und der laufenden
  Diskussion braucht
- die Antwort in einer Projektdatei steht, die der Hauptagent in einem
  Lesevorgang selbst öffnen kann
- es eine einzelne, schnelle Frage ist — dann ist die Delegation teurer als
  die Antwort

**Nie:**

- zwei Agenten gleichzeitig produktive Dateien ändern lassen
- einen Subagenten Findings selbst beheben lassen, während der Hauptagent
  an denselben Dateien arbeitet

---

## 4. Git-Regel

**Der Hauptagent besitzt die Integration.** Kein Subagent committet, pusht,
wechselt Branches oder ändert Dateien. Die drei eingerichteten Subagenten
haben deshalb kein `Write` und kein `Edit`.

Vor jedem Commit liest der Hauptagent `git status` und `git diff`
vollständig. Keine History-Rewrites.

**Grenze der Absicherung, offen benannt:** Alle drei Subagenten haben `Bash`,
weil sie `git diff` lesen, Doku-JSON abrufen oder `xcodebuild` ausführen
müssen. `Bash` erlaubt technisch auch Schreibvorgänge. Die Beschränkung auf
lesende Nutzung steht als harte Regel im jeweiligen Agent-Prompt, ist aber
eine Anweisung und keine erzwungene Sperre. Für echte Erzwingung wäre ein
`PreToolUse`-Hook nötig — bewusst nicht eingerichtet, siehe §6.

---

## 4a. Eine Phase auf einmal — und die eine Ausnahme

Der Normalfall ist eine Phase pro Durchlauf, wie in `CLAUDE.md` Regel 1
festgelegt. **Einmal** wurde davon abgewichen: Die Phasen 3 (Pinyin) und 4
(Übersetzung) liefen als ein gekoppelter Meilenstein, weil Phase 4 direkt auf
Phase 3 aufbaut und der erste sinnvoll prüfbare Produktzustand die vollständige
Kette `Deutsch → Hanzi → Pinyin` ist. Ein Gerätetest, ein Commit, aber
**getrennte Akzeptanzkriterien**, die getrennt abgehakt wurden.

Die Bedingungen, unter denen so etwas wieder zulässig ist: Der Nutzer
genehmigt es ausdrücklich, die zweite Phase baut technisch unmittelbar auf der
ersten auf, und ein Test der ersten allein hätte keinen aussagekräftigen
Produktzustand ergeben. Ohne alle drei gilt Regel 1.

---

## 5. Phase-Gate

Eine Phase ist abgeschlossen, wenn **alle** Punkte zutreffen:

- [ ] Build grün
- [ ] Tests grün
- [ ] Code Review abgeschlossen, Blocker und relevante Fehler behoben
- [ ] Testaudit abgeschlossen, geforderte Tests vorhanden und aussagekräftig
- [ ] alle Akzeptanzkriterien der Phase erfüllt
- [ ] erforderliche Gerätetests auf dem echten iPhone durchgeführt
- [ ] betroffene Dokumentation aktualisiert (`apple-frameworks.md`,
      `architecture.md`, `README.md`)

Ein grüner Testlauf allein ist **kein** Phasenabschluss. Maßgeblich sind die
Akzeptanzkriterien in `docs/roadmap.md`.

Gerätetests kann nur der Nutzer durchführen. Solange welche offen sind, wird
die Phase nicht als fertig gemeldet, sondern die offenen Punkte werden
namentlich benannt.

`/verify-phase` gibt `READY` nur aus, wenn dieses Gate vollständig erfüllt
ist. **Ein ausstehender erforderlicher Gerätetest bedeutet `NOT READY`** —
auch dann, wenn es der einzige noch offene Punkt ist. Der Bericht muss dabei
erkennbar trennen, ob echte Implementierungs- oder Testprobleme bestehen oder
ausschließlich Nutzer-Gerätetests ausstehen.

---

## 6. Bewusst nicht eingerichtet

| Bestandteil | Warum nicht |
| --- | --- |
| **Agent Teams** | Laut Dokumentation experimentell und standardmäßig deaktiviert (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). Sie lohnen sich bei paralleler Exploration über mehrere unabhängige Teilbereiche und kosten deutlich mehr Tokens. Dieses Projekt hat einen sequenziellen Ablauf mit einem Implementierer und wenigen Dateien — Teammitglieder würden sich in denselben Dateien begegnen. Nicht aktiviert; es ist keine Änderung nötig, da der Standard bereits aus ist. |
| **Weitere Implementierungsagenten** (`swift-agent`, `ui-agent`, `database-agent`, `architect-agent`, `documentation-agent`, `git-agent`, `manager-agent`) | Alle würden produktiven Code in denselben Dateien ändern. Das erzeugt Konflikte statt Nutzen und nimmt dem Hauptkontext genau die Information, die er für die nächste Entscheidung braucht. |
| **Dynamic Workflows** | Für Arbeit gedacht, die über eine Handvoll Subagenten hinauswächst. Zwei Prüfagenten pro Phase sind das Gegenteil davon. |
| **Hooks** | **In Phase 0 bewertet (Task 0.9) — Entscheidung: kein Hook.** Der erwogene `PreToolUse`-Hook sollte `project.pbxproj` vor unnötiger Handbearbeitung schützen. Gemessen: Das Anlegen von `RootView.swift`, das Löschen von `ContentView.swift` und das Umbenennen der Testdatei haben **null** Änderungen an `project.pbxproj` verursacht — die synchronisierten Ordner erledigen die Datei-Mitgliedschaft vollständig. Der Hook würde also gegen ein Risiko schützen, das bereits strukturell ausgeschlossen ist. Umgekehrt gab es in derselben Phase zwei legitime Handbearbeitungen, die ein pauschaler Hook blockiert hätte: die Korrektur dreier Build-Settings (über die Xcode-UI ebenfalls möglich, aber per Datei schneller und diffbar) und das Entfernen einer verwaisten synchronisierten Gruppe, die Xcode nach dem Löschen des UI-Test-Targets zurückgelassen hatte. Ein `swift-format`-Hook entfällt ebenfalls, weil das Projekt keinen Formatierungsstandard definiert. Neu zu bewerten, falls `project.pbxproj` künftig bei reinen Dateioperationen mitwandert oder sich Handbearbeitungen daran häufen. |
| **MCP-Server** | Kein externer Dienst im Spiel. Die App hat kein Backend, keine Datenbank außerhalb des Geräts und kein Ticketsystem. Apple-Dokumentation ist über WebFetch und die Doku-JSON-API erreichbar. |
| **Plugins** | Packaging-Ebene für die Wiederverwendung über mehrere Repositories. Es gibt genau ein Repository. |
| **Eigener Test-Runner-Agent neben `test-auditor`** | Doppelte Verantwortung. `test-auditor` führt Build und Tests bereits aus. |

---

## 7. Verifizierte Mechanismen

Geprüft gegen die offizielle Claude-Code-Dokumentation am **6. September 2026**.
Nur tatsächlich unterstützte Mechanismen werden verwendet.

| Mechanismus | Ort | Verwendete Felder |
| --- | --- | --- |
| Projekt-Subagent | `.claude/agents/<name>.md` | `name`, `description` (beide Pflicht), `tools`, `model`, `color` |
| Projekt-Skill | `.claude/skills/<name>/SKILL.md` | `name`, `description`, `when_to_use`, `argument-hint` |
| Pfadgebundene Rule | `.claude/rules/<name>.md` | `paths` |
| Projektinstruktionen | `CLAUDE.md` | Zielgröße unter 200 Zeilen |

Wissenswerte Details, die die Gestaltung hier beeinflusst haben:

- Beim Subagenten ist `tools` eine **Allowlist**. Nicht genannte Werkzeuge
  stehen nicht zur Verfügung — deshalb reicht das Weglassen von `Write` und
  `Edit`, ein zusätzliches `disallowedTools` wäre redundant.
- `model: inherit` übernimmt das Modell der Hauptsitzung.
- Der **Verzeichnisname** eines Skills bestimmt den Aufruf (`/implement-phase`);
  das `name`-Feld ist nur die Anzeige in Listen.
- Skill-Beschreibungen werden zu Sitzungsbeginn geladen, der volle Inhalt
  erst beim Aufruf. Die Beschreibungen sind deshalb kurz und trennscharf
  gehalten.
- Rules **mit** `paths` laden erst, wenn Claude eine passende Datei liest;
  Rules ohne `paths` würden bei jedem Sitzungsstart laden. Genau deshalb ist
  `learning-layer.md` pfadgebunden.
- `CLAUDE.md` ist Kontext, keine erzwungene Konfiguration. Was garantiert
  gelten muss, gehört in einen Hook — siehe §4 und §6.

Quellen:
[Subagents](https://code.claude.com/docs/en/sub-agents) ·
[Skills](https://code.claude.com/docs/en/skills) ·
[Memory und Rules](https://code.claude.com/docs/en/memory) ·
[Extend Claude Code](https://code.claude.com/docs/en/features-overview) ·
[Agent Teams](https://code.claude.com/docs/en/agent-teams)
