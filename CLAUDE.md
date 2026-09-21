# Arbeitsanweisungen für die Entwicklung mit Claude

## Was das hier ist

Private, native iOS-App zum Lernen von Mandarin-Chinesisch (Lernkarten).
Swift, SwiftUI, SwiftData, keine externen Dependencies, kein Backend,
local-first.

**Aktueller Stand: Phasen 0–13 implementiert, Phase 13 verifiziert (READY).** Stand des Gates: **649
Testfunktionen / 707 Einzelausführungen grün** — parametrisierte Tests machen
daraus zwei Zahlen, also immer mit Einheit nennen —, 0 fehlgeschlagen, 0
Compilerdiagnosen auf einem Debug-Build von null, Release-Build von null
ebenso, dazu **zwei** unabhängige Code Reviews, **zwei** Testaudits und
**einundzwanzig Gegenmutationen, die alle greifen**.

**Die vollständige Geräteprüfung und der mehrtägige Alltagstest sind seit dem
2026-09-13 kein Gate der einzelnen Phase mehr**, sondern ein gemeinsames Gate
am Ende der Roadmap: `docs/roadmap.md` § *Finale Geräte- und
Release-Abnahme*. Ein offener Punkt „Phase-10-Gerätetest" oder
„Phase-10-Soak-Test" existiert nicht. Gezielte Gerätetests innerhalb einer
Phase bleiben erlaubt, wo sich ein hardwareabhängiger Pfad sonst nicht
belegen lässt — sie sind dann **Entwicklungsbelege**. Die Testhistorie steht
vollständig in der Roadmap und wird nicht hierher kopiert.

**Projektstatus: `Finale Roadmap-Abnahme: ausstehend`.** Das Produkt ist nicht
abgenommen, solange dieses Gate offene Punkte hat.

Seit Phase 11 gibt es die **Review-Historie** (`ReviewLog`, erste
Schemaerweiterung seit Phase 1 — Q7 ist daran gemessen und beantwortet). Die
**assistierte Bewertung** derselben Phase — zwei saubere Erstversuche sparen die
Vierfachauswahl, nach drei automatischen Reviews wird wieder gefragt — ist durch
Phase 13 **ersetzt**; was davon ersetzt ist und was weitergilt, steht einzeln in
[learning-engine.md §13.9](docs/learning-engine.md). Unverändert gültig: Ein
Mismatch senkt nie etwas, ein einzelner Treffer trägt nichts, und die
Entscheidung des Nutzers gewinnt immer. Die als Produktentscheidung
gekennzeichneten Parameter sind seit Phase 13 **zwei** — Fenstergröße und
Schwelle; das Rekalibrierungsintervall ist entfallen.

Seit Phase 12 gibt es den **Session-Sprachmodus**: Ein Mikrofon-Tap armiert
ihn, danach startet die Aufnahme auf jeder neuen Karte von selbst — **beendet
wird sie weiterhin per Tap.** Kein eigenes Endpointing, und das ist gemessen
statt vermutet (Q11): `SpeechDetector` liefert auf iOS 26.6 nichts, `isFinal`
kommt Sekunden zu spät. Genau **ein** automatischer Versuch pro Karte, sonst
entstünde nach „Nichts erkannt" eine Schleife. Hintergrund, Unterbrechung,
technischer Fehler und Sessionende entwaffnen den Modus; ein Neustart braucht
immer einen Tap. **Sprachausgabe entwaffnet ihn seit Phase 13 nur noch bei
verdeckter Karte** (A44) — und vom Lernbildschirm aus ist dieser Fall gar nicht
erreichbar, die Regel ist damit faktisch stillgelegt. Regeln in
`CApp/Features/Learn/SessionSpeechMode.swift`, Entscheidungen A37 bis A39.

