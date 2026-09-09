# CC-CEDICT — Herkunft, Lizenz und Ableitung

Dieser Ordner enthält **Daten Dritter**, nicht Quellcode dieses Projekts.
Die Trennung ist beabsichtigt: Die Lizenz dieser Daten gilt für die Daten und
für Ableitungen daraus, **nicht** für den Swift-Code der App. Siehe
[../../../../README.md](../../../../README.md), Abschnitt „Drittanbieter-Daten“.

## Datenquelle

| | |
| --- | --- |
| Projekt | CC-CEDICT — Community maintained free Chinese-English dictionary |
| Herausgeber | MDBG |
| Bezugsquelle | <https://www.mdbg.net/chinese/dictionary?page=cc-cedict> |
| Download-Datei | `cedict_1_0_ts_utf-8_mdbg.txt.gz` |
| Direkter Download | <https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz> |
| Version | 1.0, Format `ts`, Zeichensatz UTF-8 |
| Versionsstempel der Datei | `2026-09-07T08:01:26Z` |
| Einträge in der Rohdatei | 125.009 |
| Größe der Rohdatei | 3,97 MB gepackt, 9,39 MB entpackt |
| Snapshot bezogen am | 2026-09-07 |
| Lizenz | Creative Commons Attribution-ShareAlike 4.0 International |
| Lizenztext | [LICENSE.txt](LICENSE.txt), <https://creativecommons.org/licenses/by-sa/4.0/> |
| Referenziertes Vorwerk | CEDICT — Copyright © 1997, 1998 Paul Andrew Denisowski |

## Wurden die Originaldaten verändert?

**Ja.** Die Rohdatei liegt nicht im Repository. Gebündelt werden zwei daraus
erzeugte Dateien, die weniger als ein Drittel der Rohdaten enthalten. Damit
sind diese Dateien eine **Bearbeitung** („Adapted Material“) im Sinne der
Lizenz und stehen deshalb selbst unter CC BY-SA 4.0.

Inhaltlich wurde **nichts** hinzugefügt, korrigiert oder umformuliert. Alle
Änderungen sind Auslassungen und eine Auswahlregel:

1. **Traditionelle Schreibweisen entfallen.** Die App ist auf vereinfachtes
   Chinesisch festgelegt.
