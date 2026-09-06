---
name: apple-api-spike
description: Klärt eine offene Apple-API-Frage (Q1 bis Q7 aus docs/apple-frameworks.md) standardisiert ab — offizielle Dokumentation zuerst, dann falls nötig ein minimaler Laufzeittest — und schreibt das belegte Ergebnis mit Datum, Gerät und Quelle nach docs/apple-frameworks.md zurück.
when_to_use: Bei Anfragen wie "kläre Q1", "unterstützt Translation deutsch nach chinesisch", "welche zh-CN-Stimmen gibt es", "ab welcher iOS-Version gibt es diese API" oder wenn ein Roadmap-Task einen technischen Spike verlangt.
argument-hint: [Q-nummer oder frage]
---

# Apple-API-Spike

Ziel ist eine belegte Antwort auf **eine** abgegrenzte Frage — kein
Feature, keine Produktarchitektur. Ein Spike, der zu Produktcode wächst,
ist gescheitert.

---

## 1. Frage festnageln

`docs/apple-frameworks.md` §10 lesen und die Q-Frage im Wortlaut übernehmen.
Ist keine Q-Nummer genannt, die Frage so umformulieren, dass sie mit „ja",
„nein" oder einem konkreten Wert beantwortbar ist. Eine unscharfe Frage
liefert eine unscharfe Antwort.

Auch prüfen, ob die Frage in `docs/apple-frameworks.md` schon beantwortet
ist — dann keinen Spike durchführen, sondern das sagen.

---

## 2. Dokumentation zuerst

Vor jedem Laufzeittest die offizielle Apple-Dokumentation prüfen. Entweder
selbst über die Doku-JSON-API oder über den Subagenten
`apple-api-researcher` — Letzteren nehmen, wenn mehrere Symbole zu prüfen
sind oder die Recherche viel Ausgabe produziert.

```bash
curl -sS -A "Mozilla/5.0" \
  "https://developer.apple.com/tutorials/data/documentation/<pfad>.json"
```

`metadata.platforms[].introducedAt` liefert die exakte Verfügbarkeit.
Verfügbarkeit einzelner Initializer und Properties immer separat prüfen —
sie weicht regelmäßig von der der Klasse ab.

Primärquelle ist developer.apple.com. Sekundärquellen nur, wenn Apple die
Frage nicht beantwortet, und dann als sekundär gekennzeichnet.

---

## 3. Ergebnis klassifizieren

Genau eine der drei Kategorien:

| Kategorie | Bedeutung | Konsequenz |
| --- | --- | --- |
| **Durch Dokumentation bestätigt** | Apple beantwortet die Frage explizit | fertig, Ergebnis eintragen |
| **Nur durch Laufzeittest beantwortbar** | gerätespezifisch (installierte Modelle, Stimmen, Hardware, Sprachpaar-Verfügbarkeit) | weiter mit Schritt 4 |
| **Nicht belegt** | weder Doku noch Laufzeittest klären es jetzt | als Unsicherheit eintragen, Umgehung vorschlagen |

Eine Vermutung ist keine dieser Kategorien und wird nicht eingetragen.

---

## 4. Nur falls Laufzeittest nötig

- Den kleinstmöglichen Test definieren: ein Aufruf, dessen Ergebnis
  ausgegeben wird. Beispiele: `LanguageAvailability.status(from:to:)`
  ausgeben, `SpeechTranscriber.supportedLocales` ausgeben,
  `AVSpeechSynthesisVoice.speechVoices()` nach `zh-CN` filtern und Name
  plus Qualität ausgeben.
- Den Test im Rahmen der laufenden Phase durchführen, an einer Stelle, die
  ohnehin existiert. **Keine** eigene Debug-Ansicht, kein Spike-Target,
  keine Hilfsklasse, keine Abstraktion.
- Der Test läuft auf dem echten iPhone, nicht im Simulator, wenn es um
  installierte Modelle, Stimmen, Mikrofon oder Hardware-Anforderungen geht.
  Simulatorergebnisse für solche Fragen sind nicht aussagekräftig — das
  gehört zum Ergebnis dazu.
- Der Nutzer führt den Gerätetest aus. Sage präzise, was er starten und
  welche Ausgabe er zurückmelden soll. Erfinde kein Ergebnis und schreibe
  keins in die Doku, das du nicht gesehen hast.
- Nach dem Spike den Testcode entfernen, wenn er nicht Teil des
  Phasen-Scopes ist.

---

## 5. Ergebnis dokumentieren

In `docs/apple-frameworks.md` eintragen — sowohl im passenden
Framework-Abschnitt als auch in der Q-Tabelle in §10, deren Zeile von
offener Frage auf Ergebnis umgestellt wird.

Format des Eintrags:

```
**Q<n> — geklärt am <YYYY-MM-DD>**
Frage:     <Wortlaut>
Umgebung:  <Gerät und iOS-Version, oder "Dokumentation" wenn kein Gerätetest>
API:       <Symbol>
Ergebnis:  <beobachtetes Ergebnis, wörtlich wenn es eine Ausgabe war>
Beleg:     <URL oder "Laufzeitausgabe auf dem Gerät">
Folge:     <was das für die Architektur bedeutet>
```

Regeln:

- Datum, Gerät und iOS-Version sind Pflicht bei Laufzeitergebnissen — ein
  Ergebnis ohne Umgebung ist in einem Jahr wertlos.
- Beobachtung und Schlussfolgerung getrennt halten.
- Nie eine Vermutung als verifizierten Fakt eintragen. Bleibt etwas offen,
  bleibt die Q-Zeile offen, mit dem Vermerk, was noch fehlt.
- Fällt eine Frage negativ aus, den dokumentierten Ausweichpfad benennen
  (etwa manuelle Eingabe statt Automatik) und nicht stillschweigend eine
  Notlösung implementieren.
