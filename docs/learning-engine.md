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

**Zwei Begriffe, die nicht dasselbe sind** — der Gerätetest der Phase 6 hat
gezeigt, dass sie für den Nutzer gleich aussahen:

| Typ | Bedeutung |
| --- | --- |
| `SelfAssessment` | Die Bewertung **eines einzelnen Versuchs**: Nochmal, Schwer, Gut, Sicher. Eine Momentaufnahme. |
| `LearningStatus` | Der **längerfristige Kenntnisstand** einer Karte: Neu, Schwach, Mittel, Gut, Sicher. Persistiert. |

„Schwer" bei einem Versuch heißt „ich wusste es mit Mühe" — nicht, dass die
Karte dauerhaft auf einer bestimmten Stufe steht. Die beiden dürfen fachlich
**nicht** zusammengelegt werden, auch wenn zwei ihrer Bezeichnungen
gleich lauten.

Seit Phase 6 verlangt der Karteneditor den `LearningStatus` **nicht mehr**
manuell: Beim Anlegen einer Karte kann niemand ihn sinnvoll beantworten. Neue
Karten starten auf `new`, bestehende behalten ihren Wert, und die Engine
schreibt ihn aus den Selbsteinschätzungen fort (§6). Langfristig soll er
stärker automatisch abgeleitet werden — Produktidee in
[architecture.md §9.1](architecture.md#91-automatische-mastery-einschätzung-produktidee-nicht-gebaut),
noch nicht gebaut. Die fünfstufige Skala bleibt vorerst unverändert; sie ist
ein Engine-Zustand, kein Pflichtfeld für den Nutzer.


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
    hinterUngesehenen = index(letzte noch nie bewertete Karte) + 1
    neuePosition = max(reinsertGap, hinterUngesehenen)
    queue.insert(karte, at: min(neuePosition, queue.count))
    reinserts[karte] += 1
```

**Ungesehene Karten zuerst.** Eine Wiederholung liegt hinter *jeder* Karte, die
ihren ersten Versuch noch nicht hatte, und mindestens `reinsertGap` Positionen
entfernt. Beide Hälften sind nötig: die untere Schranke verhindert
„A falsch → A erneut“, die Ungesehenen-Grenze verhindert den Zyklus.

**Diese Regel ist eine Korrektur aus dem Gerätetest der Phase 6.** Vorher stand
dort die feste Position `i + reinsertGap`. Physisch reproduziert: Bei
`A B C D E F G` und „Nochmal“ auf den ersten vier Karten lief der Batch als
`A B C D A B C D`, während E, F und G nie gezeigt wurden. Wegen `maxReinserts`
technisch endlich, für den Nutzer aber eine Schleife — und fachlich falsch, weil
vier Karten gedrillt werden, statt die anderen drei einzuführen. Die alte
Formulierung „genau `reinsertGap` andere Karten“ gilt damit **nicht mehr**; sie
gilt nur noch, wenn keine ungesehene Karte übrig ist.

Beispiel mit `queue = [A, C, F, B, D]` und `i = 0`, A wird mit „Nochmal“
bewertet — C, F, B und D sind noch ungesehen:

```
entfernen  → [C, F, B, D]
einfügen hinter den Ungesehenen → [C, F, B, D, A]
```

Sind weniger Karten übrig als die Position verlangt, wird angehängt — die Karte
kommt dann so spät wie im Batch noch möglich.

**Obergrenze:** Eine Karte darf pro Mini-Batch höchstens `maxReinserts` (= 1)
mal wieder eingereiht werden. Danach gilt sie als aufgelöst und verlässt den
Batch. Ohne diese Grenze könnte ein Batch nie enden.

**Auch dieser Wert ist eine Korrektur aus dem Gerätetest der Phase 6**, vorher
3. Zusammen mit mehreren Fehlkarten wurde aus einem Fenster von sieben Karten
ein Drill über zehn bis fünfzehn Fragen zu denselben wenigen Karten. Eine
einmalige kurzfristige Wiederholung bleibt erhalten; alles darüber übernimmt die
Gewichtung, die eine Karte mit niedrigem Status ohnehin mit hoher
Wahrscheinlichkeit in einen späteren Batch holt (§3.1). Die Session ist endlos,
der einzelne Batch muss es nicht sein.

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

### 7.1 Automatisch weitergereichte Versuche (Phase 11)

Geht die App von selbst weiter (§12), gibt es **keine** Selbsteinschätzung.
Persistiert wird dann:

| Feld | Änderung |
| --- | --- |
| `reviewCount` | `+= 1` — ein Versuch hat stattgefunden |
| `lastReviewedAt` | auf jetzt |
| `correctCount` | **unverändert** |
| `status` | **unverändert** (A36) |

`correctCount` bleibt stehen, weil „richtig" eine Bewertung ist und hier
niemand bewertet hat. Das Einzige, was vorlag, ist ein Textvergleich, dessen
False-Accept-Eigenschaft in Phase 9 nicht gemessen wurde. Folge: `accuracy`
(abgeleitet, heute von keiner Ansicht gelesen) **unterschätzt** Karten, die
oft automatisch durchlaufen. Von den beiden möglichen Fehlerrichtungen ist das
die richtige — sie kann nie mehr behaupten, als der Lernende gezeigt hat.

---

## 8. Parameter

Alle an einer Stelle, als benannte Konstanten:

| Konstante | Wert | Bedeutung |
| --- | --- | --- |
| `batchSize` | 7 (Default) | Karten pro Mini-Batch; seit Phase 10 in den Einstellungen zwischen 5 und 10 verstellbar |
| `reinsertGap` | 3 | **Mindest**anzahl anderer Karten vor der Wiederholung; ungesehene Karten gehen immer vor (§5) |
| `maxReinserts` | 1 | Wiedereinreihungen pro Karte und Batch (bis zum Gerätetest der Phase 6: 3, siehe §5) |
| `recencyFactor` | 0.2 | Gewichtsfaktor für Karten aus dem vorherigen Batch |
| `weightNew` | 5.0 | Basisgewicht *Neu* |
| `weightWeak` | 5.0 | Basisgewicht *Schwach* |
| `weightMedium` | 3.0 | Basisgewicht *Mittel* |
| `weightGood` | 1.0 | Basisgewicht *Gut* |
| `weightSecure` | 0.3 | Basisgewicht *Sicher* |

**`batchSize` ist seit Phase 10 verstellbar** — Bereich 5 bis 10, Default
weiterhin 7. Drei Dinge gehören dazu:

- **Geklemmt wird beim Lesen, nicht am Bedienelement.** `Preferences.batchSize`
  begrenzt jeden gespeicherten Wert auf 5…10 und liest eine fehlende Angabe
  als „Default". Die Voreinstellungsdatenbank ist editierbar und überlebt
  App-Updates; „der Stepper kann nur gültige Werte schreiben" gilt für den
  Stepper, nicht für den Speicher.
- **Die Größe erreicht zwei Stellen.** Die Auswahl selbst *und* die
  Recency-Schwelle `minimumPoolSizeForRecency(batchSize:)`, die zwei Batches
  entspricht. Wird sie nur an die Auswahl gereicht, verlieren alle Pools
  zwischen den beiden Zahlen die Dämpfung aus §3.2 — deshalb reicht
  `BatchSelector` sie an `CardWeighting.effectiveWeight` weiter, und genau
  diese Weitergabe ist mit einer Gegenmutation abgesichert
  (`BatchSelectorTests.batchSizeReachesTheRecencyThreshold`).
- **Gelesen wird am Batchstart, nie mitten im Batch.** Eine Änderung während
  einer laufenden Runde baut diese Runde nicht um; sie wirkt ab der nächsten.

§9 („Pool kleiner als `batchSize`") gilt unverändert.

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
9. Nach „Nochmal“ liegt die Wiederholung hinter jeder noch ungesehenen Karte
   und mindestens `reinsertGap` Positionen entfernt. Dazu: mehrere Fehlkarten
   hintereinander lassen keine ungesehene Karte verhungern, und das gilt für
   jede Batchgröße, nicht nur für den beobachteten Vierer-Fall.
10. Sind weniger Karten übrig als die Einfügeposition verlangt, landet die
    Karte am Ende.
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

---

## 12. Assistierte Bewertung (Phase 11)

Seit Phase 11 sammelt die App Evidenz über eine Karte und **fragt an geeigneten
Stellen nicht mehr**. Die Regel ist rein, deterministisch und liegt in
`Learning/AssistedAssessment.swift`; die Historie liefert die Feature-Schicht
als `ReviewSignal`-Werte, genau wie sie `Card` als `CardSnapshot` liefert.

### 12.1 Was in einen Versuch eingeht

| Signal | Bedeutung |
| --- | --- |
| `direction` | Modus A oder B — beide stellen verschiedene Fragen |
| `previousStatus` | der Stand **vor** diesem Versuch |
| `usedSpeech` | ob überhaupt eine automatische Evidenz vorlag |
| `speechMatched` | ob Apples Text nach der Normalisierung dem Hanzi entsprach; `nil` ohne Sprache |
| `wasManualReveal` | Aufdecken ohne Versuch |
| `wasRetry` | zweiter Anlauf an derselben Karte im selben Batch |
| `assessment` | die abgegebene Bewertung, `nil` bei automatischem Weitergehen |

**Nicht enthalten und nicht gespeichert:** Rohaudio, Konfidenz, Zeitdauern,
Aussprache- oder Tonwerte. Keiner dieser Werte wurde je gemessen (harte
Regel 7), und ein Feld, das es gibt, wird irgendwann benutzt.

### 12.2 Ein „sauberer Versuch"

Vier Bedingungen zusammen, jede tragend:

1. Sprache wurde benutzt **und** der Text stimmte überein,
2. es war **kein** Wiederholungsversuch (§6.1 folgt derselben Logik),
3. es wurde **nichts** vorher aufgedeckt,
4. eine abgegebene Bewertung schadet nicht — wer einen sauberen Versuch selbst
   bestätigt, hat trotzdem einen sauberen Versuch gemacht.

### 12.3 Die Entscheidung

```text
Karte ist Neu                      → fragen
kein sauberer Versuch              → fragen   (Mismatch, Aufdecken, Retry, ohne Sprache)
Lauf < 2 saubere Versuche          → fragen
3 automatische Reviews seit der
  letzten eigenen Bewertung        → fragen   (Rekalibrierung)
sonst                              → automatisch weiter, Status unverändert
```

Der **Vorschlag** ist ein Schritt nach oben und nie mehr: `StatusTransition`
mit *Gut*, auf derselben Leiter wie §6. Am oberen Ende gibt es keinen, weil
*Gut* auf *Sicher* nichts ändert. **Nach unten gibt es nie einen Vorschlag** —
der einzige Kandidat dafür wäre ein Mismatch, und ein Mismatch ist keine
negative Evidenz.

### 12.4 Was die Regel nicht darf

- **Ein Mismatch senkt nichts.** Er beendet einen Lauf, und das heißt: fragen,
  nicht abwerten. Der exakte Vergleich ist konstruktionsbedingt empfindlich —
  in Phase 9 kamen 8 von 16 normal gesprochenen Zielantworten als anderer
  chinesischer Text zurück.
- **Ein einzelner Treffer trägt nichts.** Die False-Accept-Eigenschaft des
  Vergleichs ist **nicht gemessen**; der Phase-9-Benchmark wurde nach dem
  Positivdurchgang abgebrochen. Wie oft ein Treffer zufällig entsteht, ist
  damit unbekannt.
- **Der Vorschlag ändert nie etwas.** Er hebt eine Taste hervor. Der Status
  bewegt sich ausschließlich über `StatusTransition` und ausschließlich nach
  einem Tipp des Nutzers.
- **Automatisches Weitergehen hebt den Status nicht.** Es spart eine Frage,
  es vergibt keine Beförderung.

### 12.5 Die drei freien Parameter sind Produktentscheidungen

Die Roadmap hatte Fenstergröße, Gewichte, Alterung und Schwellen offen
gelassen — zu konkretisieren, „nachdem reale Review-Historie existiert". Diese
Historie entsteht erst mit dieser Phase. Die Werte sind deshalb **entschieden,
nicht gemessen**, und stehen so auch im Code:

| Parameter | Wert | Begründung |
| --- | --- | --- |
| Fenstergröße | 10 | die Ausgangsidee der Roadmap; begrenzt, damit ein alter Lauf nicht die letzte Woche überstimmt |
| saubere Versuche vor dem Weitergehen | 2 | die kleinste Zahl, die nicht eins ist; höher gewählt würde das Feature keine einzige Frage sparen |
| automatische Reviews bis zur Rekalibrierung | 3 | ohne sie friert der Status einer Karte mit langem Lauf ein, und Evidenz könnte nie etwas bedeuten |

**Zeitliche Alterung gibt es bewusst nicht.** Ein Halbwertsbetrag ohne Daten,
an die er angepasst wäre, wäre genau das Muster, das der Phase-9-Benchmark
vermieden hat. Eine echte Alterung bleibt offen, bis Historie existiert, an
der sie kalibrierbar wäre.

**Aktualität entsteht durch den Abbruch des Laufs, nicht durch das Fenster.**
Das ist eine Korrektur an der ersten Fassung dieses Abschnitts, die das
Testaudit gefunden hat: Der Lauf wird vom neuesten Versuch rückwärts gezählt
und endet beim ersten verwertbaren Versuch, der nicht sauber war — alles vor
dem letzten Patzer kann also nichts bewirken. Das Fenster ist dagegen eine
**Obergrenze für das, was gelesen wird**: Bei einer Schwelle von zwei kann das
Kappen eines Laufs bei zehn keine Entscheidung ändern. Es begrenzt die
Datenmenge, nicht das Ergebnis, und genau so steht es jetzt auch im Code.
