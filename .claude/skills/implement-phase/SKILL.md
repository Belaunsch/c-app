---
name: implement-phase
description: Setzt genau eine Phase aus docs/roadmap.md um — Preflight, Implementierung im Hauptkontext, Tests, unabhängiges Review, Akzeptanzprüfung. Verwenden, wenn eine Roadmap-Phase dieses iOS-Projekts implementiert oder fortgesetzt werden soll.
when_to_use: Bei Anfragen wie "lass uns Phase 2 umsetzen", "implementiere die nächste Phase", "weiter mit dem Datenmodell" oder wenn produktiver App-Code für eine Roadmap-Phase entstehen soll.
argument-hint: [phasennummer]
---

# Phase implementieren

Der **Hauptagent implementiert selbst**. Produktivcode wird nicht an einen
Subagenten delegiert — Planung, Implementierung, Test und Korrektur hängen in
diesem Projekt eng zusammen und profitieren vom gemeinsamen Kontext.
Subagenten kommen nur für Recherche und unabhängige Prüfung dazu.

Genau **eine** Phase pro Durchlauf. Nach Abschluss nicht automatisch in die
nächste Phase wechseln.

---

## Preflight

1. **Git-Status prüfen.** `git status` und `git log --oneline -5`. Bei
   unerwarteten uncommitteten Änderungen erst klären, nicht darüberbauen.
2. **`CLAUDE.md` lesen.**
3. **Die Phase vollständig lesen** in `docs/roadmap.md`: Ziel, Scope, Tasks,
   Akzeptanzkriterien, Abhängigkeiten und den Abschnitt „Ausdrücklich nicht
   in dieser Phase". Ist keine Phase genannt, aus Roadmap und `git log` die
   nächste offene ableiten und die Annahme benennen.
4. **Relevante Architekturabschnitte lesen** in `docs/architecture.md`
   (Ordnerstruktur, Datenmodell, betroffene Services, Fehlerbehandlung).
5. **Weitere Spezifikationen lesen**, falls betroffen:
   `docs/learning-engine.md` bei Lernlogik, `docs/apple-frameworks.md` bei
   Apple-APIs.
6. **Abhängigkeiten prüfen.** Sind die Vorphasen tatsächlich abgeschlossen?
   Wenn nicht, das sagen und nicht anfangen.
7. **Offene technische Fragen prüfen.** Verweist ein Task der Phase auf eine
   Frage Q1–Q7 aus `docs/apple-frameworks.md`, ist der Spike der **erste**
   Schritt — Skill `apple-api-spike`. Nicht auf Vermutungen aufbauen.

Am Ende des Preflights in zwei bis vier Sätzen zusammenfassen, was in dieser
Phase gebaut wird und was ausdrücklich nicht.

---

## Implementierung

8. **Nur den Scope dieser Phase.** Was unter „Ausdrücklich nicht in dieser
   Phase" steht, wird nicht gebaut — auch nicht teilweise, auch nicht „weil
   es gerade schnell geht".
9. **Keine Features späterer Phasen vorziehen.** Gute Ideen für später
   gehören in den Backlog-Abschnitt der Roadmap, nicht in den Code.
10. **Minimale sinnvolle Architektur.** Keine Abstraktion ohne konkreten,
    jetzt bestehenden Bedarf. Keine Repository-Layer, keine DI-Container,
    keine Coordinator, kein Drittanbieter-State-Management, keine externen
    Dependencies.
11. **Bestehende Entscheidungen respektieren.** Die Tabelle A1–A10 in
    `docs/architecture.md` §10 ist verbindlich. Hältst du eine Entscheidung
    für falsch, sag es und schlage eine Änderung vor — ändere sie nicht
    beiläufig im Code.
12. **Im Hauptkontext implementieren.**

### Wenn eine Apple-API-Frage auftaucht

Nicht aus Erinnerung raten. Entweder Skill `apple-api-spike` (wenn es eine
Q-Frage aus `docs/apple-frameworks.md` ist) oder den Subagenten
`apple-api-researcher` für eine abgegrenzte Einzelfrage. Ergebnis mit Quelle
in `docs/apple-frameworks.md` festhalten.

---

## Nach der Implementierung

13. **Tests schreiben oder aktualisieren.** Pflicht für alles unter
    `Learning/` und für `PinyinService`. Bei Learning-Code sind die
    Testfälle in `docs/learning-engine.md` §10 einzeln vorgegeben.
14. **Build ausführen.**
15. **Tests ausführen.** Fehlschläge werden behoben, nicht umgangen.
16. **Unabhängiges Review** über den Subagenten `code-reviewer`. Ihm die
    Phasennummer und den zu prüfenden Diff-Bereich mitgeben.
17. **Findings beheben.** Blocker und relevante Fehler zwingend, kleinere
    Verbesserungen nach Abwägung. Ein Finding, das dem Projekt
    widerspricht (etwa der Wunsch nach zusätzlichen Abstraktionen), wird
    begründet abgelehnt statt umgesetzt.
18. **Build und Tests erneut ausführen.**
19. **Akzeptanzkriterien einzeln prüfen.** Jedes Kriterium der Phase
    einzeln als erfüllt, nicht erfüllt oder Gerätetest-ausstehend
    klassifizieren, mit Beleg. Für eine gründliche Prüfung inklusive
    Testaudit den Skill `verify-phase` verwenden.
20. **Dokumentation aktualisieren**, wenn sich etwas Belegtes geändert hat:
    Spike-Ergebnisse in `docs/apple-frameworks.md`, tatsächlich getroffene
    Abweichungen in `docs/architecture.md`, Status in `README.md`.
    Dokumentation nicht der Roadmap anpassen, um Abweichungen zu
    verschleiern — Abweichungen benennen.
21. **`git status` und `git diff` vollständig lesen**, bevor committet wird.

---

## Phase-Gate

Ein grüner Testlauf allein schließt keine Phase ab. Maßgeblich sind die
Akzeptanzkriterien der Roadmap.

Abgeschlossen ist eine Phase erst, wenn Build grün ist, Tests grün sind, das
Review abgeschlossen und die Findings behandelt sind, alle
Akzeptanzkriterien erfüllt sind, die erforderlichen Gerätetests durchgeführt
wurden und die Dokumentation dem Stand entspricht.

Gerätetests kann nur der Nutzer durchführen. Benenne am Ende ausdrücklich,
welche Kriterien noch einen Test auf dem iPhone brauchen, und behaupte nicht,
die Phase sei fertig, solange diese offen sind.

Danach anhalten. Die nächste Phase beginnt erst auf ausdrückliche Ansage.
