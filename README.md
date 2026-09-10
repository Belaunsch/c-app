# c-app — Mandarin-Lernkarten für iOS

Private, native iOS-App zum Lernen von Mandarin-Chinesisch mit Lernkarten.
Deutsch als Ausgangssprache, Hanzi + Pinyin als Zielinhalt, Aussprache über
Text-to-Speech und Spracheingabe über die Mandarin-Spracherkennung des Systems.

## Status

**Phasen 0 bis 7 abgeschlossen.**

Vorhanden sind die Architektur- und Planungsdokumentation, die
Claude-Code-Entwicklungsinfrastruktur (`.claude/agents/`, `.claude/skills/`,
`.claude/rules/`), das Xcode-Projekt, die SwiftData-Modelle für Karten und
Tags mit einem rein lokalen `ModelContainer` — und eine nutzbare
Kartenverwaltung: Wörter und Sätze getrennt, Karten anlegen, bearbeiten und
löschen, Suche über Deutsch, Hanzi und Pinyin, Filter nach Kategorie und
Lernstatus, Kategorien umbenennen und löschen.

Build und Unit-Tests laufen grün: **389 Testfunktionen / 447 Einzelausführungen,
0 Fehlschläge, 0 Compilerwarnungen** auf einem Debug-Build von null (iPhone-17-Simulator, iOS
26.5), Release-Build von null ebenso. Jede Phase ist auf einem echten iPhone
bestätigt, die letzte am **2026-09-09**.

Neu aus den Phasen 3 und 4: Beim Anlegen einer Karte genügt der deutsche Text
— mit Return oder beim Verlassen des Feldes erzeugt die App Hanzi über Apples
Translation-Framework und daraus das Pinyin mit Tonzeichen. Beides bleibt
jederzeit editierbar, und ein von Hand korrigierter Wert wird nur nach
ausdrücklicher Nutzeraktion überschrieben — über das ↻ im jeweiligen Feld. Die
Pinyin-Erzeugung läuft komplett offline; auf dem Testgerät liegen auch die
Übersetzungsmodelle lokal, sodass die ganze Kette im Flugmodus funktioniert.

Neu aus Phase 5: Die Lernlogik selbst — Gewichtung nach Lernstand, Auswahl
von Mini-Batches, Wiedereinstreuung nicht gewusster Karten, Statusübergänge —
liegt als reine, deterministisch getestete Swift-Schicht in `CApp/Learning/`.
Sie kennt weder SwiftUI noch SwiftData, keine Uhr und keinen eigenen Zufall.

Neu aus Phase 6: Der Tab „Lernen" ist kein Platzhalter mehr. Eine Session
fragt Karten von Deutsch nach Chinesisch ab: Wort oder Satz wählen,
optional Kategorien einschränken, Karte lesen, Lösung aufdecken, selbst
einschätzen. Jede Antwort wird sofort gespeichert, der Lernstatus folgt der
Übergangsmatrix, und nicht gewusste Karten kommen innerhalb derselben Session
wieder — hinter allen Karten, die noch keinen ersten Versuch hatten. Der
Kategorienfilter verknüpft mehrere Kategorien mit **ODER** — in beiden
Bildschirmen: „üb beides" im Lernen, „zeig mir beides" in der Liste. In der
Kartenliste verengen Typ, Suche und Lernstatus weiter, die Kategorien sind
eine ODER-Gruppe darin. Keine Streaks, keine Punkte, keine Timer.

Neu aus Phase 7: **Sprachausgabe.** Ein Lautsprecher in der aufgedeckten
Lernkarte, in der Kartenliste und im Editor spricht das Chinesische — im
Editor den gerade eingegebenen, noch nicht gespeicherten Text. Gesprochen
wird immer **Hanzi**, nie Pinyin. Die Stimme wird nach Qualität gewählt
(`.premium` > `.enhanced` > `.default`); auf dem Testgerät ist das die
nachgeladene **Lili (Premium)**, ohne Premium- oder Enhanced-Stimme
**Tingting**. Sprechrate `0.45`, verstellbar erst in Phase 10. Ein neuer Tap
ersetzt die laufende Wiedergabe, es gibt keine Warteschlange und kein
automatisches Abspielen. Fehlt jede chinesische Stimme, verschwindet der
Knopf und die App erklärt einmal pro Lauf den Weg über die
iOS-Einstellungen — die erreichbare Qualität hängt am Gerätebestand.

Nach Phase 7 kam ein UX-Schritt ohne eigene Phasennummer: Die Kartenliste ist
ein **Akkordeon** — eingeklappt eine Zeile mit dem deutschen Text und dem
Lautsprecher, aufgeklappt Hanzi, Pinyin, Kategorien und ein Stift, der als
einziger den Editor öffnet. Höchstens eine Karte ist offen. Dazu fünf
Sortierungen (Datum in beide Richtungen, Deutsch A–Z und Z–A, Kategorie mit
echten Abschnitten), die gewählte bleibt über Neustarts erhalten. Mehrere
Kategorien verknüpfen mit ODER. Im Lernen stehen die Kategorien direkt auf
dem Setup-Bildschirm statt hinter einem Filterknopf, mit einem
**Alle**-Eintrag für „keine Einschränkung". Umbenennen und Löschen von Kategorien
bleibt der Kategorienverwaltung vorbehalten; anlegen kann man sie dort — sie
hat dafür jetzt ein `+` oben rechts — und weiterhin direkt im Karteneditor.

