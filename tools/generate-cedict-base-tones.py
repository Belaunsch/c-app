#!/usr/bin/env python3
"""Leitet die Grundtöne neutralisierter Silben aus dem gebündelten Asset ab.

## Warum es diese Datei gibt

`一个` steht in CC-CEDICT als `yi1 ge5` und wird `yíge` gesprochen: Die
`一`-Sandhi-Regel wird davon ausgelöst, was `个` **zugrunde** ist — ein vierter
Ton — und nicht vom neutralen Ton, mit dem es an die Oberfläche kommt. Diese
Information steht nirgends im Asset: `个` allein ist ein mehrdeutiges
Stichwort, also führt `cedict-readings.txt` keine Lesung dafür.

Ableitbar ist sie trotzdem, und zwar **aus demselben Asset**: Dasselbe Zeichen
erscheint in anderen Stichwörtern mit vollem Ton — `一个人` gibt `ge4`. Dieses
Skript zählt, welche Töne jede Silbe über alle reinen Han-Stichwörter hinweg
annimmt, und schreibt den vorherrschenden auf.

**Vorherrschend, nicht eindeutig**, und dieser Unterschied ist der Grund, dass
es funktioniert: `个` liest `ge4` in 86 Stichwörtern, `ge5` in 43 und `ge3` in
genau einem. Wer einen eindeutigen Vollton verlangt, bekommt für genau den Fall
keine Antwort, auf den es ankommt. Die Schwelle liegt bei neun von zehn — das
lässt die seltene Variante draußen, ohne zum Raten einzuladen.

Dazu eine **Mindestevidenz** von fünf Vorkommen. Aus dem Review: 49 Zeilen der
ersten Fassung ruhten auf ein bis drei Vorkommen, und dort kippt der
„vorherrschende Vollton" nachweislich weg vom Grundton der reduzierten Form —
`们 men → 2` stammte ausschließlich aus dem Ortsnamen 图们, nicht aus einem
Vollton des Pluralsuffixes. Die Untergrenze entfernt solche Zufallszeilen und
keinen einzigen erreichbaren Fall.

## Warum vorberechnet und nicht zur Laufzeit

Gemessen im Simulator (Debug): Der Zensus über alle Stichwörter kostet **314 ms**.
`ChineseLexicon` ist `@MainActor`, der Editor lädt in seinem `.task` — 314 ms
dort wären ein merkbares Stocken beim Öffnen des Editors und damit ein Verstoß
gegen die Performance-Vorgabe der Phase 6.5. Die Daten sind statisch, die
Ableitung deterministisch, also gehört sie in den Build und nicht in den Start.

## Lizenz

Die Ausgabe ist eine **Ableitung von CC-CEDICT** und steht damit unter
derselben Lizenz, CC BY-SA 4.0. Sie liegt deshalb im selben Ordner wie die
Quelldaten und ist in `SOURCE.md` dokumentiert. Keine neue Datenquelle: Diese
Datei enthält keine Information, die nicht schon in `cedict-readings.txt`
steckt — sie stellt sie nur so um, dass ein Nachschlagen sie findet.

Aufruf aus dem Repository-Wurzelverzeichnis:

    python3 tools/generate-cedict-base-tones.py
"""

from __future__ import annotations

import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "CApp" / "Resources" / "ThirdParty" / "CC-CEDICT"
SOURCE = DATA / "cedict-readings.txt"
TARGET = DATA / "cedict-base-tones.txt"

# Neun von zehn. Darunter wird nicht geantwortet.
DOMINANCE = 0.9
# Und mindestens fünf Vorkommen, sonst ist „vorherrschend" ein Zufall.
MINIMUM_EVIDENCE = 5


def is_han(text: str) -> bool:
    return all("一" <= character <= "鿿" for character in text)


