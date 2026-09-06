---
name: verify-phase
description: Prüft eine bereits implementierte Roadmap-Phase, ohne neue Features zu bauen — Git-Diff, unabhängiges Code Review, Testaudit, Akzeptanzkriterien, Scope-Creep — und liefert ein READY- oder NOT-READY-Verdict.
when_to_use: Bei Anfragen wie "ist Phase 3 fertig", "prüfe die Phase", "können wir committen", "verify" oder vor dem Abschluss-Commit einer Phase.
argument-hint: [phasennummer]
---

# Phase verifizieren

Dieser Skill **prüft**. Er implementiert keine Features und behebt keine
Findings. Ergebnis ist ein Bericht plus Verdict; die Behebung entscheidet der
Nutzer und läuft danach über `implement-phase`.

Zulässig sind ausschließlich lesende Schritte. Eine Ausnahme: offensichtliche
Dokumentationskorrekturen dürfen vorgeschlagen, aber nicht stillschweigend
vorgenommen werden.

---

## Ablauf

**1. Phase identifizieren**

Aus dem Argument, sonst aus `docs/roadmap.md` und `git log --oneline -10`
ableiten. Die Annahme benennen.

**2. Maßstab lesen**

- `docs/roadmap.md`, die betroffene Phase: Scope, Tasks,
  Akzeptanzkriterien, „Ausdrücklich nicht in dieser Phase"
- `CLAUDE.md`
- `docs/architecture.md`, betroffene Abschnitte

**3. Diff prüfen**

`git status` und `git diff` (bzw. `git diff <basis>..HEAD`, wenn die Phase
schon Commits hat). Verschaffe dir selbst einen Überblick, bevor du
delegierst — du musst die Ergebnisse der Subagenten beurteilen können.

**4. Unabhängiges Code Review**

Subagent `code-reviewer`. Mitgeben: Phasennummer und -titel, Diff-Bereich,
Hinweis auf zusätzlich relevante Spezifikationen.

**5. Testaudit**

Subagent `test-auditor`. Mitgeben: Phasennummer und -titel. Er führt Build
und Tests aus und gleicht die Akzeptanzkriterien ab.

Die Schritte 4 und 5 sind unabhängig und können parallel laufen.

**6. Ergebnisse zusammenführen**

Widersprüche zwischen den beiden Berichten nicht mitteln, sondern
auflösen: selbst nachsehen und entscheiden, was zutrifft. Ergebnisse eines
Subagenten nicht ungeprüft übernehmen — ein plausibel klingendes Finding
kann falsch sein.

**7. Akzeptanzkriterien klassifizieren**

Jedes Kriterium der Phase genau einer Kategorie zuordnen:

| Kategorie | Bedeutung |
| --- | --- |
| erfüllt | durch Test, Build oder gelesenen Code belegt |
| nicht erfüllt | mit Begründung |
| Gerätetest ausstehend | nur auf echter Hardware prüfbar — zählt **nicht** als erfüllt |

Kein Kriterium ohne Beleg als erfüllt markieren. Typische Gerätetest-Fälle:
Signing und Start auf dem iPhone, Mikrofon, verfügbare Stimmen,
Modell-Downloads, Verhalten im Flugmodus, Dynamic Type, VoiceOver.

**8. Scope-Creep identifizieren**

Alles im Diff, das die Phase nicht verlangt oder ausdrücklich ausschließt —
mit Datei und Verweis auf die Phasenbeschreibung.

**9. Blocker benennen**

Was den Phasenabschluss verhindert, in der Reihenfolge, in der es behoben
werden sollte. **Ein noch nicht durchgeführter erforderlicher Gerätetest ist
ein Blocker** — er verhindert den Phasenabschluss genauso wie ein
fehlgeschlagener Test.

Dabei aber sichtbar trennen, worum es sich handelt:

- **Echte Implementierungs- oder Testprobleme** werden einzeln aufgeführt.
- **Ausschließlich ausstehende Gerätetests** werden unter der Überschrift
  `Nur Gerätetest ausstehend:` aufgeführt, jeweils mit der konkreten
  Handlung, die der Nutzer durchführen soll.

Der Nutzer muss auf einen Blick erkennen, ob er etwas reparieren oder nur
etwas auf dem iPhone ausprobieren muss.

---

## Ausgabe

Zum Abschluss genau dieses Format, ohne Zusätze davor:

```
Phase X Verification

Build:
PASS / FAIL

Tests:
PASS / FAIL

Acceptance criteria:
x/y erfüllt
z Gerätetest ausstehend

Blocker:
<echte Probleme einzeln, sonst — falls nur Gerätetests fehlen —
"Nur Gerätetest ausstehend:" mit der konkreten Handlung je Punkt,
sonst "keine">

Scope violations:
...

Verdict:
READY / NOT READY
```

Beispiel für den Fall, dass nur noch ein Gerätetest aussteht:

```
Phase 0 Verification

Build:
PASS

Tests:
PASS

Acceptance criteria:
4/5 erfüllt
1 Gerätetest ausstehend

Blocker:
Nur Gerätetest ausstehend:
- App auf physischem iPhone starten und beide Tabs prüfen

Scope violations:
keine

Verdict:
NOT READY
```

Regeln für das Verdict:

**`READY` bedeutet: Die Phase ist vollständig abgeschlossen.** Es gilt genau
dann, wenn **alle** folgenden Punkte zutreffen:

- Build PASS
- Tests PASS
- keine Blocker
- keine Scope-Verletzungen
- alle erforderlichen Reviews abgeschlossen
- alle Akzeptanzkriterien erfüllt
- alle erforderlichen Gerätetests durchgeführt

Sonst **`NOT READY`**.

- **Ein ausstehender erforderlicher Gerätetest bedeutet `NOT READY`** — auch
  dann, wenn es der einzige noch offene Punkt ist. Ein Kriterium in der
  Kategorie „Gerätetest ausstehend" ist **nicht** erfüllt, sondern
  ungeprüft.
- Führt der Nutzer den Gerätetest durch und meldet das Ergebnis zurück, kann
  eine erneute Verifikation `READY` ergeben.
- Im Zweifel **NOT READY**. Eine zu optimistische Freigabe ist der
  teurere Fehler.

`READY` darf dem Phase-Gate in
[docs/claude-workflow.md §5](../../../docs/claude-workflow.md) nie
widersprechen. Weichen die beiden je voneinander ab, gilt das Phase-Gate und
dieser Skill wird korrigiert.

Nach der Ausgabe anhalten. Keine Fixes, keine Commits, kein Wechsel in die
nächste Phase.