Seit Phase 13 ist der **Lernflow** umgebaut. Die verdeckte Karte hat zwei
Zeilen: der Aufnahmepfad und darunter **Aufgeben** — in Modus A in *jedem*
Erkennungszustand so beschriftet, auch ohne Mikrofonfreigabe; Modus B heißt
weiter „Antwort zeigen". Läuft eine Aufnahme, steht dort `[ Fertig ][ ■ ]`: die
breite Taste schrumpft animiert nach rechts auf die Stop-Fläche. **■ verwirft**
den Versuch — keine Auswertung, kein Aufdecken, kein `ReviewLog`, kein Zähler,
und der Sprachmodus bleibt armiert (A45). *Aufgeben* übernimmt die Rolle von
„Nochmal": es streut die Karte **genau einmal** je Mini-Batch wieder ein, aber
nur, wenn eine Aufnahme möglich war — sonst würde auf einem Gerät ohne
Erkennung jeder Batch doppelt so lang (A41). Ein Mismatch streut **nicht**
wieder ein.

Nach dem Aufdecken sind die vier Bewertungstasten **weg**. Dort steht
`[ Weiter ]` oder eine Zustimmungsfrage: „Neue Einstufung — Mittel → Gut" mit
*Ablehnen* und *Bestätigen*, nie beides. **Es gibt keinen Pfad, auf dem die App
einen Status senkt.** Nach unten kommt eine Karte über die **Korrektur von Hand**
in der Kartenübersicht: Kontextmenü auf der Zeile, *Lernstand setzen*, fünf
Stufen, der aktuelle markiert. Das ist keine Lernantwort — kein `ReviewLog`,
keine Zähler, keine Wiedereinstreuung —, aber es setzt
`Card.classificationEvidenceResetAt`, damit die alten Reviews einer
zurückgesetzten Karte nicht sofort denselben Vorschlag erneut auslösen. Regel und
Begründung, warum kein vorhandenes Feld das konnte:
[learning-engine.md §13.13](docs/learning-engine.md).
`correctCount` wächst nicht mehr — auch *Bestätigen* ist keine
Selbsteinschätzung. Die Regel zählt einen Lauf nur über **vergleichbare**
Versuche: gleiche Richtung, gleicher Ausgangsstatus, Abbruch am ersten
unsauberen Versuch und an einer Ablehnung, die selbst nicht mitzählt. Damit
kann `.new` einen ersten Vorschlag bekommen (`Neu → Mittel`), und eine von Hand
auf *Neu* zurückgesetzte Karte benutzt ihre alte Evidenz nicht. Vorschlag,
Annahme und Ablehnung liegen in **zwei neuen `ReviewLog`-Feldern**
(`suggestedStatus`, `suggestionDecision`); `assessmentRaw` bedeutet weiter
ausschließlich die historische Selbsteinschätzung und wird im neuen Flow
**nie** geschrieben. Regeln und Begründungen:
[learning-engine.md §13](docs/learning-engine.md), Entscheidungen A40 bis A45.

**Q12 ist beantwortet und nichts dazu gebaut:** Die Tastatursprache lässt sich
aus einer normalen App nicht erzwingen, und SwiftUI hat dafür überhaupt keine
API. Die Einschränkung steht dokumentiert in
[apple-frameworks.md](docs/apple-frameworks.md) Q12; der Weg zum Hanzi bleibt
die Kette `Deutsch → Hanzi → Pinyin`.

**Nächster Schritt: Phase 14 — AI-Erklärung zu einer Karte.** Spezifiziert und
**gemessen** am 2026-09-21, noch nicht implementiert. Die Phase begann mit zwei
Produktfällen und endet mit einem.

**Gebaut wird:** eine kurze, deutsche, lernorientierte Erklärung zu einer
vorhandenen Karte — Bedeutung, Gebrauch, höchstens zwei Beispiele —, erreichbar
aus dem Kontextmenü der Kartenliste **und** von einer **aufgedeckten** Lernkarte,
sichtbar als erzeugt gekennzeichnet und **nicht persistiert**. Die Phase führt
deshalb **keinen einzigen Schreibzugriff** auf den Store ein: kein neues Attribut,
keine Migration, kein `ReviewLog`, keine Änderung an `Card` oder
`LearningStatus`. `Learning/` bleibt unverändert.

