#!/usr/bin/env python3
"""Erzeugt aus der CC-CEDICT-Rohdatei die beiden Assets, die die App bündelt.

Aufruf:

    python3 tools/generate-cedict-asset.py <pfad/zu/cedict_1_0_ts_utf-8_mdbg.txt>

Die Rohdatei selbst wird **nicht** ins Repository gelegt (9,4 MB, davon
braucht die App weniger als ein Drittel). Bezugsquelle, Lizenz und Version
stehen in CApp/Resources/ThirdParty/CC-CEDICT/SOURCE.md.

Erzeugt werden:

* `cedict-readings.txt` — `Stichwort<TAB>Pinyin` für jedes vereinfachte
  Stichwort mit **einer** Lesung. Pinyin bleibt in der CC-CEDICT-Schreibweise
  mit Tonziffern; die Umwandlung in Tonzeichen macht `PinyinTone` in der App,
  damit sie eine getestete reine Funktion bleibt und das Asset nah am
  Original.
* `cedict-ambiguous.txt` — ein Stichwort pro Zeile, für jedes Stichwort mit
  **mehreren** Lesungen. Der Resolver erkennt daran, dass er die Lesung nicht
  aus dem Lexikon allein entscheiden darf.

Warum keine Glossen im Asset: Nichts liest sie derzeit. Die deutsche
Bedeutungsauflösung würde englische Glossen brauchen und ist in dieser
Iteration bewusst nicht gebaut (Begründung in docs/architecture.md, A24).
Sobald es einen Konsumenten gibt, ergänzt dieses Skript sie — die Rohdaten
enthalten sie.

Bewusste Reduktionen gegenüber der Rohdatei, alle in SOURCE.md dokumentiert:

1. Traditionelle Schreibweisen entfallen. Die App ist auf vereinfachtes
   Chinesisch festgelegt.
2. Englische Glossen entfallen, siehe oben.
3. Stichwörter ohne Han-Zeichen entfallen (gemessen 59, etwa "110" oder "3C").
4. Bei Einträgen, die sich nur in der Groß-/Kleinschreibung unterscheiden —
   CC-CEDICT schreibt Eigennamen groß, etwa `Ping2 guo3` für die Firma neben
   `ping2 guo3` für die Frucht — wird die klein geschriebene Lesung
   bevorzugt. Existiert nur eine groß geschriebene, bleibt sie groß:
   `Bei3 jing1` soll `Běijīng` ergeben.
"""

import re
import sys
from pathlib import Path

ENTRY = re.compile(r"^(\S+) (\S+) \[([^\]]*)\] /(.*)/$")
META = re.compile(r"^#! (\w+)=(.*)$")

# Han-Bereiche, die als Stichwort in Frage kommen. Bewusst grob: es geht nur
# darum, Einträge wie "110" oder "3C" auszusortieren.
HAN_RANGES = ((0x3400, 0x9FFF), (0xF900, 0xFAFF), (0x20000, 0x3FFFF))


def contains_han(text: str) -> bool:
    return any(any(lo <= ord(c) <= hi for lo, hi in HAN_RANGES) for c in text)


def normalized(pinyin: str) -> str:
    """Vergleichsform: Groß-/Kleinschreibung und Mehrfachabstände egal."""
    return " ".join(pinyin.lower().split())


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2

    source = Path(sys.argv[1])
    target = Path(__file__).resolve().parent.parent / "CApp/Resources/ThirdParty/CC-CEDICT"
    target.mkdir(parents=True, exist_ok=True)

    meta: dict[str, str] = {}
    by_word: dict[str, list[str]] = {}
    skipped_non_han = 0
    unparsed = 0

    with source.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line.startswith("#"):
                if found := META.match(line):
                    meta[found.group(1)] = found.group(2)
                continue
            entry = ENTRY.match(line)
            if not entry:
                unparsed += 1
                continue
            _, simplified, pinyin, _ = entry.groups()
            if not contains_han(simplified):
                skipped_non_han += 1
                continue
            by_word.setdefault(simplified, []).append(pinyin)

    if unparsed:
        print(f"Warnung: {unparsed} Zeilen entsprachen nicht dem Eintragsformat")

    readings: dict[str, str] = {}
    ambiguous: list[str] = []
    for word, pinyins in by_word.items():
        if len({normalized(p) for p in pinyins}) > 1:
            ambiguous.append(word)
            continue
        # Nur Groß-/Kleinschreibung unterscheidet die Einträge: die
        # klein geschriebene Lesung ist die des allgemeinen Wortes.
        readings[word] = min(pinyins, key=lambda p: (sum(c.isupper() for c in p), p))

    header = [
        "# Abgeleitet aus CC-CEDICT. Nicht von Hand bearbeiten.",
        "# Erzeugt von tools/generate-cedict-asset.py",
        f"# CC-CEDICT Version {meta.get('version', '?')}.{meta.get('subversion', '?')}"
        f", Stand {meta.get('date', '?')}, {meta.get('entries', '?')} Einträge",
        "# Lizenz der Daten und dieser Ableitung: CC BY-SA 4.0",
        "# https://creativecommons.org/licenses/by-sa/4.0/",
        "# Herkunft, Umfang der Änderungen und Erzeugung: siehe SOURCE.md",
    ]

    readings_path = target / "cedict-readings.txt"
    with readings_path.open("w", encoding="utf-8") as out:
        out.write("\n".join(header) + "\n")
        for word in sorted(readings):
            out.write(f"{word}\t{readings[word]}\n")

    ambiguous_path = target / "cedict-ambiguous.txt"
    with ambiguous_path.open("w", encoding="utf-8") as out:
        out.write("\n".join(header) + "\n")
        for word in sorted(ambiguous):
            out.write(f"{word}\n")

    longest = max(len(w) for w in readings)
    print(f"CC-CEDICT {meta.get('version')}.{meta.get('subversion')} vom {meta.get('date')}")
    print(f"  Rohdatei          {source.stat().st_size / 1024 / 1024:6.2f} MB")
    print(f"  Stichwörter       {len(by_word)}")
    print(f"  ohne Han-Zeichen  {skipped_non_han} übersprungen")
    print(f"  eindeutig         {len(readings)}  -> {readings_path.name}"
          f" ({readings_path.stat().st_size / 1024 / 1024:.2f} MB)")
    print(f"  mehrdeutig        {len(ambiguous)}  -> {ambiguous_path.name}"
          f" ({ambiguous_path.stat().st_size / 1024:.0f} KB)")
    print(f"  längstes Stichwort {longest} Zeichen")
    return 0


if __name__ == "__main__":
    sys.exit(main())