Noch nicht vorhanden: **Spracherkennung** und der Lernmodus in umgekehrter
Richtung.

Neu aus Phase 4.5: Das Pinyin kommt nicht mehr aus reiner Transliteration,
sondern aus einem gebündelten Lexikon — daher die neutralen Töne (`xièxie`,
`zǎoshang`), die ICU nicht kennt. Was das Lexikon nicht eindeutig entscheiden
kann, wird als prüfbedürftig gekennzeichnet statt geraten. Dazu eine ruhigere
Kartenansicht: kompakter Navigationstitel, Filter hinter einem Knopf,
mehrzeilige Felder für Satzkarten und keine Dauer-Erklärtexte mehr.

Neu aus Phase 6.5: Das Feld zeigt die Aussprache, die man tatsächlich sagt,
nicht die Wörterbuchschreibung. `你好` steht im Lexikon als `ni3 hao3` und
erscheint als `níhǎo`, `不对` als `búduì`, `一点` als `yìdiǎn`. Angewandt wird
nur, was obligatorisch und lokal entscheidbar ist: dritter Ton vor drittem Ton
innerhalb einer Lexikoneinheit und dort abhängig von der Verzweigung
(`展览馆` → `zhánlánguǎn`, aber `小老鼠` → `xiǎoláoshǔ`), dazu die Regeln für
`一` und `不`. Prosodisch variable Fälle bleiben in der Wörterbuchform, und
der lexikalische Neutralton wird von keiner Regel angetastet — `对不起` bleibt
`duìbuqǐ`.

Gemessen an einem Golden Corpus mit **372 Fällen** in elf Kategorien, dessen
Sollwerte aus GB/T 16159-2012, 现代汉语-Lehrmaterial und CC-CEDICT stammen und
**nicht** aus dem App-Code: **343 von 347** Fällen mit Aussprache-Erwartung
exakt getroffen. Der Wert gilt für genau diesen Corpus und ist keine Aussage
über beliebigen chinesischen Text. Vier bekannte Grenzen stehen namentlich im
Testcode und in
[docs/roadmap.md](docs/roadmap.md): `一号`, `千禧一代`, `水果酒`, `不看` — in
allen vier fehlt die entscheidende Information in den Daten, nicht im
Algorithmus.

Nächster Schritt: **Phase 8 — Lernmodus B: Chinesisches Audio → Deutsch**.

## Drittanbieter-Daten

Der App-Code und die eingebundenen Fremddaten sind getrennt, auch lizenzrechtlich.