**Gestrichen wird der Bulk-Fall** — Kartenentwürfe aus einer Beschreibung. Er ist
an der **vor** der Messung festgelegten No-Go-Bedingung gescheitert: In 50
generierten Einträgen trugen vier eine falsche Bedeutung bei völlig unauffälligem
Hanzi (`Abbruch|结账`, `Speisekarte|菜谱`, `Toast|面包`, `Töpfe|碗`), und eine
Vorschau aus Deutsch, Hanzi und Pinyin kann das nicht sichtbar machen. **Die
Schwelle ist nach Kenntnis der Ergebnisse nicht verändert worden**, es ist kein
externer Dienst und kein Plan B an die Stelle getreten. Der Ansatz „Bulk mit
unabhängiger Bedeutungsprüfung" steht als **neu zu spezifizierende und neu zu
messende** Idee im Backlog. Die Entscheidungen P1 bis P4 sind als getroffen
dokumentiert und dem blockierten Fall zugeordnet.

Alles ausschließlich **on-device** über `SystemLanguageModel`; dass es kein Dienst
wird, folgt aus den harten Regeln 2 und 8. Q13 ist geschlossen — API-Oberfläche in
[apple-frameworks.md §11](docs/apple-frameworks.md), Gerätemessung in §12. Drei
Messbefunde prägen den Entwurf: `availability` wird **nie gecacht**,
`Locale.current` war auf dem Gerät `en_DE` (also beide Ziel-Locales **namentlich**
prüfen), und `rateLimited` trat **im Vordergrund** auf — deshalb **eine Anfrage je
Nutzeraktion** und ein echter Fehlerpfad dafür.

**Erst danach** die finale Geräte- und Release-Abnahme.

Die Kette `Deutsch → Hanzi → Pinyin` läuft mit Return oder beim Verlassen des
Feldes automatisch, beide Werte bleiben editierbar, und ein von Hand gesetzter
Wert wird nur nach ausdrücklicher Nutzeraktion überschrieben — über das ↻ im
jeweiligen Feld. Die ganze Kette funktioniert offline.

Pinyin kommt primär aus gebündelten CC-CEDICT-Daten (`ChineseLexicon`,
`PinyinTone`), ICU liefert nur noch die Wortgrenzen und den gekennzeichneten
Fallback. Ein nicht eindeutig auflösbares Pinyin wird **nicht geraten**,
sondern als prüfbedürftig markiert und im Editor benannt.

Seit Phase 6.5 zeigt das Feld die **Lernaussprache** statt der
Wörterbuchschreibung: `不对` → `búduì`, `一点` → `yìdiǎn`, `你好` → `níhǎo`.
Die lexikalische Lesung und der gesprochene Ton sind getrennte Werte
(`PinyinSyllable`), `ToneSandhi` ist eine reine Foundation-Schicht, und
angewandt wird nur, was obligatorisch und lokal entscheidbar ist — Details und
Begründung in A28 bis A30. Gemessen an einem Golden Corpus mit 372 Fällen:
343 von 347 exakt. Vier bekannte Grenzen stehen namentlich in
`PinyinCorpusTests.knownFailures`; in allen vier fehlt die Information in den
Daten, nicht im Algorithmus.