2. **Englische Glossen entfallen.** Derzeit liest sie nichts. Die deutsche
   Bedeutungsauflösung bräuchte sie, ist in dieser Iteration aber bewusst
   nicht gebaut — Begründung in
   [architecture.md A24](../../../../docs/architecture.md#10-zusammenfassung-der-architekturentscheidungen).
   Sobald es einen Konsumenten gibt, ergänzt der Generator sie; die Rohdaten
   enthalten sie unverändert.
3. **Stichwörter ohne Han-Zeichen entfallen** (gemessen 59, etwa `110`, `3C`).
4. **Bei mehreren Einträgen zum selben Stichwort, die sich nur in der
   Groß-/Kleinschreibung unterscheiden, wird die klein geschriebene Lesung
   gewählt.** CC-CEDICT schreibt Eigennamen groß — `Ping2 guo3` für die Firma
   neben `ping2 guo3` für die Frucht. Für Lernkarten ist das allgemeine Wort
   der Regelfall. Existiert nur eine groß geschriebene Lesung, bleibt sie
   groß: `Bei3 jing1` soll `Běijīng` ergeben, nicht `běijīng`.
5. **Tonziffern bleiben unverändert.** Die Umwandlung in Tonzeichen macht
   `PinyinTone` in der App. So bleibt das Asset nah am Original und die
   Umwandlung eine getestete reine Funktion.

## Erzeugung der Ableitung

Reproduzierbar mit einem Aufruf, ohne weitere Werkzeuge:

```bash
curl -L -o cedict.txt.gz \
  https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz
gunzip cedict.txt.gz
python3 tools/generate-cedict-asset.py cedict.txt
```

Das Skript ist der einzige Weg, mit dem diese Dateien entstehen; sie werden
nie von Hand bearbeitet. Es ist ein Werkzeug für die Entwicklung und **nicht
Teil des App-Targets** — es liegt außerhalb von `CApp/` und wird deshalb
nicht mitgebaut.

## Die gebündelten Dateien

| Datei | Inhalt | Größe |
| --- | --- | --- |
| `cedict-readings.txt` | `Stichwort<TAB>Pinyin` für jedes vereinfachte Stichwort mit genau **einer** Lesung. 119.939 Zeilen. | 2,55 MB |
| `cedict-ambiguous.txt` | Ein Stichwort pro Zeile für jedes Stichwort mit **mehreren** Lesungen. 1.250 Zeilen. | 6 KB |
| `cedict-base-tones.txt` | Grundtöne neutralisierter Silben. 407 Zeilen. | 7 KB |
| `LICENSE.txt` | Vollständiger Lizenztext CC BY-SA 4.0. | 20 KB |

Alle Datendateien beginnen mit Kommentarzeilen, die Version, Lizenz und
Herkunft nennen, damit die Angaben auch dann mitreisen, wenn die Datei
einzeln kopiert wird.

### `cedict-base-tones.txt` — nachträglich ergänzt in Phase 6.5

Diese Datei ist eine **Ableitung zweiter Stufe**: Sie entsteht nicht aus dem
CC-CEDICT-Original, sondern aus `cedict-readings.txt` in diesem Ordner.
Erzeugt von [`tools/generate-cedict-base-tones.py`](../../../../tools/generate-cedict-base-tones.py),
und damit allein aus dem Repository reproduzierbar.

**Wozu.** `一个` steht als `yi1 ge5` und wird `yíge` gesprochen: Die
`一`-Sandhi-Regel wird davon ausgelöst, was `个` **zugrunde** ist — ein vierter
Ton —, nicht vom neutralen Ton an der Oberfläche. Diese Information steht in
`cedict-readings.txt` nicht direkt, weil `个` allein ein mehrdeutiges
Stichwort ist. Sie steckt aber darin: Dasselbe Zeichen erscheint in anderen
Stichwörtern mit vollem Ton, `一个人` gibt `ge4`.

**Wie.** Gezählt wird, welche Töne jede Silbe über alle reinen
Han-Stichwörter hinweg annimmt; aufgeschrieben wird der **vorherrschende**,
sofern er mindestens neun von zehn Nicht-Neutral-Vorkommen hält. Vorherrschend
statt eindeutig ist wesentlich: `个` liest `ge4` 86-mal, `ge5` 43-mal und
`ge3` genau einmal — wer einen eindeutigen Vollton verlangt, bekommt für den
entscheidenden Fall keine Antwort.

Dazu eine **Mindestevidenz von fünf Vorkommen**, nachträglich ergänzt: Ohne
sie ruhten 59 Zeilen auf ein bis drei Belegen, und dort kippt der
vorherrschende Vollton weg vom Grundton der reduzierten Form — `们 men` ergab
2, und das stammte ausschließlich aus dem Ortsnamen 图们, nicht aus einem
Vollton des Pluralsuffixes. Aus dem Review.

Von 538 Silben mit Neutralton-Lesung bekommen damit 407 einen Grundton; die
übrigen 131 bleiben ohne Eintrag, und die App wendet dort keine Regel an. Die
Silbe steht in der **expandierten** Schreibweise (`nü`, nicht `nu:`), weil der
Konsument sie so nachfragt — eine Zeile war deshalb unauffindbar, bis das
Review es fand.

**Warum vorberechnet.** Derselbe Zensus zur Laufzeit kostet gemessen 314 ms,
und `ChineseLexicon` liegt auf dem Main Actor. Im `.task` des Editors wäre das
ein merkbares Stocken. Die Daten sind statisch, die Ableitung deterministisch.

**Lizenz.** Ableitung von CC-CEDICT, also dieselbe Lizenz: CC BY-SA 4.0. Keine
neue Datenquelle — die Datei enthält keine Information, die nicht schon in
`cedict-readings.txt` steckt; sie stellt sie nur so um, dass ein Nachschlagen
sie findet.

## Gemessene Eigenschaften des Datenbestands

Erhoben am Snapshot vom 2026-09-07, Zahlen in
[apple-frameworks.md §10, Q6](../../../../docs/apple-frameworks.md#10-offene-technische-fragen-zu-klären-vor-der-jeweiligen-phase) fortgeführt:

- 121.189 vereinfachte Stichwörter aus 125.009 Einträgen.
- **1.250 Stichwörter (1,03 %) haben tatsächlich verschiedene Lesungen.**
  Weitere 1.881 haben mehrere Einträge, die sich aber nur in
  Groß-/Kleinschreibung oder Glosse unterscheiden und dieselbe Aussprache
  ergeben — für die Aussprache also eindeutig.
- Von den echten Mehrdeutigkeiten sind 1.249 nur ein bis drei Zeichen lang.
  Mehrzeichige Wörter, die die Segmentierung findet, sind praktisch immer
  eindeutig.
- Längstes Stichwort: 19 Zeichen. 95,3 % sind vier Zeichen oder kürzer.
- 1.218 Einträge verwenden die `u:`-Schreibweise für `ü`.
- 631 Pinyin-Silben entsprechen nicht dem Schema Buchstaben plus Tonziffer,
  fast alle davon `,` (455) und `·` (160) in Namen und Aufzählungen.