| | App-Code | Lexikondaten |
| --- | --- | --- |
| Ort | `CApp/`, ohne `CApp/Resources/ThirdParty/` | `CApp/Resources/ThirdParty/CC-CEDICT/` |
| Herkunft | dieses Projekt | [CC-CEDICT](https://www.mdbg.net/chinese/dictionary?page=cc-cedict), Herausgeber MDBG |
| Lizenz | nicht durch die Datenlizenz berührt | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |

Die gebündelten Dateien sind **Bearbeitungen** der Originaldaten (auf
vereinfachtes Chinesisch und Aussprache reduziert) und stehen deshalb selbst
unter CC BY-SA 4.0. Der Swift-Code liest diese Daten, ist aber keine
Bearbeitung von ihnen — die ShareAlike-Pflicht greift auf ihn nicht über.
Version, Bezugsquelle, alle vorgenommenen Änderungen und das
Erzeugungsskript sind in
[SOURCE.md](CApp/Resources/ThirdParty/CC-CEDICT/SOURCE.md) dokumentiert, die
Namensnennung in
[ATTRIBUTION.md](CApp/Resources/ThirdParty/CC-CEDICT/ATTRIBUTION.md). Es
handelt sich um ein **Daten-Asset**, nicht um eine Laufzeit-Dependency: kein
Swift Package, kein SDK, kein Server.

Die Umsetzung erfolgt Phase für Phase gemäß
[docs/roadmap.md](docs/roadmap.md), mit einem Test nach jeder Phase.

## Ziel

Bestehende Sprachlern-Apps erfüllen einzelne Anforderungen, kombinieren sie
aber nicht in der gewünschten Form. Diese App soll deshalb zunächst eine
fokussierte, hochwertige Flashcard-App werden:

- strikte Trennung von **Wortkarten** und **Satzkarten**
- Karten anlegen mit minimaler Tipparbeit: deutscher Text rein, Hanzi und
  Pinyin werden automatisch erzeugt und bleiben **jederzeit editierbar**
- inhaltliche **Kategorien/Tags** getrennt vom **Lernstatus**
- zwei Abfragerichtungen: Deutsch → Chinesisch (laut sprechen) und
  chinesisches Audio → Deutsch (Hörverstehen)
- Lernsessions, die sich unbegrenzt anfühlen, intern aber in kleinen
  dynamischen Gruppen von ~7 Karten arbeiten
- gewichtete Kartenauswahl nach Lernbedarf statt starrer Stapel oder
  reinem Zufall

Ausdrücklich **nicht** Teil des Produkts: Herzen, Streaks, Zeitlimits,
Tageslimits, Gamification, Werbung, In-App-Käufe, Accounts, Analytics.

## Tech Stack

| Bereich | Entscheidung |
| --- | --- |
| Sprache | Swift |
| UI | SwiftUI |
| Persistenz | SwiftData (lokal, keine CloudKit-Synchronisation) |
| Übersetzung DE → ZH | Translation Framework (`TranslationSession`) |
| Hanzi → Pinyin | CoreFoundation-Transliteration (`CFStringTokenizer` / `CFStringTransform`) |
| Sprachausgabe | AVFoundation (`AVSpeechSynthesizer`, `zh-CN`-Stimme) |
| Spracherkennung | Speech Framework (`SpeechAnalyzer` / `SpeechTranscriber`) |
| Externe Dependencies | keine |
| Backend | keines |
| Deployment Target | **iOS 26.0** |
| Build-Toolchain | Xcode 26.x (stabil) |

Begründung des Deployment Targets und die geprüfte API-Verfügbarkeit stehen in
[docs/apple-frameworks.md](docs/apple-frameworks.md). Kurzfassung: `SpeechAnalyzer`
und `SpeechTranscriber` gibt es erst ab iOS 26.0, und der UI-freie Initializer
`TranslationSession(installedSource:target:)` ebenfalls erst ab iOS 26.0. Da die
App privat auf einem eigenen Gerät läuft, gibt es keinen Grund, ältere iOS-
Versionen zu unterstützen.

## Entwicklungsprinzipien

1. **MVP zuerst.** Kein Feature bauen, bevor die Foundation dafür nötig ist.
2. **Kleine, testbare Schritte.** Jede Roadmap-Phase endet in einem Zustand,
   der auf dem Gerät überprüfbar ist.
3. **Apple-native Lösungen bevorzugen.**
4. **Keine unnötigen Dependencies.** Aktuell null externe Pakete.
5. **Geschäftslogik unabhängig von Views.** Die Learning Engine kennt weder
   SwiftUI noch SwiftData.
6. **Learning Engine separat testbar** — reine Swift-Typen, Unit-Tests ohne
   Simulator-Abhängigkeit.
7. **Automatik ist Komfort, kein Zwang.** Übersetzung und Pinyin dürfen das
   Speichern einer Karte nie blockieren; manuelle Eingabe ist immer möglich.
8. **Keine vorzeitige Optimierung.**
9. **Keine Gamification.**
10. **Local-first.** Keine Cloud-Architektur ohne konkrete Notwendigkeit.

Bewusst *nicht* verwendet: Repository-Abstraktionen, DI-Frameworks,
Coordinator-Patterns und Drittanbieter-State-Management. SwiftUI und SwiftData
reichen für den Umfang dieser App aus. Details und Begründung in
[docs/architecture.md](docs/architecture.md).

## Dokumentation

| Dokument | Inhalt |
| --- | --- |
| [docs/roadmap.md](docs/roadmap.md) | Bootstrap-Phase B plus 11 Produktphasen (0–10) mit Ziel, Scope, Tasks, Akzeptanzkriterien, Abhängigkeiten und expliziten Nicht-Zielen |
| [docs/architecture.md](docs/architecture.md) | Ordnerstruktur, SwiftData-Modell, Schichten, Services, Fehlerbehandlung, Erweiterbarkeit |
| [docs/learning-engine.md](docs/learning-engine.md) | Spezifikation von Gewichtung, Mini-Batch-Auswahl, Queue-Verhalten und Statusübergängen |
| [docs/apple-frameworks.md](docs/apple-frameworks.md) | Geprüfte API-Verfügbarkeit, Permissions, Offline-/Online-Verhalten, offene technische Fragen, Quellen |
| [docs/claude-workflow.md](docs/claude-workflow.md) | Rollen, Phase-Workflow, Delegationsregeln und Phase-Gate für die Entwicklung mit Claude Code |
| [CLAUDE.md](CLAUDE.md) | Projektregeln und Routing zu Skills und Subagents |

## Datenschutz

Die App ist local-first konzipiert: keine Accounts, kein Login, kein eigener
Server, keine Analytics, keine Telemetrie, keine Werbung.

Zwei Einschränkungen sind dokumentiert und technisch bedingt:

- Sprachmodelle für **Übersetzung** und **Spracherkennung** werden beim ersten
  Gebrauch von Apple-Servern heruntergeladen. Das erfordert einmalig eine
  Internetverbindung; danach läuft die Verarbeitung auf dem Gerät.
- Apple gibt für `TranslationSession` an, dass API-Nutzungs- und
  Performance-Metriken erhoben werden können (Bundle-ID, Sprachpaar) — jedoch
  **keine Inhalte**.

Details in [docs/apple-frameworks.md](docs/apple-frameworks.md).
