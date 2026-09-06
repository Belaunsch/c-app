# Learning Engine — Spezifikation

Diese Datei spezifiziert die Lernlogik so genau, dass sie in Phase 5 direkt
implementiert und getestet werden kann. Sie ist die verbindliche Referenz für
Gewichtung, Kartenauswahl, Wiedereinstreuung und Statusübergänge.

Alle Zahlenwerte sind als benannte Konstanten an einer Stelle definiert und
bewusst leicht änderbar (siehe [§8](#8-parameter)).

---

## 1. Ziele und Nicht-Ziele

**Ziele**

- Die Session fühlt sich für den Nutzer unbegrenzt an.
- Intern wird in kleinen Gruppen von ~7 unterschiedlichen Karten gearbeitet.
- Karten mit höherem Lernbedarf kommen häufiger dran, aber nicht ausschließlich.
- Eine nicht gewusste Karte kommt **innerhalb derselben Session** wieder —
  aber erst nach mehreren anderen Karten, nie unmittelbar danach.
- Der Kern ist verständlich und deterministisch testbar.

**Nicht-Ziele (bewusst)**

- Kein Spaced-Repetition-Scheduling mit Intervallen und Fälligkeitsdaten
  (vorbereitet, aber nicht im MVP).
- Keine Vermischung von Wörtern und Sätzen in einer Session.
- Keine Streaks, Herzen, Zeitlimits oder Tageslimits.
- Keine adaptive Schwierigkeitsschätzung, kein Lernmodell pro Nutzer.

---

## 2. Begriffe

| Begriff | Bedeutung |
| --- | --- |
| **Pool** | Alle Karten, die zur Session-Konfiguration passen (Kartentyp, optional Tag-Filter). Wird einmal beim Sessionstart gebildet. |
| **Mini-Batch** | Eine Gruppe von standardmäßig 7 **unterschiedlichen** Karten aus dem Pool. |
| **Queue** | Die Abfragereihenfolge innerhalb des aktuellen Mini-Batches. Verändert sich durch Wiedereinstreuung. |
| **Aufgelöst** | Eine Karte gilt als aufgelöst, wenn sie im aktuellen Mini-Batch mit *Schwer*, *Gut* oder *Sicher* bewertet wurde. Sie verlässt damit den Batch. |
| **Session** | Folge beliebig vieler Mini-Batches, bis der Nutzer beendet. |

Ablauf auf oberster Ebene:

```
Session starten
  └─ Pool bilden (Typ + Tags)
     └─ Mini-Batch auswählen (7 Karten, gewichtet, ohne Zurücklegen)
        └─ Queue mischen
           └─ Karte zeigen → aufdecken → Selbsteinschätzung
              ├─ "Nochmal" → Karte nach ≥3 anderen Karten erneut einreihen
              └─ sonst    → Karte aufgelöst, verlässt den Batch
        └─ alle 7 aufgelöst → nächsten Mini-Batch auswählen (endlos)
```

---

## 3. Gewichtung

### 3.1 Basisgewicht aus dem Lernstatus

| Lernstatus | Basisgewicht |
| --- | --- |
| Neu | 5.0 |
| Schwach | 5.0 |
| Mittel | 3.0 |
| Gut | 1.0 |
| Sicher | 0.3 |

Das Gewicht wird **nicht persistiert**, sondern jedes Mal aus dem Status
berechnet (siehe [architecture.md](architecture.md#persistiert-vs-abgeleitet)).

Wichtig: „Sicher“ hat bewusst ein Gewicht > 0. Eine sichere Karte soll selten,
aber eben doch wieder erscheinen.

### 3.2 Recency-Faktor

Um zu verhindern, dass dieselbe Karte in zwei aufeinanderfolgenden Mini-Batches
erscheint:

```
effektivesGewicht = basisGewicht × (imVorherigenBatchAufgelöst ? 0.2 : 1.0)
```

Ausnahme: Ist der Pool kleiner als `2 × batchSize`, entfällt der Recency-Faktor
vollständig — sonst würde die Auswahl bei kleinen Kartenbeständen künstlich
verzerrt oder blockiert.

Es wird nur der **unmittelbar vorherige** Mini-Batch berücksichtigt, keine
längere Historie. Das reicht für den gewünschten Effekt und bleibt trivial
testbar.

---

## 4. Auswahl des Mini-Batches

Anforderung: `batchSize` **unterschiedliche** Karten, gewichtet, ohne
Zurücklegen. Naives wiederholtes Ziehen mit Zurücklegen erfüllt das nicht.

Verwendet wird gewichtetes Ziehen ohne Zurücklegen nach **Efraimidis–Spirakis**
(A-Res). Das ist ein Einzeiler pro Karte, exakt korrekt und in einem
Durchlauf erledigt:

```
für jede Karte c im Pool:
    w = effektivesGewicht(c)
    u = zufälligeZahl in (0, 1)          // aus dem injizierten RNG
    key(c) = -ln(u) / w                   // kleiner Key = höhere Chance

sortiere Pool aufsteigend nach key
nimm die ersten min(batchSize, poolGröße) Karten
```

Eigenschaften:

- Eine Karte kann pro Batch nur einmal gezogen werden — Unterschiedlichkeit
  ist strukturell garantiert, nicht nachträglich gefiltert.
- Die Auswahlwahrscheinlichkeit ist proportional zum Gewicht.
- Ein Gewicht von 0 wird nicht vorkommen (Minimum 0.3); zur Sicherheit wird
  `w <= 0` auf einen sehr großen Key abgebildet statt eine Division durch
  null zu erzeugen.
- Mit einem festen RNG-Seed ist das Ergebnis reproduzierbar → direkt testbar.

Die Engine bekommt den Zufallsgenerator hereingereicht
(`inout some RandomNumberGenerator`), sie erzeugt ihn nicht selbst.

### Reihenfolge innerhalb des Batches

Nach der Auswahl wird die Reihenfolge **gleichverteilt gemischt** (Fisher-Yates
mit demselben injizierten RNG). Die Gewichtung steuert *ob* eine Karte im Batch
ist, nicht *wo* sie darin steht.

---

## 5. Queue und Wiedereinstreuung

Die Queue ist eine Liste von Karten-IDs mit einem Index `i` auf die aktuelle
Karte.

Einheitliche Regel: **Bei jeder Selbsteinschätzung wird die aktuelle Karte aus
der Queue entfernt.** Dadurch rückt die nächste Karte automatisch auf Index `i`
nach; der Index muss nicht fortgeschaltet werden. Bei „Nochmal“ wird die Karte
anschließend wieder eingefügt:

```
queue.remove(at: i)                       // aktuelle Karte entfernen

falls antwort == "Nochmal" und reinserts[karte] < maxReinserts:
    neuePosition = i + reinsertGap        // reinsertGap = 3
    falls neuePosition >= queue.count:
        queue.append(karte)               // ans Ende
    sonst:
        queue.insert(karte, at: neuePosition)
    reinserts[karte] += 1
```

Beispiel mit `queue = [A, C, F, B, D]` und `i = 0`, A wird mit „Nochmal“
bewertet:

```
entfernen  → [C, F, B, D]
einfügen an Position 0 + 3 → [C, F, B, A, D]
```

Damit liegen genau `reinsertGap` andere Karten (C, F, B) vor der Wiederholung:

```
A falsch → C → F → B → A erneut
```

und nicht:

```
A falsch → A erneut
```

Sind nach dem Entfernen weniger als `reinsertGap` Karten übrig, wird ans Ende
angehängt — die Karte kommt dann so spät wie im Batch noch möglich.

**Obergrenze:** Eine Karte darf pro Mini-Batch höchstens `maxReinserts` (= 3)
mal wieder eingereiht werden. Danach gilt sie als aufgelöst und verlässt den
Batch. Ohne diese Grenze könnte ein Batch nie enden.

Bei **„Schwer“, „Gut“, „Sicher“** wird die Karte aus der Queue entfernt und
gilt als aufgelöst.

Ein Mini-Batch ist beendet, wenn alle seine Karten aufgelöst sind. Danach wird
sofort und ohne Nutzerinteraktion der nächste Mini-Batch ausgewählt. Für den
Nutzer entsteht ein ununterbrochener Fluss.

---

## 6. Statusübergänge

`newStatus = clamp(effektiveStufe + delta, weak, secure)`

wobei `effektiveStufe` für `Neu` den Wert von `Schwach` (1) annimmt und sonst
der Stufe des aktuellen Status entspricht (Schwach 1, Mittel 2, Gut 3,
Sicher 4).

| Selbsteinschätzung | delta |
| --- | --- |
| Nochmal | −2 |
| Schwer | −1 |
| Gut | +1 |
| Sicher | +2 |

Daraus ergibt sich die vollständige Übergangsmatrix:

| von \ Antwort | **Nochmal** | **Schwer** | **Gut** | **Sicher** |
| --- | --- | --- | --- | --- |
| **Neu** | Schwach | Schwach | Mittel | Gut |
| **Schwach** | Schwach | Schwach | Mittel | Gut |
| **Mittel** | Schwach | Schwach | Gut | Sicher |
| **Gut** | Schwach | Mittel | Sicher | Sicher |
| **Sicher** | Mittel | Gut | Sicher | Sicher |

Zwei bewusste Eigenschaften:

- `Neu` ist ein reiner Startzustand. Nach der ersten Bewertung kehrt eine Karte
  nie dorthin zurück (außer der Nutzer setzt den Status von Hand).
- Ein Fehler auf einer sicheren Karte wirft sie auf *Mittel* zurück, nicht
  sofort auf *Schwach*. Ein einzelner Aussetzer soll den Fortschritt nicht
  vollständig entwerten — zwei Aussetzer hintereinander schon.

### 6.1 Statusänderung nur einmal pro Mini-Batch

**Der Lernstatus einer Karte wird pro Mini-Batch nur bei der *ersten*
Selbsteinschätzung geändert.**

Begründung: Ohne diese Regel würde die Folge „Nochmal“ → später „Gut“ eine
Karte netto auf *Mittel* heben — eine Karte, die man beim ersten Versuch nicht
konnte, wäre nach dem Batch besser bewertet als vorher. Der ehrliche Indikator
ist der erste Versuch. Weitere Einschätzungen derselben Karte im selben Batch
aktualisieren nur die Zähler (§7).

### 6.2 Manuelle Bearbeitung

Der Nutzer kann den Lernstatus in der Kartenübersicht direkt setzen. Ein
manuell gesetzter Status verhält sich anschließend wie jeder andere Status —
es gibt keine Sonderbehandlung und keine Sperre.

---

## 7. Persistierte Änderungen pro Antwort

Bei **jeder** Selbsteinschätzung (auch bei Wiederholungen innerhalb eines
Batches):

| Feld | Änderung |
| --- | --- |
| `reviewCount` | `+= 1` |
| `correctCount` | `+= 1` bei *Schwer*, *Gut*, *Sicher*; unverändert bei *Nochmal* |
| `lastReviewedAt` | auf die aktuelle Zeit setzen |
| `status` | nur bei der ersten Einschätzung im Batch (§6.1) |

*Schwer* zählt als korrekt: Der Nutzer wusste die Antwort, wenn auch mühsam.
Nur *Nochmal* bedeutet „nicht gewusst“.

Daraus abgeleitet (nicht gespeichert): `errorCount = reviewCount - correctCount`,
`accuracy = correctCount / reviewCount`.

Geschrieben wird nach jeder Antwort, nicht erst am Sessionende — so geht bei
einem Absturz oder App-Wechsel nichts verloren.

---

## 8. Parameter

Alle an einer Stelle, als benannte Konstanten:

| Konstante | Wert | Bedeutung |
| --- | --- | --- |
| `batchSize` | 7 | Karten pro Mini-Batch |
| `reinsertGap` | 3 | Mindestanzahl anderer Karten vor der Wiederholung |
| `maxReinserts` | 3 | Wiedereinreihungen pro Karte und Batch |
| `recencyFactor` | 0.2 | Gewichtsfaktor für Karten aus dem vorherigen Batch |
| `weightNew` | 5.0 | Basisgewicht *Neu* |
| `weightWeak` | 5.0 | Basisgewicht *Schwach* |
| `weightMedium` | 3.0 | Basisgewicht *Mittel* |
| `weightGood` | 1.0 | Basisgewicht *Gut* |
| `weightSecure` | 0.3 | Basisgewicht *Sicher* |

`batchSize` wird später optional in den Einstellungen verstellbar (Bereich
5–10). Vorerst fest.

---

## 9. Randfälle

| Fall | Verhalten |
| --- | --- |
| Pool ist leer | Session startet nicht; Hinweis mit direktem Weg zum Anlegen einer Karte |
| Pool kleiner als `batchSize` | Batch = gesamter Pool; Recency-Faktor deaktiviert |
| Pool hat genau 1 Karte | Batch der Größe 1; „Nochmal“ hängt ans Ende an; `maxReinserts` greift weiterhin |
| Karte wird während der Session bearbeitet | Änderung wird beim nächsten Anzeigen sichtbar; die Queue arbeitet mit IDs, nicht mit Kopien der Inhalte |
| Karte wird während der Session gelöscht | ID lässt sich nicht mehr auflösen → wird beim Weiterschalten übersprungen |
| Karte ohne Hanzi | wird beim Bilden des Pools ausgeschlossen (in beiden Richtungen unbrauchbar) |
| App wird in den Hintergrund geschickt | Kartenänderungen sind bereits gespeichert; der Session-Zustand liegt nur im Speicher. Bei Terminierung der App ist die Session vorbei — bewusste MVP-Entscheidung, kein Wiederherstellen der Queue. |

---

## 10. Testfälle für Phase 5

Pflicht-Unit-Tests, alle ohne Simulator und ohne `ModelContainer` lauffähig:

**Gewichtung**
1. Jeder Status liefert genau sein Basisgewicht.
2. Recency-Faktor wird angewandt, wenn die Karte im Vorbatch war.
3. Recency-Faktor entfällt bei Pool < `2 × batchSize`.

**Batch-Auswahl**
4. Ein Batch enthält keine Karte doppelt.
5. Batchgröße = `min(batchSize, poolGröße)`.
6. Gleicher Seed ⇒ gleiches Ergebnis (Determinismus).
7. Über viele Ziehungen mit festem Seed werden Karten mit Status *Schwach*
   deutlich häufiger gewählt als *Sicher* (statistische Plausibilität, kein
   exakter Erwartungswert).
8. Pool mit einer einzigen Karte liefert einen Batch der Größe 1.

**Queue**
9. Nach „Nochmal“ liegen genau `reinsertGap` andere Karten vor der Wiederholung.
10. Sind weniger als `reinsertGap` Karten übrig, landet die Karte am Ende.
11. Nach `maxReinserts` Wiederholungen verlässt die Karte den Batch.
12. „Gut“ entfernt die Karte sofort aus der Queue.
13. Ein Batch endet erst, wenn alle Karten aufgelöst sind.
14. Batch der Größe 1 mit „Nochmal“ terminiert (kein Endlosloop).

**Statusübergänge**
15. Alle 20 Zellen der Übergangsmatrix aus §6.
16. Untergrenze *Schwach* und Obergrenze *Sicher* werden nie unter-/überschritten.
17. Zweite Einschätzung derselben Karte im selben Batch ändert den Status nicht.

**Zähler**
18. `reviewCount` steigt bei jeder Einschätzung, auch bei Wiederholungen.
19. `correctCount` steigt bei *Schwer*/*Gut*/*Sicher*, nicht bei *Nochmal*.

---

## 11. Vorbereitung auf echtes Spaced Repetition

Der Übergang ist bewusst klein gehalten:

1. `Card` bekommt zwei zusätzliche Felder: `dueDate: Date?` und
   `intervalDays: Double`.
2. `CardWeighting` multipliziert das Basisgewicht mit einem
   Überfälligkeitsfaktor, z. B. `max(1.0, verstricheneTage / intervalDays)`.
3. Die Statusübergänge aus §6 setzen zusätzlich das neue Intervall
   (SM-2-artig: *Nochmal* setzt zurück, *Gut* multipliziert, *Sicher*
   multipliziert stärker).

**Batch-Auswahl, Queue-Logik und die Schnittstelle der Engine bleiben dabei
unverändert.** Genau deshalb ist die Gewichtung als eigene, austauschbare
Funktion herausgezogen.
