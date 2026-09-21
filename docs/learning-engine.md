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
Karten starten auf `new`, bestehende behalten ihren Wert, und bis Phase 12
schrieb die Engine ihn aus den Selbsteinschätzungen fort (§6). **Seit Phase 13
gibt es die Selbsteinschätzungen im Lernflow nicht mehr:** Der Status bewegt
sich nur noch über eine vom Nutzer bestätigte Einstufung
([§13](#13-lernflow-und-assistierte-einstufung-phase-13)) oder von Hand in der
Kartenliste. Die Idee, ihn stärker automatisch abzuleiten, war in
[architecture.md §9.1](architecture.md#91-automatische-mastery-einschätzung-produktidee-nicht-gebaut)
als Produktidee beschrieben und ist damit der Regelfall geworden — mit der dort
benannten Einschränkung, dass von den vier Signalen nur der
Recognition-Match trägt. Die fünfstufige Skala bleibt unverändert; sie ist ein
Engine-Zustand, kein Pflichtfeld für den Nutzer.


| Begriff | Bedeutung |
| --- | --- |
| **Pool** | Alle Karten, die zur Session-Konfiguration passen (Kartentyp, optional Tag-Filter). Wird einmal beim Sessionstart gebildet. |
| **Mini-Batch** | Eine Gruppe von standardmäßig 7 **unterschiedlichen** Karten aus dem Pool. |
| **Queue** | Die Abfragereihenfolge innerhalb des aktuellen Mini-Batches. Verändert sich durch Wiedereinstreuung. |
| **Aufgelöst** | Eine Karte gilt als aufgelöst, wenn sie im aktuellen Mini-Batch mit *Schwer*, *Gut* oder *Sicher* bewertet wurde. Sie verlässt damit den Batch. **Ab Phase 13** ([§13.4](#134-die-sechs-aktionen-und-was-sie-schreiben)): aufgelöst ist eine Karte, deren Versuch mit *Weiter*, *Bestätigen* oder *Ablehnen* abgeschlossen wurde und die nicht nach *Aufgeben* wieder eingestreut wird. |
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

**Ab Phase 13 ändert sich die letzte Zeile des Kartenzyklus**, nicht die
Struktur darüber: Statt der Selbsteinschätzung steht dort *Weiter* oder eine
binäre Einstufungsfrage, und die Rolle von „Nochmal" übernimmt *Aufgeben*.
Pool, Mini-Batch, Gewichtung und Queue bleiben unverändert — die verbindliche
Beschreibung des neuen Kartenzyklus steht in
[§13](#13-lernflow-und-assistierte-einstufung-phase-13).

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

> **Ab Phase 13** löst nicht mehr die Selbsteinschätzung diese Regeln aus,
> sondern der Abschluss eines Versuchs, und wieder eingestreut wird genau nach
> *Aufgeben* ([§13.5](#135-wiedereinstreuung-aufgeben-ist-die-einzige-aussage-über-nichtwissen)).
> **Position, Obergrenze und Begründung dieses Abschnitts gelten unverändert**
> — nur der Auslöser heißt anders.

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

**Ab Phase 13 gilt die Regel unverändert, wird aber nicht mehr gezählt,
sondern ist strukturell erfüllt:** Der Status wandert nur über *Bestätigen*,
das setzt einen sauberen Versuch voraus, und ein sauberer Versuch ist kein
Wiederholungsversuch ([§13.9](#139-welche-phase-11-regeln-damit-ersetzt-sind)).

Begründung: Ohne diese Regel würde die Folge „Nochmal“ → später „Gut“ eine
Karte netto auf *Mittel* heben — eine Karte, die man beim ersten Versuch nicht
konnte, wäre nach dem Batch besser bewertet als vorher. Der ehrliche Indikator
ist der erste Versuch. Weitere Einschätzungen derselben Karte im selben Batch
aktualisieren nur die Zähler (§7).

### 6.2 Manuelle Bearbeitung

Der Nutzer kann den Lernstatus in der Kartenübersicht direkt setzen — seit
Phase 13 auch tatsächlich: über ein Kontextmenü auf der Kartenzeile, mit dem
aktuellen Stand markiert. Die Auswahl schreibt sofort, ohne Bestätigungsdialog,
und die Auswahl des bereits aktiven Status ist ein No-op.

**Diese Korrektur ist keine Lernantwort.** Sie schreibt keinen
`ReviewLog`-Eintrag, bewegt weder `reviewCount` noch `correctCount` noch
`lastReviewedAt`, und sie streut keine Karte in einen laufenden Batch ein. Sie
als Review zu verbuchen würde ein Lernereignis erfinden, das nicht stattgefunden
hat.

**Sie setzt aber eine Evidenzgrenze**, und das ist der schwierige Teil — siehe
[§13.13](#1313-die-manuelle-korrektur-und-ihre-evidenzgrenze). Ein manuell
gesetzter Status verhält sich danach wie jeder andere: keine Sonderbehandlung,
keine Sperre.

**Bis Phase 13 war dieser Abschnitt eine Beschreibung ohne Deckung.** Er stand
seit Phase 1 hier, das Bedienelement wurde nie gebaut, und bis Phase 12 fiel das
nicht auf, weil *Nochmal* (−2) und *Schwer* (−1) nach unten führten. Als Phase 13
diese beiden entfernte, war der Widerspruch da: kein automatischer Downgrade und
kein manueller. Das unabhängige Code Review hat ihn gefunden, und er ist mit
dem Kontextmenü eingelöst statt umformuliert worden.

---

## 7. Persistierte Änderungen pro Antwort

Bei **jeder** Selbsteinschätzung (auch bei Wiederholungen innerhalb eines
Batches) — ab Phase 13 bei jedem abgeschlossenen Versuch, siehe
[§13.4](#134-die-sechs-aktionen-und-was-sie-schreiben):

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

### 7.1 Versuche ohne Bewertung (Phase 11, erweitert in Phase 13)

Geht die App von selbst weiter (§12), gibt es **keine** Selbsteinschätzung.
**Ab Phase 13 gilt dieselbe Tabelle für *Weiter* und *Ablehnen***, die beide
ebenfalls keine Bewertung abgeben; das automatische Weitergehen selbst
entfällt ([§13.9](#139-welche-phase-11-regeln-damit-ersetzt-sind)). Die Zeile
`correctCount` gilt zusätzlich für *Bestätigen*: Auch eine bestätigte
Einstufung ist keine Selbsteinschätzung, also bewegt sie diesen Zähler nicht
([§13.4](#134-die-sechs-aktionen-und-was-sie-schreiben)). Persistiert wird:

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

**Was Phase 13 an dieser Liste ändert** (Einzelbegründungen in
[§13.9](#139-welche-phase-11-regeln-damit-ersetzt-sind)):

| Konstante | ab Phase 13 |
| --- | --- |
| `AssistedAssessment.windowSize` = 10 | unverändert — Obergrenze für die gelesene Historie |
| `cleanRunBeforeAutoAdvance` = 2 | heißt `cleanRunBeforeSuggestion`, Wert 2, jetzt Schwelle für einen **Vorschlag** |
| `autoAdvancesBeforeRecalibration` = 3 | **entfällt** |
| `batchSize`, `reinsertGap`, `maxReinserts`, `recencyFactor`, alle Gewichte | unverändert |

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

> **Teilweise überholt durch [§13](#13-lernflow-und-assistierte-einstufung-phase-13)
> (Phase 13, implementiert am 2026-09-21).** Dieser Abschnitt beschreibt den
> Stand der Phasen 11 und 12 und bleibt als Erklärung der bis dahin
> geschriebenen Historie gültig — das laufende Produkt folgt §13. Welche Regeln
> ersetzt sind und welche unverändert weitergelten, steht einzeln in
> [§13.9](#139-welche-phase-11-regeln-damit-ersetzt-sind); §12.1, §12.2, §12.4
> und §12.5 gelten in beiden Fassungen.

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

---

## 13. Lernflow und assistierte Einstufung (Phase 13)

**Status: spezifiziert und implementiert am 2026-09-21.** Dieser Abschnitt ist
die verbindliche Regel des laufenden Produkts und **ersetzt §12 dort, wo die
beiden sich widersprechen** — die Ersetzungen stehen einzeln in
[§13.9](#139-welche-phase-11-regeln-damit-ersetzt-sind). §12 bleibt als
Beschreibung des Stands der Phasen 11 und 12 stehen; §12.1, §12.2, §12.4 und
§12.5 gelten in beiden Fassungen weiter.

### 13.1 Warum die vier Tasten den normalen Flow verlassen

Phase 11 hat die Frage nur im sauberen Fall gespart. In jedem anderen Fall —
Mismatch, Aufdecken, Retry, kein Mikrofon, Modus B, Rekalibrierung — stand
weiterhin *Nochmal / Schwer / Gut / Sicher* auf dem Bildschirm. Das ist genau
der Tap, den die Roadmap loswerden wollte, und es ist eine Frage, die direkt
nach dem Aufdecken niemand ehrlich beantworten kann: Der Unterschied zwischen
*Schwer* und *Gut* ist eine Stimmung, keine Beobachtung, und beide liegen
**nach** dem Moment, in dem die Antwort schon sichtbar war.

Der neue Flow stellt höchstens **eine binäre Frage**, und nur dann, wenn die
App für einen konkreten Schritt nach oben Evidenz hat. Sonst gibt es einen
einzigen Knopf weiter.

Was dabei **nicht** entsteht: kein neues Signal, keine Ersatzheuristik, keine
Aussprachebewertung. Die einzige automatische positive Evidenz dieser App
bleibt der exakte Textvergleich aus Phase 9, mit allen Grenzen aus §12.4.

### 13.2 Der Flow in Modus A

```text
verdeckte Karte
  ├─ [ Antwort sprechen ]  → Aufnahme läuft
  │     ├─ [ ■ ]      → Versuch verworfen, keine Auswertung, kein Aufdecken
  │     └─ [ Fertig ] → finalisieren → Phase-9-Vergleich → aufdecken
  └─ [ Aufgeben ]     → laufende Aufnahme verwerfen → aufdecken

aufgedeckte Karte
  ├─ kein Vorschlag → [ Weiter ]
  └─ Vorschlag      → „Neue Einstufung: Mittel → Gut"
                      [ Ablehnen ]  [ Bestätigen ]
```

Der **Versuch ist erst mit dem Verlassen der Karte abgeschlossen** — also mit
*Weiter*, *Bestätigen* oder *Ablehnen*. Genau dann entsteht der
`ReviewLog`-Eintrag, und genau einer. Das ist eine bewusste Präzisierung der
Formulierung „schreibt den Review, deckt danach die Karte auf": Ausgewertet
wird vor dem Aufdecken, protokolliert wird beim Verlassen — sonst könnte der
Eintrag nicht tragen, wie die Einstufungsfrage ausgegangen ist, und die
Phase-11-Zusage „pro abgeschlossenem Versuch genau ein Eintrag" wäre
gebrochen.

Wer die Session mitten im aufgedeckten Zustand verlässt, erzeugt **keinen**
Eintrag. Das ist unverändert: Der Fragepfad aus Phase 11 verhält sich heute
genauso.

Zwei Randfälle, damit sie nicht beim Implementieren entschieden werden müssen:

- **Aufgeben während `finalizing`.** Der Lernende gewinnt: Die laufende
  Analyse wird verworfen, ihr Ergebnis erreicht die Karte nicht mehr, der
  Versuch gilt als von Hand aufgedeckt (`usedSpeech = false`). Das ist der
  Weg, den Phase 9 für das Aufdecken während einer Aufnahme schon geht —
  dieselbe Abbruchlogik, dieselbe Epochenprüfung.
- **Schreibfehler bei *Bestätigen* oder *Ablehnen*.** Wie bisher:
  `rollback()`, Alert, die Karte bleibt aufgedeckt — **und der Vorschlag bleibt
  stehen**, damit dieselbe Entscheidung erneut möglich ist. Ein Alert, nach dem
  die Frage verschwunden ist, wäre die Unwahrheit über das, was gespeichert
  wurde.

### 13.3 Der Flow in Modus B

```text
nur Audio → [ Hanzi anzeigen ] → [ Antwort zeigen ] → [ Weiter ]
```

**Kein Vorschlag, keine Statusänderung, keine Wiedereinstreuung.** Ohne die
vier Tasten gibt es in Modus B kein Correctness-Signal, und eine
Ersatzheuristik wird nicht erfunden. Der Knopf heißt dort weiterhin *Antwort
zeigen* und nicht *Aufgeben*: Das Aufdecken **ist** der vorgesehene Schritt
dieses Modus, nicht das Aufgeben eines Versuchs. **In Modus A heißt er
dagegen in jedem Zustand *Aufgeben*** — auch ohne Mikrofonfreigabe und auf
einem Gerät ohne Erkennung ([§13.5](#135-wiedereinstreuung-aufgeben-ist-die-einzige-aussage-über-nichtwissen)).

Die benannte Folge steht in [§13.11](#1311-was-das-kostet).

### 13.4 Die sechs Aktionen und was sie schreiben

| Aktion | Vorbedingung | `status` | `reviewCount` | `correctCount` | Queue | `ReviewLog` |
| --- | --- | --- | --- | --- | --- | --- |
| **Fertig** | Aufnahme läuft | — | — | — | — | — (nur Auswertung + Aufdecken) |
| **■ (Stop)** | Aufnahme läuft | — | — | — | — | — (nichts ist passiert) |
| **Aufgeben** | verdeckt, Modus A | — | — | — | — | — (nur Aufdecken) |
| **Weiter** | aufgedeckt, kein Vorschlag | unverändert | `+= 1` | **unverändert** | Karte verlässt den Batch; nach *Aufgeben* Wiedereinstreuung nach §5, sofern eine Aufnahme möglich war (§13.5) | ein Eintrag: `assessment = nil`, `suggestedStatus = nil`, `suggestionDecision = nil` |
| **Bestätigen** | aufgedeckt, Vorschlag liegt vor | auf den vorgeschlagenen Wert | `+= 1` | **unverändert** | Karte verlässt den Batch | ein Eintrag: `assessment = nil`, `suggestedStatus` = der Vorschlag, `suggestionDecision = .accepted` |
| **Ablehnen** | aufgedeckt, Vorschlag liegt vor | unverändert | `+= 1` | **unverändert** | Karte verlässt den Batch | ein Eintrag: `assessment = nil`, `suggestedStatus` = der Vorschlag, `suggestionDecision = .declined` |

Vier Dinge daran sind Entscheidungen, nicht Mechanik:

- **`assessment` bleibt im neuen Flow immer leer.** Das Feld bedeutet
  ausschließlich „der Lernende hat im alten Flow eine der vier
  Selbsteinschätzungen abgegeben" und behält diese Bedeutung, damit die
  Historie aus den Phasen 11 und 12 lesbar bleibt. Eine bestätigte Einstufung
  ist **etwas anderes** als eine Selbsteinschätzung: Sie ist die Zustimmung zu
  einem Vorschlag der App und wird deshalb als solche gespeichert
  ([§13.10](#1310-die-schemaänderung-zwei-felder-und-warum-genau-zwei)) —
  nicht als die Bewertung, die denselben Übergang erzeugt hätte. Der Unterschied
  ist später nicht rekonstruierbar, wenn er jetzt eingeschmolzen wird.
- **`correctCount` bewegt sich im neuen Flow nie** — auf keinem der drei
  Abschlusswege. Es ist in §7 über die Selbsteinschätzung definiert, und die
  gibt es hier nicht mehr; auch *Bestätigen* ist keine, sondern Zustimmung zu
  einem Vorschlag der App. Die Begründung ist unverändert die aus §7.1:
  „richtig" ist eine Bewertung, und vorgelegen hat ein Textvergleich, dessen
  False-Accept-Eigenschaft nicht gemessen ist. `correctCount` wird damit ein
  Aggregat der Phasen 1 bis 12, das stehen bleibt und nicht mehr wächst; die
  Folge für `accuracy` steht in [§13.11](#1311-was-das-kostet).
- **Stop schreibt nichts.** Ein abgebrochener Versuch ist kein Versuch. Der
  Zähler `reviewCount` bleibt stehen, der Sprachmodus bleibt armiert, und auf
  **derselben** Karte startet keine neue Aufnahme von selbst — A38 gilt
  unverändert, ein weiterer Anlauf braucht einen Tap.
- **Der Status wird bei *Bestätigen* direkt geschrieben**, auf den Wert, den
  §13.6 vorgeschlagen hat. `StatusTransition` bleibt die einzige Stelle, an der
  dieser Wert **entsteht** (beim Bilden des Vorschlags); geschrieben wird er
  danach ohne eine zweite Herleitung. Zwei Wege zum selben Wert wären zwei
  Wahrheiten.

### 13.5 Wiedereinstreuung: „Aufgeben" ist die einzige Aussage über Nichtwissen

*Nochmal* war bis Phase 12 die einzige Antwort, die eine Karte im Batch
zurückließ (§5). Ohne die vier Tasten übernimmt **Aufgeben** genau diese Rolle
— und nur diese. Beschriftung und Wiedereinstreuung sind dabei **zwei
getrennte Regeln**, und das ist Absicht.

**Der Knopf heißt in Modus A in jedem Zustand *Aufgeben*** — auch bei
verweigertem Mikrofon und auf einem Gerät ohne Mandarin-Erkennung. Ein
Bedienelement, das sich je nach Mikrofonzustand umbenennt, ist schwerer zu
lernen als eines, das es nicht tut, und *Aufgeben* beschreibt in allen diesen
Fällen dasselbe: Der Lernende beendet diesen Versuch, ohne die Antwort
produziert zu haben. Nur Modus B heißt weiter *Antwort zeigen*, weil das
Aufdecken dort der vorgesehene Schritt ist.

**Die Wiedereinstreuung hängt an einer eigenen, engeren Bedingung:**

```text
Wiedereinstreuung  ⟺  Modus A  ∧  von Hand aufgedeckt
                                 ∧  eine Aufnahme war auf dieser Karte möglich
```

„Möglich" heißt: Die Erkennungsphase war keine der beiden dauerhaft
unmöglichen (`unavailable`, `permissionDenied`). Position und Obergrenze sind
unverändert §5 — hinter jeder noch ungesehenen Karte, mindestens
`reinsertGap`, höchstens `maxReinserts` mal, also **genau einmal pro
Mini-Batch**.

Was dadurch **nicht** passiert: Aufgeben senkt keinen Status (es gibt keinen
automatischen Downgrade mehr, §13.8), es zählt nicht als korrekt, und es ist
keine negative Evidenz für die Einstufungsregel — es ist schlicht kein
sauberer Versuch.

**Warum die dritte Bedingung nötig ist — und warum Beschriftung und Verhalten
hier auseinandergehen dürfen:** Auf einem Gerät ohne Mandarin-Erkennung oder
ohne Mikrofonfreigabe ist das Aufdecken der einzige Weg vorwärts. Würde dort
jede Karte wieder eingestreut, würde **jeder Batch doppelt so lang** —
7 Karten würden zu 14 Fragen, jede Karte zweimal, immer. Das wäre kein
Lernvorteil, sondern ein Defekt.

Die Beschriftung bleibt trotzdem überall *Aufgeben*. Dass derselbe Knopf je
nach Gerät unsichtbar etwas unterschiedlich weiterplant, ist vertretbar, weil
der Unterschied reine **Terminplanung** ist: Er berührt weder den Lernstand
noch die Evidenz noch irgendeine Aussage an den Lernenden. Beides sind zwei
reine Prädikate, beide getestet — eines für den Text, eines für die Queue.

| Richtung | Erkennung verfügbar | Knopf | Wiedereinstreuung |
| --- | --- | --- | --- |
| A | ja | „Aufgeben" | ja, nach §5, genau einmal |
| A | nein (`unavailable`, `permissionDenied`) | **„Aufgeben"** | nein |
| B | — | „Antwort zeigen" | nein |

Ein **Mismatch streut nicht wieder ein.** Nur *Aufgeben* tut es. Ein Mismatch
ist ausdrücklich keine negative Evidenz (§13.8), und ihn zur
Wiederholungsentscheidung zu machen wäre genau das — eine Handlung auf ein
Signal, dem die App nach eigener Aussage nicht traut. Die einzige Aussage über
Nichtwissen im neuen Flow kommt vom Lernenden.

Die Bedingung wird **beim Aufdecken** festgehalten, nicht beim Verlassen der
Karte: Der Erkennungszustand kann sich dazwischen ändern, und welcher Knopf
gedrückt wurde, steht danach nicht mehr zur Debatte.

### 13.6 Der Vorschlag

Der vorgeschlagene Status ist unverändert **ein Schritt nach oben auf der
Leiter aus §6** und wird über dieselbe Funktion gebildet:

```text
Vorschlag = StatusTransition.newStatus(from: aktuellerStatus, for: .good)
```

Daraus ergeben sich genau vier mögliche Vorschläge — die *Gut*-Spalte der
Matrix aus §6:

| aktueller Status | Vorschlag |
| --- | --- |
| Neu | Mittel |
| Schwach | Mittel |
| Mittel | Gut |
| Gut | Sicher |
| Sicher | keiner (der Schritt würde nichts ändern) |

**Neu → Mittel und nicht Neu → Schwach**, weil *Neu* laut §6 ein reiner
Startzustand ist und die Leiter ihn mit Stufe 1 (*Schwach*) verrechnet. Zwei
saubere Versuche mit *Schwach* zu belohnen wäre eine Beförderung, die wie eine
Abwertung liest. Das ist keine neue Leiter, sondern dieselbe.

**Nach unten gibt es keinen Vorschlag**, und es gibt keinen zweiten Schritt
auf einmal.

### 13.7 Die Regel

Eingaben, alle unverändert aus §12.1 plus ein Feld: der aktuelle Status der
Karte, der laufende Versuch als `ReviewSignal`, und die Historie derselben
Karte, neueste zuerst, gekappt bei `windowSize`.

Ein **sauberer Versuch** ist unverändert §12.2: Sprache benutzt **und** Text
übereinstimmend, **kein** Retry, **nichts** vorher aufgedeckt.

Neu ist, welche Versuche überhaupt in denselben Lauf gehören. Der Lauf wird
vom laufenden Versuch rückwärts gezählt und berücksichtigt nur
**vergleichbare** Versuche:

1. **Gleiche Richtung.** Ein Versuch in der anderen Richtung wird
   *übersprungen*, nicht als Bruch gezählt. Modus B trägt keine Information
   über die Abrufleistung in Modus A — und dürfte sie deshalb auch nicht
   zerstören.
2. **Gleicher Ausgangsstatus.** Nur Versuche mit
   `previousStatus == aktuellerStatus` zählen. Das ist die Evidenz, die *seit
   der letzten Statusänderung* entstanden ist.
3. **Abbruch am ersten unsauberen Versuch.** Mismatch, Aufgeben, Retry oder
   „ohne Sprache" beenden den Lauf.
4. **Abbruch an einer Ablehnung genau dieses Schritts**, und der ablehnende
   Versuch selbst zählt **nicht** mit. „Genau dieses Schritts" ist die engere
   Lesart und die umgesetzte: Der Eintrag trägt den abgelehnten Status, und
   verglichen wird gegen den Status, der jetzt vorgeschlagen würde (A42, „für
   genau diesen nächsten Status"). Für jede heute erreichbare Historie fallen
   beide Lesarten zusammen, weil der Vorschlag deterministisch aus dem Status
   folgt und ein vergleichbarer Eintrag denselben Ausgangsstatus hat — die
   engere Regel ist der Schutz für eine spätere Fassung, die etwas anderes
   vorschlägt.

Ist der Lauf mindestens `cleanRunBeforeSuggestion` lang und gibt es überhaupt
einen Schritt nach oben, wird vorgeschlagen; sonst steht *Weiter* da.

```text
Lauf ≥ 2 vergleichbare saubere Versuche  und  Vorschlag ≠ aktueller Status
    → „Neue Einstufung"  [ Ablehnen ] [ Bestätigen ]
sonst
    → [ Weiter ]
```

**Regel 2 ist es, die `.new` freigibt.** Phase 11 hatte für `.new` einen
eigenen Riegel, weil eine von Hand auf *Neu* zurückgesetzte Karte ihre
Historie behält und die App sofort eine Beförderung hervorgehoben hätte —
ausgerechnet auf der Karte, die der Nutzer eben als ungelernt erklärt hat. Der
Riegel war das richtige Verhalten aus dem falschen Grund: Er hat den Status
geprüft, wo die **Herkunft der Evidenz** das Problem war. Regel 2 erledigt
beides. Eine zurückgesetzte Karte hat keine Evidenz auf *Neu*, also keinen
Vorschlag; eine wirklich neue Karte sammelt zwei saubere Versuche auf *Neu*
und bekommt ihren ersten Vorschlag. Der Riegel entfällt damit.

**Dieselbe Regel begrenzt auch die Kette nach oben.** Nach einer bestätigten
Beförderung *Mittel → Gut* tragen die Einträge mit `previousStatus == medium`
nichts mehr bei; die nächste Stufe braucht zwei frische saubere Versuche auf
*Gut*. Zwei Beförderungen hintereinander sind so nicht möglich.

**Und Regel 4 ist die Ablehnung.** Sie setzt die positive Evidenz für genau
diesen nächsten Status **vollständig auf null**, und sie zählt selbst nicht
als positiver Versuch. Bei der Schwelle 2 heißt das:

```text
Treffer, Treffer            → Vorschlag  Mittel → Gut
                            → Ablehnen          (protokolliert)
Treffer                     → kein Vorschlag    (Lauf = 1)
Treffer                     → Vorschlag  Mittel → Gut
```

Die Ablehnung wird **persistiert**, damit sie App- und Sessionneustarts
überlebt — sonst wäre sie eine Höflichkeit für die nächsten zehn Minuten.
Dafür gibt es die Schemaänderung dieser Phase, einzeln begründet
[in §13.10](#1310-die-schemaänderung-zwei-felder-und-warum-genau-zwei).

### 13.8 Was die Regel nicht darf

Unverändert und vollständig weiter gültig — jede Zeile aus §12.4 und der
Roadmap:

- **Ein Mismatch senkt nichts und schlägt nie einen Downgrade vor.** Er
  beendet einen Lauf. Der exakte Vergleich ist konstruktionsbedingt
  empfindlich: 8 von 16 normal gesprochenen Zielantworten kamen in Phase 9 als
  anderer chinesischer Text zurück.
- **Ein einzelner Treffer trägt nichts.** Die False-Accept-Eigenschaft des
  Vergleichs ist nicht gemessen.
- **Ein Retry ist keine gleichwertige positive Evidenz** — er ist gar keine.
- **Aufdecken und Aufgeben sind keine positive Evidenz.**
- **Keine automatische Herabstufung**, unter keinen Umständen, auch nicht über
  mehrere Mismatches. Es gibt **keinen** Pfad, auf dem die *App* einen Status
  senkt. Nach unten kommt eine Karte ausschließlich über die Korrektur von Hand
  in der Kartenübersicht (§6.2), und die gibt es seit Phase 13 wirklich
  ([§13.13](#1313-die-manuelle-korrektur-und-ihre-evidenzgrenze)).
- **Eine tatsächliche Statusänderung braucht die Zustimmung des Nutzers.** Der
  Vorschlag ändert nichts; er wird zu einer Änderung durch den Tap auf
  *Bestätigen* und durch nichts sonst.
- **Höchstens eine Stufe nach oben.**
- Kein Score, kein Prozentwert, keine Konfidenz, keine Aussage über Aussprache
  oder Töne (harte Regel 7), keine Streaks und keine
  Fortschrittsanzeige (harte Regel 6).

### 13.9 Welche Phase-11-Regeln damit ersetzt sind

| Regel aus §12 | ab Phase 13 |
| --- | --- |
| `.ask(suggestion:)` — Vierfachauswahl mit hervorgehobenem Vorschlag | **ersetzt.** Es gibt entweder *Weiter* oder die binäre Einstufungsfrage. Die vier Tasten verschwinden aus dem Lernflow. |
| `.autoAdvance` — die Frage entfällt, die Karte wechselt von selbst | **ersetzt.** Jede Karte endet mit einem Tap, und der aufgedeckte Zustand wird **immer** gezeigt. Damit ist auch der Phase-11-Vorbehalt „ob der Kartenwechsel ohne Rückmeldung zu abrupt wirkt" erledigt: Es gibt keinen Wechsel ohne Rückmeldung mehr. |
| `cleanRunBeforeAutoAdvance = 2` | **umbenannt und in der Bedeutung geändert:** `cleanRunBeforeSuggestion = 2` — Schwelle für einen **Vorschlag**, nicht fürs Überspringen einer Frage. Der Wert bleibt, die Begründung aus §12.5 bleibt. |
| `autoAdvancesBeforeRecalibration = 3` | **entfällt.** Der Parameter existierte, weil eine Karte mit langem Lauf sonst nie wieder gefragt worden wäre und ihr Status eingefroren wäre. Diesen Zustand gibt es nicht mehr: Sobald die Schwelle erreicht ist, liegt ein Vorschlag auf dem Tisch, und Regel 2 setzt den Lauf nach jeder Änderung selbst zurück. Ein Intervall, das nichts mehr schützt, wird nicht beibehalten. |
| `guard currentStatus != .new` → kein Vorschlag, keine Hervorhebung | **ersetzt** durch die Gleichstatus-Regel (§13.7, Regel 2). `.new` kann einen ersten Vorschlag bekommen; die von Hand zurückgesetzte Karte ist weiterhin geschützt, jetzt aber am richtigen Grund. |
| `ReviewSignal.isUsable` = `assessment != nil \|\| usedSpeech` | **ersetzt** durch die Richtungsregel. Sonst wäre ein *Aufgeben* ohne Sprache — im neuen Flow ein Alltagsfall, weil kein `assessment` mehr dabei entsteht — **übersprungen** statt als Bruch gezählt worden, und „Treffer, Aufgeben, Treffer" hätte einen Vorschlag erzeugt. |
| `AssistedAssessment.assessment(leadingTo:from:)` | **entfällt.** Sie übersetzte einen vorgeschlagenen Status in die Taste, die ihn erzeugt — und beides braucht es nicht mehr: Es gibt keine Taste, und *Bestätigen* wird ausdrücklich **nicht** als Selbsteinschätzung gespeichert ([§13.10](#1310-die-schemaänderung-zwei-felder-und-warum-genau-zwei)). Damit verlieren auch `SelfAssessment.countsAsCorrect` und `keepsCardInBatch` ihre Aufrufer; entfernt wird, was eine Aufrufersuche bei der Umsetzung als aufruferlos bestätigt. `statusDelta` und die vier RawValues bleiben — sie tragen die Matrix aus §6 und die Historie |
| `assessment != nil` als Beleg einer Bewertung | **bleibt, und wird geschützt.** Der neue Flow schreibt `assessment` niemals; eine bestätigte Einstufung wird als solche gespeichert, nicht als die Bewertung, die denselben Übergang erzeugt hätte ([§13.10](#1310-die-schemaänderung-zwei-felder-und-warum-genau-zwei)) |
| §12.2 „sauberer Versuch", alle vier Bedingungen | **unverändert.** |
| §12.4 in jedem Punkt | **unverändert**, siehe §13.8. |
| §12.5 „die freien Parameter sind Produktentscheidungen, keine Messungen" | **unverändert**, und gilt für `cleanRunBeforeSuggestion` genauso. Die Kalibrierung an realer Historie bleibt offen; sie wird durch die Aufzeichnung der Ablehnungen sogar erst möglich. |
| §7.1 Tabelle (Versuch ohne Bewertung) | **bleibt**, gilt jetzt für *Weiter* und *Ablehnen*. |
| §6.1 „Statusänderung nur einmal pro Mini-Batch" | **bleibt**, wird aber nicht mehr von der Queue erzwungen, sondern strukturell — siehe unten. |
| A36 „automatisches Weitergehen ändert den Lernstand nicht" | **in der Form überholt** (es gibt kein automatisches Weitergehen mehr), **in der Substanz übernommen**: *Weiter* hebt nichts. |
| Phase-12-Regel „Sprachausgabe entwaffnet den Sprachmodus" | **verengt**, siehe [§13.12](#1312-sprachausgabe-und-sprachmodus). |

**Zu §6.1:** Der Status kann nur über *Bestätigen* wandern, *Bestätigen* setzt
einen sauberen Versuch voraus, und ein sauberer Versuch ist per Definition
kein Retry. Eine zweite Statusänderung derselben Karte im selben Batch ist
damit unmöglich, ohne dass irgendwo ein Zähler das verhindern müsste. Das ist
eine **Invariante, die ein Test festnageln muss** — nicht eine Beobachtung,
die man beim Lesen des Codes nachvollzieht.

### 13.10 Die Schemaänderung: zwei Felder, und warum genau zwei

Zu protokollieren sind drei Dinge: der **vorgeschlagene Status**, die
**Annahme** und die **Ablehnung**. Und vier Tatsachen müssen später
auseinanderzuhalten sein, ohne Raten:

1. eine **historische Selbsteinschätzung** aus dem alten Flow,
2. eine **vorgeschlagene Einstufung**,
3. sie wurde **angenommen**,
4. sie wurde **abgelehnt**.

**`assessment` ist dafür nicht verwendbar**, und das ist der Kern dieses
Abschnitts. Das Feld bedeutet „der Lernende hat eine der vier
Selbsteinschätzungen abgegeben". Eine Zustimmung zu einem Vorschlag der App in
dasselbe Feld zu schreiben, weil sie zufällig denselben Statusübergang
erzeugt, würde (1) und (3) **ununterscheidbar** machen — rückwirkend und ohne
Weg zurück, weil die Unterscheidung nirgends sonst festgehalten wäre. Der
neue Flow schreibt deshalb **immer `assessment = nil`**.

Also zwei additive, optionale Felder auf `ReviewLog`:

```swift
/// Der Status, den die App bei diesem Versuch vorgeschlagen hat.
/// `nil` = es gab keinen Vorschlag.
private(set) var suggestedStatusRaw: Int?
var suggestedStatus: LearningStatus? { get set }

/// Was aus dem Vorschlag wurde: angenommen oder abgelehnt.
/// `nil` = es gab keinen Vorschlag.
private(set) var suggestionDecisionRaw: String?
var suggestionDecision: SuggestionDecision? { get set }
```

```swift
/// Explizit ausgeschriebene RawValues, weil sie Historie sind — dieselbe
/// Regel wie bei `SelfAssessment`, `SessionDirection` und `SpeechRate`.
nonisolated enum SuggestionDecision: String, CaseIterable, Sendable {
    case accepted = "accepted"
    case declined = "declined"
}
```

RawValues im Store aus demselben Grund wie bei `previousStatusRaw`; beide
Default `nil`, damit die Migration leichtgewichtig bleiben kann. Die beiden
Felder sind immer gemeinsam gesetzt oder gemeinsam `nil` — das ist eine
Invariante, die ein Test festnagelt, und kein Vertrauen.

**Sind wirklich beide nötig? Nachgerechnet, nicht angenommen:**

| Alternative | reicht nicht, weil |
| --- | --- |
| nur `suggestionDecision` | Der **vorgeschlagene Status** wäre nur über die heutige Regel rekonstruierbar (`previousStatus` + ein Schritt nach oben). Die Regel ist eine Produktentscheidung, die sich ändern darf — danach wären alle Alteinträge falsch gelesen. Eine Historie, deren Bedeutung von der aktuellen Fassung der Regel abhängt, ist keine Historie. Außerdem braucht §13.7 Regel 4 genau diesen Status. |
| nur `suggestedStatus` | „angenommen" und „abgelehnt" wären nicht unterscheidbar. Aus dem Eintrag selbst geht es nicht hervor — der Status der Karte liegt auf `Card` und wird von jedem späteren Versuch überschrieben —, und aus dem *nächsten* Eintrag es zu folgern wäre eine kartenübergreifende Herleitung, die für den jüngsten Eintrag ohnehin scheitert. |
| ein gemeinsames Feld („vorgeschlagen & abgelehnt: Mittel") | Das ist `suggestedStatus` plus ein implizites `declined` und verliert die Annahme. Genau die Annahmequote ist aber der Messwert, für den §12.5 die Kalibrierung offenlässt. |

**Zwei Felder, und semantische Eindeutigkeit vor der gesparten Property.** Alle
vier Tatsachen sind danach direkt ablesbar:

| Fall | `assessment` | `suggestedStatus` | `suggestionDecision` |
| --- | --- | --- | --- |
| historische Selbsteinschätzung (Phase 11/12) | gesetzt | `nil` | `nil` |
| automatisch weitergereicht (Phase 11/12) | `nil` | `nil` | `nil` |
| *Weiter* ohne Vorschlag (ab Phase 13) | `nil` | `nil` | `nil` |
| Vorschlag **angenommen** | `nil` | der Vorschlag | `.accepted` |
| Vorschlag **abgelehnt** | `nil` | der Vorschlag | `.declined` |

Zeile 2 und 3 sind identisch, und das ist richtig: Beides ist ein Versuch ohne
Bewertung und ohne Vorschlag. Unterscheidbar bleiben sie über `reviewedAt` und
darüber, ob Phase 13 zu diesem Zeitpunkt schon lief — eine Unterscheidung, die
keine Regel braucht.

**Keine zweite Bewertungshistorie**, kein zweites Modell, keine
Parallelstruktur in den `UserDefaults`: ein Versuch, ein Eintrag, und der
Eintrag trägt auch, was aus dem Vorschlag wurde.

**Was die Engine davon sieht.** `ReviewSignal` bekommt **nicht** beide Felder,
sondern den einen abgeleiteten Wert, den die Regel liest:

```swift
let declinedSuggestion: LearningStatus?   // gesetzt nur bei .declined
```

Abgeleitet an der Abbildungsgrenze `ReviewLog → ReviewSignal`, genau wie
`Card → CardSnapshot`. Die Annahme braucht die Regel nicht: Ein angenommener
Vorschlag hat den Status bewegt, also trägt sein Eintrag einen anderen
`previousStatus` als die Karte jetzt und fällt schon durch Regel 2 heraus. Ein
Feld, das die Engine nie liest, kommt auch nicht in die Engine — der Store ist
die Historie, nicht `ReviewSignal`.

**Nicht ins Schema gehört** der Merker, ob eine Aufnahme auf dieser Karte
möglich war (§13.5). Er entscheidet die Wiedereinstreuung **innerhalb** des
laufenden Versuchs und wird von keiner Regel später gelesen; `wasManualReveal`
trägt die Evidenzseite schon. Ein Feld, das es gibt, wird irgendwann benutzt.

**Grenze, die dazugehört:** Für Einträge aus den Phasen 11 und 12 gibt es
keine Angabe darüber, ob ein damals hervorgehobener Vorschlag angenommen oder
übergangen wurde — dort ist nur die gewählte Bewertung festgehalten. Die
Annahmequote ist also erst **ab Phase 13** messbar, nicht rückwirkend.

### 13.11 Was das kostet

Vier Folgen, alle bewusst in Kauf genommen und keine davon versteckt. Eine
fünfte stand hier zunächst als **offene Entscheidung** und ist eingelöst:
Phase 13 entfernte mit *Nochmal* und *Schwer* den letzten abwärts führenden Pfad
und verwies für die Korrektur auf §6.2 — das nie gebaut worden war. Das
Kontextmenü aus [§13.13](#1313-die-manuelle-korrektur-und-ihre-evidenzgrenze)
schließt die Lücke, also ist sie keine Folge dieser Phase mehr, sondern ihr
Bestandteil.

1. **Ohne Mikrofon bewegt sich kein Lernstand mehr von selbst.** Die einzige
   automatische positive Evidenz ist der Textvergleich. Wer in Modus A nie
   spricht oder auf einem Gerät ohne Mandarin-Erkennung lernt, bekommt nie einen
   Vorschlag — nach oben geht es dann nur über die Korrektur von Hand, nach unten
   ebenfalls. Das ist die ehrliche Konsequenz aus „keine neue Ersatzheuristik
   erfinden", und sie ist erträglich, weil es die Korrektur jetzt gibt (§13.13).
2. **Dasselbe gilt für Modus B**, dauerhaft und unabhängig vom Gerät.
3. **Die Gewichtung folgt einem Status, der sich seltener bewegt** (§3.1). Eine
   gut gelernte, aber nie gesprochene Karte behält ihr hohes Gewicht und kommt
   weiter häufig. Das ist die richtige Fehlerrichtung — sie fragt zu viel,
   nicht zu wenig —, aber es ist eine Änderung am Sessiongefühl und gehört auf
   die Geräteliste.
4. **`correctCount` wächst ab Phase 13 nicht mehr** und wird damit ein
   eingefrorenes Aggregat der Phasen 1 bis 12. Es ist in §7 über die
   Selbsteinschätzung definiert, und die gibt es im Lernflow nicht mehr — auch
   *Bestätigen* ist keine (§13.4). Das abgeleitete `accuracy` wird dadurch auf
   Dauer bedeutungslos: `reviewCount` wächst weiter, `correctCount` nicht.
   Gelesen wird es von keiner Ansicht, und die Fehlerrichtung ist unverändert
   die untertreibende — es kann nie mehr behaupten, als der Lernende gezeigt
   hat. **Ein Umbau oder eine Neuberechnung findet nicht statt:** beides wäre
   eine Änderung mit Migrationsrisiko an einem Wert, den nichts liest.

`SelfAssessment` bleibt als Typ erhalten — als Wert im Store (Historie des
alten Flows) und als Eingang von `StatusTransition`, das den Vorschlag bildet.
Die Übergangsmatrix aus §6 behält alle zwanzig
Zellen; erreichbar ist im normalen Flow nur noch die *Gut*-Spalte. Die anderen
drei bleiben stehen, weil sie die Historie erklären und weil ein
Spaced-Repetition-Ausbau (§11) sie wieder braucht.

### 13.12 Sprachausgabe und Sprachmodus

Die Phase-12-Regel „eine bewusst gestartete Sprachausgabe entwaffnet den
Session-Sprachmodus" wird **verengt: sie gilt nur, solange die Karte verdeckt
ist.**

Der Grund der Regel war, dass nie gleichzeitig gesprochen und aufgenommen
wird, und dass ein Modus, der nach dem Zuhören sofort wieder mitschneidet,
dem Lernenden die Entscheidung wegnimmt. Auf der **aufgedeckten** Karte
greift beides nicht: Die Aufnahme dieses Versuchs ist beendet, die nächste
beginnt erst nach dem Kartenwechsel, und der Kartenwechsel stoppt die
Sprachausgabe ohnehin.

Ohne diese Verengung hätte Phase 13 die Phase-12-Funktion praktisch
abgeschafft: Der Lernende landet jetzt auf **jeder** Karte im aufgedeckten
Zustand, in dem der große Lautsprecher steht — einmal die Antwort anhören
hätte den Sprachmodus jedes Mal gekostet.

**Damit wird die Reihenfolge beim Kartenwechsel tragend, und sie ist deshalb
festgeschrieben.** Weil die Sprachausgabe den Modus auf der aufgedeckten Karte
nicht mehr entwaffnet, ist diese Reihenfolge das Einzige, was verhindert, dass
ein laufender Ton und ein neues Mikrofon aufeinandertreffen. Läuft beim Tap auf
*Weiter*, *Bestätigen* oder *Ablehnen* noch eine Sprachausgabe:

```text
Weiter / Bestätigen / Ablehnen
  → Sprachausgabe stoppen
  → Kartenwechsel
  → erst danach die automatische Aufnahme der neuen Karte
```

**Niemals Sprachausgabe und Mikrofon gleichzeitig** — die Regel aus Phase 9,
unverändert. Die drei Schritte gehören an **eine** Stelle und an **einen**
Beobachter je Kartenübergang; zwei getrennte Beobachter wären der Doppelstart,
den das Phase-12-Review schon einmal gefunden hat, und ihre Reihenfolge ist
nicht zugesichert.

**Wie weit das prüfbar ist — korrigiert am 2026-09-21.** Die erste Fassung
dieses Abschnitts behauptete, die Reihenfolge sei „über `SessionSpeechState` als
Sequenz prüfbar, ohne View". **Das ist falsch, und das Testaudit hat es gefunden:**
`SessionSpeechState` kennt kein Sprachausgabe-Ereignis und keine Reihenfolge
gegenüber `speech.stop()`. Was tatsächlich gilt:

- **Prüfbar und geprüft:** „genau ein neuer Schlüssel je Kartenübergang", über
  `LearnFlow.cardCycleKey(cardID:answeredCount:)` — inklusive der
  wiedereingestreuten Karte, deren ID sich nicht ändert, und der gelöschten
  Karte (`LearnFlowTests.theCycleKeyChangesOncePerTransition`). Genau diese
  Hälfte war in Phase 12 schon einmal kaputt.
- **Nur strukturell:** dass `speech.stop()` **vor** dem Kartenwechsel läuft. Das
  steht in einem `onChange` in `LearnSessionView`, und kein Unit-Test erreicht
  einen `body`. Die Zusicherung ruht auf zwei Stellen — der ersten Anweisung
  dieses Beobachters und darauf, dass `startRecording(for:)` selbst mit
  `speech.stop()` beginnt —, sie hängt also nicht an der Anweisungsreihenfolge
  allein. Der reale Beleg gehört auf die Geräteliste.

Alles andere aus Phase 12 bleibt: Hintergrund, Audio-Unterbrechung,
technischer Fehler, dauerhaft unmögliche Erkennung und Sessionende entwaffnen
den Modus weiterhin, und ein Neustart braucht immer einen Tap.

**Und eine Genauigkeit, die das Review verlangt hat:** „Verengt" ist für die
Sprachausgabe-Regel zu freundlich. Vom Lernbildschirm aus ist der verdeckte Fall
**nicht erreichbar** — Modus A zeigt vor dem Aufdecken keinen Lautsprecher, und
Modus B, der einen zeigt, ist am Beobachter durch die Richtungsprüfung
ausgeschlossen. Die Phase-12-Regel ist damit faktisch **stillgelegt**, nicht nur
eingeschränkt. Der Fall bleibt in der Entscheidungstabelle stehen, weil er die
ehrliche Antwort wäre, sobald auf einer verdeckten Modus-A-Karte ein
Lautsprecher erschiene — ihn zu löschen würde „wir haben das entschieden" in
„daran hat niemand gedacht" verwandeln.

### 13.13 Die manuelle Korrektur und ihre Evidenzgrenze

**Die Regel schlägt nur vorsichtig nach oben vor; der Nutzer korrigiert
jederzeit, insbesondere nach unten.** Das ist die Symmetrie, die der Phase
gefehlt hat, und sie ist keine Rückkehr der Selbsteinschätzung: Sie sitzt in der
Kartenübersicht, nicht im Lernflow.

**Die Bedienung** (§6.2): ein Kontextmenü auf der Kartenzeile, *Lernstand
setzen* mit den fünf Stufen, der aktuelle markiert. Die Auswahl schreibt sofort
und persistiert sofort, ohne Bestätigungsdialog — eine Statusänderung ist einen
Tap gemacht und einen Tap zurückgenommen. Der alte Statuspicker im Karteneditor
kommt **nicht** zurück; beim Anlegen einer Karte kann ihn niemand beantworten,
und genau das war der Grund, ihn in Phase 6 zu entfernen.

**Was eine Korrektur nicht ist:** keine Lernantwort. Kein `SelfAssessment`, kein
`ReviewLog`-Eintrag, `reviewCount` und `correctCount` unverändert,
`lastReviewedAt` unverändert, keine Wiedereinstreuung. Die bestehende Historie
wird **nicht gelöscht**.

#### Die Evidenzgrenze, und warum sie nötig ist

Den Status zu setzen genügt nicht, und der Fall, der das zeigt, ist der
realistische:

```text
Karte steht auf Mittel, sammelt saubere Mittel-Reviews
  → Vorschlag Mittel → Gut, bestätigt
  → später Gut → Sicher, bestätigt
  → der Lernende widerspricht und setzt von Hand zurück auf Mittel
```

Die alten Mittel-Reviews tragen `previousStatus == medium`, sind nach der
Gleichstatus-Regel (§13.7, Regel 2) also wieder vergleichbar — und der nächste
saubere Versuch würde sofort erneut *Mittel → Gut* anbieten. Genau die
Beförderung, die der Lernende gerade zurückgenommen hat.

Deshalb setzt die Korrektur eine persistente Linie:

```swift
card.status = gewählterStatus
card.classificationEvidenceResetAt = now
try context.save()
```

Danach zählt als Evidenz **nur, was nach dieser Linie liegt** — strikt danach:
Ein Review mit demselben Zeitstempel wie die Korrektur zählt nicht, weil die
Korrektur die spätere der beiden Aussagen ist.

`nil` heißt „nie korrigiert", also ist alles zulässig. Das ist auch der Wert, den
jede vor Phase 13 geschriebene Karte zurückliest, und der einzige ehrliche.

#### Warum ein eigenes Feld, und warum es nicht in der Engine liegt

**Geprüft, ob ein vorhandenes Feld die Semantik trägt — keines tut es.**
`lastReviewedAt` bewegt sich bei *jedem* Review und würde damit auch die frischen
Versuche ausschließen, die gerade zählen sollen; `createdAt` bewegt sich nie; die
Zähler sind Zähler; die beiden `…WasEditedManually`-Merker gehören zum Text, und
sie umzudeuten wäre genau die Wiederverwendung, die dieses Projekt verbietet. Auf
`ReviewLog` ist `previousStatus` das Feld, an dem der Fall **scheitert**.

**Gelesen wird die Grenze beim Übergeben der Historie, nicht in der Regel.**
`LearnSessionModel.recentSignals` filtert, bevor es abbildet — dieselbe Stelle,
an der `windowSize` seit Phase 11 als *obere* Schranke wirkt (§12.5); die
Korrektur ist die passende *untere*. Dass der Filter vor dem Fenster läuft, ist
Lesbarkeit und **keine** tragende Eigenschaft: Zulässigkeit ist monoton in der
Zeit — zulässig heißt „neuer als die Linie" —, also liefern beide Reihenfolgen
dieselbe Menge. Eine frühere Fassung dieses Satzes behauptete etwas anderes und
lehrte damit eine Invariante, die es nicht gibt; das Review hat es gefunden.
`Learning/` bleibt damit ohne Uhr und `ReviewSignal` ohne Zeitstempel — ein
Datumsvergleich in der Regel hätte beiden einen gegeben.

#### Schema

`Card.classificationEvidenceResetAt: Date?`, additiv mit Default `nil`. Gemessen
statt angenommen: `SchemaMigrationTests.evidenceBoundaryMigratesLightly` schreibt
einen Store mit dem nachgebauten **Phase-13-Schema** (`ReviewLog` mit den zwei
Vorschlagsfeldern, `Card` ohne die Linie), öffnet dieselbe Datei mit dem
aktuellen Schema, liest jeden Wert unverändert, findet die neue Property als
`nil` — also bleibt die Historie vollständig zulässig —, benutzt sie sofort und
öffnet noch einmal zur Kontrolle. Das ist der **dritte** additive Fall, den Q7
einzeln beantwortet, statt aus zwei einen Erfahrungswert zu machen.