Die Lernlogik liegt als reine, getestete Foundation-Schicht in
`CApp/Learning/` — Gewichtung, gewichtete Auswahl ohne Zurücklegen, Queue mit
Wiedereinstreuung, Statusübergänge. Sie kennt keine `Card`, keinen
`ModelContext` und keine Uhr; Zufall wird hereingereicht. Q8 ist geschlossen
(Target behält `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, reine Typen sind
einzeln `nonisolated`).

Darüber liegt seit Phase 6 der Lernmodus A in `CApp/Features/Learn/`:
Session-Setup, Abfrage, Selbsteinschätzung, Rückschreiben nach SwiftData nach
**jeder** Antwort. Die Kategorien stehen im Setup seit A33 als direkte
Auswahl statt hinter einem Filterknopf — mehrere ergeben die **Vereinigung**,
keine Auswahl heißt „alle", dargestellt durch einen Alle-Eintrag. Die
Kartenliste verknüpft seit A32 ebenfalls mit **ODER**; die frühere
UND-Semantik der Liste (A12, A26) ist überholt. Dort verengen Typ, Suche und
Status weiter, die Kategorien sind eine ODER-Gruppe innerhalb dieser
UND-Kette.

Seit Phase 7 gibt es **Sprachausgabe**: ein Lautsprecher in der Lernkarte, in
der Kartenliste und im Editor, dort auf dem noch nicht gespeicherten Text. Der Synthesizer bekommt immer **Hanzi**, nie Pinyin
(A31); `SpeechSynthesisService` hält genau eine `AVSpeechSynthesizer`-Instanz
und ihren Delegate für die App-Laufzeit und wird über die Environment
verteilt. Die Stimme wird nach Qualität gewählt — `.premium` > `.enhanced` >
`.default`, innerhalb einer Klasse ein deterministischer Identifier-Tiebreak.
Auf dem Testgerät ergibt das die nachgeladene **Lili (Premium)**, ohne
Premium- oder Enhanced-Stimme **Tingting** als getesteten Fallback; einen
Sonderfall auf einen Stimmennamen gibt es nicht. Rate `0.45` (gemessen gegen
`0.40` und `0.50`), Session `.playback` + `.voicePrompt`. Ein neuer Tap
ersetzt die laufende Wiedergabe, es gibt keine Warteschlange, kein Autoplay
und keinen Interruption-Observer. Bekannte Grenze: Die erreichbare Qualität
hängt am Gerätebestand — die App lädt keine Stimmen nach. Beide Messrunden
stehen in [apple-frameworks.md](docs/apple-frameworks.md) unter Q5.

Seit Phase 8 gibt es **Lernmodus B: chinesisches Audio → Deutsch**. Die
Richtung ist ein Wert in `SessionConfiguration` (`SessionDirection`, Standard
`.germanToChinese`) und wird im Setup gewählt; sie ist **reine Präsentation**
— nichts unter `Learning/` liest die Konfiguration, also erreicht sie
Gewichtung, Batch, Queue und Statusübergänge nicht. Drei Stufen: nur Audio,
dann auf Wunsch das **Hanzi allein** ohne die Bedeutung, dann die volle
Antwort, die als einzige die Selbsteinschätzung freigibt. Kein Autoplay. Der
Phase-7-TTS-Service wird unverändert wiederverwendet; laufende Sprache stoppt
beim Kartenwechsel. Der vollständig aufgedeckte Zustand ist in beiden
Richtungen dieselbe `LearnRevealedAnswerView` (A34).

Seit Phase 9 gibt es **Spracherkennung**, ausschließlich in Modus A und
ausschließlich optional. `SpeechRecognitionService` kapselt die gesamte
Apple-Integration: Locale-Auflösung mit **Validierung** auf `zh`/`Hans`/`CN`
(Apples Near-Equivalence-Regel nennt Script nicht und darf ein `zh_TW`
liefern), Asset-Bereitschaft über `AssetInventory.status(forModules:)` für
genau die benutzte Modulkonfiguration — nie über `installedLocales` und nie
gecacht —, Mikrofon über `AVAudioEngine`, Konvertierung auf das zur Laufzeit
gelesene `bestAvailableAudioFormat`, dann `SpeechAnalyzer`. Verglichen wird
allein über `AnswerNormalization`.

**Der Wortlaut ist die Regel:** Ein Treffer heißt **„Erkannt wie erwartet"** —
Apples finaler Text entspricht nach der Normalisierung dem gespeicherten
Hanzi. Nie „richtig ausgesprochen", nie „Töne korrekt", kein Score, kein
Prozentwert, keine Konfidenz (harte Regel 7). Ursprünglich stand dort „Antwort
wahrscheinlich korrekt"; der Phase-9-Benchmark hat dieser Aussage den Boden
entzogen — 8 von 16 normal gesprochenen Zielantworten wurden als anderer Text
erkannt. Die Schwelle wurde **nicht** gelockert, die Behauptung reduziert.
Erkennung verändert **niemals** den Lernstand; die Selbsteinschätzung bleibt
die einzige Bewertung. `CApp/Learning/` ist in dieser Phase vollständig
unverändert geblieben.

Seit Phase 10 gibt es **Einstellungen** hinter dem Zahnrad der
Kartenübersicht: Sprechtempo in drei gemessenen Stufen, Stimmenauswahl ab
zwei installierten Mandarin-Stimmen, Kartenzahl je Runde zwischen 5 und 10,
Verwaltung des Erkennungsmodells und die Kartenzahl je Lernstand. Gespeicherte
Werte werden **beim Lesen** geklemmt, nicht am Bedienelement (`Preferences`);
die Batchgröße erreicht Auswahl **und** Recency-Schwelle und wird nur am
Batchstart gelesen. Dazu App-Icon, Fehler-Audit als Matrix in
[architecture.md §7](docs/architecture.md#7-fehlerbehandlung), Leer- und
Ladezustände, VoiceOver-Sprachauszeichnung über `ChineseText` und Dynamic Type
für die chinesischen Texte.

Für Phase 11 ist vorgemerkt, dass mehrere wiederholte
Treffer als *potenzielle* positive Evidenz in eine Statusschätzung eingehen
könnten — ein Mismatch dagegen ist **keine** sichere negative Evidenz, und
die False-Accept-Eigenschaft ist nicht gemessen.

Drittanbieter-Daten liegen ausschließlich in
`CApp/Resources/ThirdParty/CC-CEDICT/` und stehen unter CC BY-SA 4.0; die
Lizenz gilt für die Daten und ihre Ableitungen, **nicht** für den App-Code.
Herkunft, Version und Änderungen sind dort in `SOURCE.md` dokumentiert. Neue
Fremddaten gehören in denselben Ordner mit derselben Dokumentation.

## Vor jeder Änderung lesen

| Frage | Dokument |
| --- | --- |
| Was ist als Nächstes zu tun? | [docs/roadmap.md](docs/roadmap.md) |
| Wo gehört mein Code hin? | [docs/architecture.md](docs/architecture.md) |
| Wie funktioniert die Lernlogik genau? | [docs/learning-engine.md](docs/learning-engine.md) |
| Ab welcher iOS-Version gibt es diese API? Was ist unklar? | [docs/apple-frameworks.md](docs/apple-frameworks.md) |
| Wie arbeiten wir, wer darf was? | [docs/claude-workflow.md](docs/claude-workflow.md) |

## Routing

| Aufgabe | Weg |
| --- | --- |
| Normale Feature-Implementierung | Skill `/implement-phase` |
| Abschlussprüfung einer Phase | Skill `/verify-phase` |
| Apple-API- oder Verfügbarkeitsfrage | Skill `/apple-api-spike`, für Einzelfragen Subagent `apple-api-researcher` |
| Unabhängiges Code Review | Subagent `code-reviewer` |
| Unabhängige Test- und Acceptance-Prüfung | Subagent `test-auditor` |

Produktivcode schreibt **immer der Hauptagent**, nie ein Subagent. Die drei
Subagenten prüfen und recherchieren; sie ändern keine Dateien. Details und
Begründung in [docs/claude-workflow.md](docs/claude-workflow.md).

## Harte Regeln

1. **Eine Phase auf einmal.** Der Umfang steht in der Roadmap. Nichts aus
   einer späteren Phase vorziehen — auch nicht „weil es gerade schnell geht“.
2. **Keine externen Dependencies.** Kein Swift Package, kein CocoaPods, kein
   Carthage, kein Laufzeit-SDK, kein Backend. Ein **lizenzkonformes
   Daten-Asset** ist dagegen erlaubt — siehe `CApp/Resources/ThirdParty/` —
   sofern Quelle, Lizenz, Version und alle Änderungen dokumentiert sind und
   die Datenlizenz vom App-Code getrennt bleibt. Wenn etwas ohne Paket nicht
   lösbar erscheint, erst fragen.
3. **Keine Repository-Layer, keine DI-Container, keine Coordinator, kein
   Drittanbieter-State-Management.** Begründung in
   [architecture.md §1](docs/architecture.md#1-schichten).
4. **`Learning/` importiert nur `Foundation`.** Kein SwiftUI, kein SwiftData.
   Detailregeln der Schicht: `.claude/rules/learning-layer.md` (lädt
   automatisch beim Arbeiten an diesen Dateien).
5. **Automatik blockiert nie.** Übersetzung und Pinyin sind Vorschläge.
   Eine Karte muss sich immer speichern lassen, auch wenn beides fehlschlägt.
   Manuell geänderte Werte werden nie automatisch überschrieben.
6. **Keine Gamification.** Keine Streaks, Herzen, Timer, Tageslimits,
   Punktzahlen. Auch nicht „nur als kleines Extra“.
7. **Keine Aussprachebewertung behaupten.** Der Vergleich in Version 1 ist
   rein textuell. Kein Score, keine Prozentangabe, kein Ton-Feedback.
8. **Keine Analytics, keine Telemetrie, kein Crash-Reporting, kein Login,
   kein Server.**
9. **Unsicherheiten dokumentieren statt raten.** Offene technische Fragen
   gehören als Q-Eintrag in
   [apple-frameworks.md §10](docs/apple-frameworks.md#10-offene-technische-fragen-zu-klären-vor-der-jeweiligen-phase).
10. **Am Ende jeder Phase:** Akzeptanzkriterien durchgehen, Tests laufen
    lassen, Review durchführen lassen, auf dem echten Gerät prüfen. Ein
    grüner Testlauf allein ist kein Phasenabschluss. Vollständiges
    Phase-Gate: [docs/claude-workflow.md §5](docs/claude-workflow.md#5-phase-gate).
    Erst danach die nächste Phase.

## Konventionen

- **Swift-Code, Typnamen und Code-Kommentare auf Englisch** (Swift-üblich).
  Das gilt auch für Doc-Comments und Testtitel.
- **Projektdokumentation und alle nutzersichtbaren Texte auf Deutsch.**

  **Bekannte Abweichung (Stand Phase 1):** Der in Phase 0 und 1 geschriebene
  Swift-Code enthält deutsche Kommentare, Doc-Comments und Testtitel — rund
  120 von etwa 240 Kommentarzeilen in 12 von 13 Dateien. Diese Dateien werden
  **nicht** rückwirkend übersetzt; der Aufwand stünde in keinem Verhältnis
  zum Nutzen. Die Regel gilt für **neu geschriebenen** Swift-Code ab Phase 2.
  Bestehende deutsche Kommentare bleiben stehen, bis die betroffene Datei aus
  fachlichem Grund ohnehin umgeschrieben wird — kein Übersetzen um des
  Übersetzens willen.
- Deployment Target **iOS 26.0**, nur iPhone, Portrait.
- Fehlerbehandlung: kein `try!`, keine leeren `catch {}`. Für
  nutzersichtbare Fehler `AppError` in `Support/` verwenden.
- Tests für alles unter `Learning/` und für `PinyinService` sind Pflicht,
  nicht optional.

## Build und Test

Entwickelt wird in VS Code, gebaut und auf dem Gerät gestartet wird mit Xcode.

```bash
xcodebuild -scheme CApp -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme CApp -destination 'platform=iOS Simulator,name=iPhone 17' test
```

**Voraussetzung einmalig:** Die Xcode-Lizenz muss akzeptiert sein, sonst
verweigern `git` und `xcodebuild` den Dienst:

```bash
sudo xcodebuild -license accept
```

Neue Dateien werden in VS Code angelegt; durch die *synchronisierten Ordner*
(Xcode 16+) landen sie automatisch im Target — `project.pbxproj` muss nicht
angefasst werden.