def main() -> int:
    if not SOURCE.exists():
        print(f"Fehlt: {SOURCE}", file=sys.stderr)
        return 1

    header_version = ""
    counts: dict[tuple[str, str], dict[int, int]] = defaultdict(lambda: defaultdict(int))
    neutral: set[tuple[str, str]] = set()

    for line in SOURCE.read_text(encoding="utf-8").splitlines():
        if line.startswith("#"):
            if "CC-CEDICT Version" in line:
                header_version = line.lstrip("# ").strip()
            continue
        if "\t" not in line:
            continue
        word, reading = line.split("\t", 1)
        fields = reading.split(" ")
        characters = list(word)
        # Silbenzahl geprüft, nicht angenommen: 13 Einträge schreiben zwei
        # Silben ohne Trennzeichen (`兙` liest `shi2ke4`).
        if len(fields) != len(characters) or not is_han(word):
            continue
        for character, field in zip(characters, fields):
            if not field or not field[-1].isdigit():
                continue
            tone = int(field[-1])
            # `ü` ausgeschrieben, wie es der Konsument fragt: `PinyinSyllable`
            # expandiert `u:` zu `ü`, **bevor** es den Grundton nachschlägt.
            # Ohne diese Zeile stand `女 nu:` in der Datei und war nie
            # auffindbar — vom Review gefunden, eine Zeile betroffen.
            syllable = field[:-1].lower().replace("u:", "ü")
            if not syllable or not syllable.isalpha():
                continue
            key = (character, syllable)
            if tone == 5:
                neutral.add(key)
            elif 1 <= tone <= 4:
                counts[key][tone] += 1

    rows: list[tuple[str, str, int, int, int]] = []
    undecided = 0
    for key in sorted(neutral):
        tones = counts.get(key)
        if not tones:
            undecided += 1
            continue
        total = sum(tones.values())
        tone, best = max(tones.items(), key=lambda kv: kv[1])
        if total < MINIMUM_EVIDENCE or best / total < DOMINANCE:
            undecided += 1
            continue
        rows.append((key[0], key[1], tone, best, total))

    lines = [
        "# Grundtöne neutralisierter Silben. Ableitung aus cedict-readings.txt.",
        "# ERZEUGT von tools/generate-cedict-base-tones.py. Nicht von Hand bearbeiten.",
        f"# {header_version}" if header_version else "#",
        "# Lizenz der Daten und dieser Ableitung: CC BY-SA 4.0 — siehe SOURCE.md.",
        "#",
        "# Wozu: `一个` ist `yi1 ge5` und wird `yíge` gesprochen, weil die",
        "# `一`-Regel vom Grundton des folgenden Zeichens ausgelöst wird und",
        "# nicht vom neutralen Ton an der Oberfläche. Diese Datei sagt, welcher",
        "# Grundton das ist, wo die Daten ihn hergeben.",
        "#",
        f"# Schwelle: der vorherrschende Vollton muss {DOMINANCE:.0%} der",
        f"# Nicht-Neutral-Vorkommen halten, bei mindestens {MINIMUM_EVIDENCE}",
        "# Vorkommen. Sonst steht die Silbe nicht hier, und der Aufrufer wendet",
        "# keine Regel an.",
        "#",
        "# Spalten: Zeichen, Silbe, Grundton, Vorkommen dieses Tons, Vorkommen",
        "# aller Volltöne dieser Silbe.",
    ]
    for character, syllable, tone, best, total in rows:
        lines.append(f"{character}\t{syllable}\t{tone}\t{best}\t{total}")
    TARGET.write_text("\n".join(lines) + "\n", encoding="utf-8")

    size = TARGET.stat().st_size / 1024
    print(f"{TARGET.relative_to(ROOT)}: {len(rows)} Silben, {size:.0f} KB")
    print(f"  Silben mit Neutralton insgesamt: {len(neutral)}")
    print(f"  ohne belegbaren Grundton:        {undecided}")
    for probe in [("个", "ge"), ("子", "zi"), ("上", "shang"), ("们", "men")]:
        row = next((r for r in rows if (r[0], r[1]) == probe), None)
        if row:
            print(f"  {probe[0]} {probe[1]}: Ton {row[2]} ({row[3]} von {row[4]})")
        else:
            print(f"  {probe[0]} {probe[1]}: nicht belegbar")
    return 0


if __name__ == "__main__":
    sys.exit(main())
