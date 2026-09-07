# Technische Prüfung: Apple Frameworks

Stand der Prüfung: **6. September 2026**

Dieses Dokument hält fest, welche Apple-APIs für die App vorgesehen sind, ab
welcher iOS-Version sie verfügbar sind, welche Berechtigungen und
Netzwerkzugriffe sie benötigen — und welche Punkte **noch offen** sind.

Grundregel für dieses Dokument: Was nicht aus der offiziellen Apple-
Dokumentation belegt ist, wird als Unsicherheit markiert statt geraten.

---

## 1. Entscheidung: Deployment Target iOS 26.0

**Deployment Target: iOS 26.0. Build mit Xcode 26.x (stabile Version).**

Begründung:

- `SpeechAnalyzer`, `SpeechTranscriber`, `DictationTranscriber` und
  `AssetInventory` sind **erst ab iOS 26.0** verfügbar. Die moderne
  Spracherkennung ist damit an iOS 26 gebunden.
- Der UI-freie Initializer `TranslationSession(installedSource:target:)` ist
  ebenfalls **erst ab iOS 26.0** verfügbar. Auf iOS 18–25 lässt sich eine
  Übersetzungssession nur über den SwiftUI-Modifier `.translationTask()`
  erzeugen. Ab iOS 26 haben wir beide Wege — das vereinfacht die Architektur
  der Übersetzungsschicht erheblich.
- Die App ist privat und läuft auf einem eigenen, aktuellen iPhone. Es gibt
  keinen Grund, ältere iOS-Versionen zu unterstützen.

Zu iOS 27: iOS 27 war am Prüfungsstichtag noch nicht als finale Version
verfügbar (erwartet um den 14. September 2026); Xcode 27 lag als Beta vor.
Für die geplanten Features bringt iOS 27 nach aktueller Kenntnis **keine
zwingend benötigte API**. Empfehlung: auf iOS 26.0 als Target und der stabilen
Xcode-26-Toolchain bleiben und iOS 27 später neu bewerten.

---

## 2. Übersicht

| Framework / API | Verfügbar ab | Zweck in der App | Netzwerk | Berechtigung |
| --- | --- | --- | --- | --- |
| SwiftData (`@Model`, `ModelContainer`) | iOS 17.0 | lokale Persistenz der Karten und Tags | nein | keine |
| `Translation.TranslationSession` | iOS 18.0 | Deutsch → Chinesisch | nur Modell-Download | keine (System-Dialog beim Download) |
| `TranslationSession(installedSource:target:)` | **iOS 26.0** | Übersetzen ohne View-Bindung | nein | keine |
| `Translation.LanguageAvailability` | iOS 18.0 | Prüfen, ob Sprachpaar unterstützt/installiert ist | nein | keine |
| `Speech.SpeechAnalyzer` | **iOS 26.0** | Session-Verwaltung für Audioanalyse | nein | Mikrofon (+ ggf. Spracherkennung, s. u.) |
| `Speech.SpeechTranscriber` | **iOS 26.0** | Mandarin-Spracherkennung | nur Modell-Download | wie oben |
| `Speech.DictationTranscriber` | **iOS 26.0** | Fallback auf älterer/schwächerer Hardware | ggf. | wie oben |
| `Speech.AssetInventory` | **iOS 26.0** | Download/Reservierung der Sprachmodelle | ja (Download) | keine |
| `Speech.SFSpeechRecognizer` | iOS 10.0 | Legacy-Fallback, nur falls nötig | teils ja | Spracherkennung + Mikrofon |
| `AVFoundation.AVSpeechSynthesizer` | iOS 7.0 | Mandarin-Sprachausgabe | nein | keine |
| `AVSpeechSynthesisVoice.speechVoices()` | iOS 7.0 | verfügbare `zh-CN`-Stimmen ermitteln | nein | keine |
| `CoreFoundation.CFStringTransform` / `CFStringTokenizer` | seit langem | Hanzi → Pinyin mit Tonzeichen | nein | keine |

---

## 3. SwiftData

- Verfügbar ab **iOS 17.0**, `@Model` konvertiert eine Swift-Klasse in ein
  persistiertes Modell; `ModelContext` für Einfügen/Ändern/Löschen; `@Query`
  für das Laden in SwiftUI-Views.
- Läuft vollständig lokal. Keine CloudKit-Synchronisation vorgesehen — der
  `ModelContainer` wird ohne CloudKit-Konfiguration erstellt.
- Kein Netzwerkzugriff, keine Berechtigung.

Praktische Hinweise für die Umsetzung (Erfahrungswerte, in Phase 1 zu
verifizieren):

- Enums als gespeicherte Properties benötigen `Codable`-Konformität
  (`RawRepresentable` mit `String`/`Int` als RawValue funktioniert).
- Für Suche/Filter über größere Kartenmengen lohnt sich `#Index`; das ist
  aber eine Optimierung und gehört **nicht** in Phase 1.
- Migrationen: Solange die App privat ist und die Kartenmenge klein bleibt,
  genügt zunächst die automatische leichtgewichtige Migration. Ein
  `VersionedSchema`/`SchemaMigrationPlan` wird erst eingeführt, wenn eine
  Änderung das erzwingt (siehe Roadmap Phase 1).

---

## 4. Translation Framework (Deutsch → Chinesisch)

### Belegte Fakten

- `TranslationSession` ist eine Klasse, die Übersetzungen zwischen einem
  Sprachpaar durchführt, verfügbar ab **iOS 18.0** / macOS 15.0.
- Es gibt **zwei Wege**, eine Session zu bekommen:
  1. über den SwiftUI-Modifier `.translationTask()` an einer View — die
     Session wird der Action-Closure übergeben;
  2. über den direkten Initializer `TranslationSession(installedSource:target:)`
     — **ab iOS 26.0**. Dieser Weg braucht keine View, erfordert aber, dass
     die Sprachen **bereits auf dem Gerät installiert** sind, und benötigt
     eine explizit gesetzte `sourceLanguage`.
- Sind die Sprachen nicht installiert, wirft der direkte Weg einen Fehler.
  Um die Zustimmung des Nutzers für den Download einzuholen, muss über
  `.translationTask()` übersetzt werden — das System zeigt Download-Dialog
  und Fortschritt selbst an.
- Die Übersetzung selbst läuft mit On-Device-ML-Modellen, die systemweit mit
  allen Apps und der Übersetzen-App geteilt werden.
- Apple-Hinweis wörtlich in der Dokumentation: alle Übersetzungen über
  `TranslationSession` werden auf dem Gerät verarbeitet; Apple kann
  API-Nutzungs- und Performance-Metriken erheben, einschließlich Bundle-ID
  sowie Ausgangs- und Zielsprache — **jedoch nicht die Inhalte**.
- `LanguageAvailability.status(from:to:)` (ab iOS 18.0) prüft, ob die nötigen
  Sprachressourcen installiert und einsatzbereit sind.
- Das Framework unterstützt **nicht**, von einer Sprache in dieselbe Sprache
  zu übersetzen.

### Konsequenz für die Architektur

Weil der Download-Flow nur über `.translationTask()` läuft, braucht der
Karten-Editor eine kleine, unsichtbare Host-View, die eine
`TranslationSession.Configuration` hält. Der reguläre Übersetzungsaufruf nutzt
danach den direkten Initializer. Details in
[architecture.md](architecture.md#translationservice).

### Offene Punkte

- **Ist das Paar `de` → `zh-Hans` unterstützt?** Deutsch und Chinesisch
  (Simplified) sind beide Sprachen des Apple-Übersetzungsstacks, aber ob
  dieses *konkrete Paar* im Translation Framework direkt verfügbar ist, ist
  aus der Dokumentation nicht belegt. **Muss zur Laufzeit mit
  `LanguageAvailability.status(from:to:)` auf dem Zielgerät geprüft werden**
  (Roadmap Phase 4, Task 4.1 — Spike vor allem Weiteren).
- Falls das Paar nicht direkt unterstützt wird, ist ein Pivot über Englisch
  (`de` → `en` → `zh-Hans`) technisch möglich, verschlechtert aber die
  Qualität merkbar. Diese Variante wird nur als dokumentierter Notfallpfad
  geführt, nicht als Default.
- Qualität der Übersetzung bei **Sätzen** ist unbekannt. Genau deshalb ist die
  Editierbarkeit von Hanzi und Pinyin eine harte Anforderung und kein
  Komfortfeature.

---

## 5. Hanzi → Pinyin mit Tonzeichen

Es gibt in iOS **keine dedizierte Pinyin-API**. Verfügbar ist die
ICU-basierte Transliteration von CoreFoundation:

- **Primärer Ansatz:** `CFStringTokenizer` mit
  `kCFStringTokenizerUnitWordBoundary` und dem Token-Attribut
  `kCFStringTokenizerAttributeLatinTranscription`. Das liefert eine
  **wortweise segmentierte** lateinische Transkription — für Chinesisch also
  Pinyin mit Tonzeichen und sinnvollen Wortgrenzen (`苹果` → `píngguǒ` statt
  `píng guǒ`).
- **Fallback:** `CFStringTransform(str, nil, kCFStringTransformMandarinLatin, false)`
  über den gesamten String. Liefert Pinyin mit Tonzeichen, trennt aber
  silbenweise und ohne Wortsegmentierung.
- Optional lassen sich Tonzeichen mit `kCFStringTransformStripDiacritics`
  entfernen — für diese App **nicht** gewünscht, Tonzeichen sind Pflicht.

Beides läuft vollständig offline, ohne Berechtigung und ohne Netzwerkzugriff.

### Bekannte Grenzen (dokumentierte Unsicherheit)

- **Polyphone Zeichen (多音字)** werden nicht immer korrekt aufgelöst, z. B.
  `行` (xíng/háng), `长` (cháng/zhǎng), `得` (dé/de/děi), `了` (le/liǎo).
  Die Wortsegmentierung über `CFStringTokenizer` verbessert das, garantiert
  aber keine Korrektheit.
- **Tonsandhi** (z. B. bei `不` und `一`) wird in Pinyin üblicherweise
  ohnehin nicht geschrieben — hier also kein Problem, aber erwähnt, damit
  es nicht als Fehler interpretiert wird.
- Der neutrale Ton wird nicht immer erwartungskonform gesetzt.
- ICU-Transliterationstabellen können sich zwischen iOS-Versionen ändern. Die
  Ausgabe ist damit **nicht über Versionen hinweg garantiert stabil**.

**Konsequenz:** Das Pinyin-Feld ist immer editierbar, und ein manuell
korrigierter Wert wird niemals automatisch überschrieben. Siehe
[learning-engine.md](learning-engine.md) und Roadmap Phase 3.

---

## 6. Sprachausgabe (Mandarin TTS)

- `AVSpeechSynthesizer` (ab iOS 7.0) spricht eine `AVSpeechUtterance`. Die
  Stimme wird über `AVSpeechUtterance.voice` gesetzt.
- Verfügbare Stimmen liefert `AVSpeechSynthesisVoice.speechVoices()`; jede
  Stimme kennt ihre `language` und `quality`.
- Apple-Hinweis: Der Synthesizer wird vom System **nicht automatisch
  retained** — die Instanz muss so lange gehalten werden, bis die Ausgabe
  beendet ist. Das ist eine klassische Fehlerquelle (Ausgabe bricht sofort
  ab) und deshalb hier explizit notiert.
- Kein Netzwerkzugriff, keine Berechtigung.

### Vorgehen

Nicht blind `AVSpeechSynthesisVoice(language: "zh-CN")` verwenden, sondern
`speechVoices()` nach `zh-CN` filtern und die beste verfügbare Qualität
auswählen (`.premium` > `.enhanced` > `.default`).

### Offene Punkte

- Welche `zh-CN`-Stimmen auf dem Zielgerät tatsächlich vorhanden sind, ist
  gerätespezifisch. Hochwertige Stimmen müssen vom Nutzer manuell unter
  *Einstellungen → Bedienungshilfen → Gesprochene Inhalte → Stimmen*
  geladen werden; eine Kompaktstimme ist üblicherweise vorinstalliert.
  → Die App muss die vorhandenen Stimmen prüfen und, falls nur eine
  Kompaktstimme vorliegt, einen erklärenden Hinweis anzeigen (Roadmap
  Phase 7).
- Die Tonqualität der System-Mandarin-Stimme für einzelne Wörter (ohne
  Satzkontext) muss auf dem Gerät bewertet werden. Falls einzelne Wörter
  unnatürlich klingen, ist eine Option, sie in einen minimalen Trägersatz
  einzubetten — als Idee notiert, nicht im MVP.

---

## 7. Spracherkennung (Mandarin-Eingabe)

### Belegte Fakten

- `SpeechAnalyzer` und `SpeechTranscriber` sind ab **iOS 26.0** verfügbar
  (ebenso iPadOS/macOS/tvOS/visionOS 26.0).
- `SpeechAnalyzer` verwaltet die Analysesession; Module wie `SpeechTranscriber`
  liefern ihre Ergebnisse über eine `AsyncSequence`. Audio wird ebenfalls als
  `AsyncSequence` hineingegeben. Ein Analyzer verarbeitet immer nur **eine**
  Eingabesequenz gleichzeitig.
- `SpeechTranscriber` ist das Modul für normale Konversation und allgemeine
  Zwecke; es hat **Hardware-Anforderungen**. Über `supportedLocales` bzw.
  `installedLocales` prüft man, ob das Gerät die Modelle unterstützt; wenn
  nicht, soll man das Feature deaktivieren oder `DictationTranscriber`
  verwenden.
- `supportedLocales` enthält auch nicht installierte, aber herunterladbare
  Locales. Ist das Array leer, unterstützt das Gerät den Transcriber nicht.
- `DictationTranscriber` (ab iOS 26.0) nutzt dieselben Modelle wie die
  System-Diktierfunktion und ist mit älteren Geräten kompatibel. Er
  unterstützt keine Sprachen, die `SFSpeechRecognizer` nur über Netzwerk
  anbietet.
- `AssetInventory` (ab iOS 26.0) verwaltet die Sprachmodelle. Belegt:
  Assets müssen **vor** dem Gebrauch installiert werden, sie werden von
  Apple-Servern geladen, vom System verwaltet und **zwischen Apps geteilt**;
  die Installation ist ein vierstufiger Prozess; das System stellt eine
  begrenzte Anzahl locale-spezifischer Reservierungen zur Verfügung; nicht
  mehr benötigte Locales soll man wieder freigeben; das System kann Apps von
  lange unbenutzten Assets abmelden.
- Legacy: `SFSpeechRecognizer` (ab iOS 10.0) unterstützt pro Instanz genau
  eine Sprache, und für **manche Sprachen ist eine Internetverbindung
  erforderlich**.

### Sekundär belegt (auf dem Gerät zu verifizieren)

- Nach Berichten aus der Entwickler-Community enthält
  `SpeechTranscriber.supportedLocales` unter iOS 26 auch `zh_CN` (sowie
  `zh_HK`, `zh_TW`, `yue_CN`). Das stammt **nicht** aus der offiziellen
  Dokumentation. → In Phase 9 als erster Task auf dem Zielgerät ausgeben und
  protokollieren.
- Ebenfalls nur sekundär belegt: dass `SpeechAnalyzer` zusätzlich zur
  Mikrofonberechtigung `NSSpeechRecognitionUsageDescription` benötigt.
  → Vorgehen: **beide** Info.plist-Schlüssel setzen
  (`NSMicrophoneUsageDescription` und `NSSpeechRecognitionUsageDescription`)
  und das tatsächliche Verhalten auf dem Gerät prüfen. Beide Schlüssel zu
  setzen ist unschädlich; einen fehlenden Schlüssel bestraft iOS mit einem
  Crash.

### Bewertung der Antwort (bewusst einfach gehalten)

In Version 1 wird **keine Aussprachebewertung und keine Tonanalyse
behauptet**. Der Vergleich ist rein textuell:

1. Erkannten Text und Soll-Hanzi normalisieren (Interpunktion und
   Whitespace entfernen, chinesische Satzzeichen ebenfalls).
2. Bei Gleichheit: „Antwort wahrscheinlich korrekt“.
3. Sonst: beide Varianten anzeigen und die Selbsteinschätzung dem Nutzer
   überlassen.

Kein Score, keine Prozentangabe, kein Ton-Feedback. Eine echte
Aussprachebewertung ist Backlog, nicht MVP.

---

## 8. Netzwerkzugriff — Zusammenfassung

Die App selbst führt **keine eigenen Netzwerkanfragen** durch. Netzwerkzugriff
entsteht ausschließlich indirekt über das System:

| Auslöser | Netzwerk | Häufigkeit |
| --- | --- | --- |
| Download der Übersetzungsmodelle (`de`, `zh-Hans`) | ja | einmalig, mit System-Dialog |
| Download der Spracherkennungsmodelle (`zh_CN`) über `AssetInventory` | ja | einmalig, ggf. erneut nach System-Abmeldung |
| Übersetzen mit installierten Modellen | nein | — |
| Spracherkennung mit installierten Modellen | nein | — |
| Sprachausgabe (`AVSpeechSynthesizer`) | nein | — |
| Hanzi → Pinyin (CoreFoundation) | nein | — |
| SwiftData-Persistenz | nein | — |
| Metriken durch Apple bei `TranslationSession` | Bundle-ID + Sprachpaar, keine Inhalte | pro Nutzung |

Folgerung: Die App ist nach dem einmaligen Modell-Download **vollständig
offline nutzbar**. Das ist eine Anforderung, die in Phase 10 aktiv getestet
wird (Flugmodus-Test).

---

## 9. Benötigte Info.plist-Schlüssel

| Schlüssel | Grund | Ab Phase |
| --- | --- | --- |
| `NSMicrophoneUsageDescription` | Aufnahme für die Spracherkennung | 9 |
| `NSSpeechRecognitionUsageDescription` | Spracherkennung (vorsorglich, s. Abschnitt 7) | 9 |

Für Übersetzung, TTS, Pinyin und SwiftData sind keine Berechtigungen nötig.
Die Schlüssel werden erst in Phase 9 gesetzt — vorher braucht die App sie
nicht, und ein unnötiger Berechtigungsdialog wäre ein Rückschritt.

---

## 10. Offene technische Fragen (zu klären vor der jeweiligen Phase)

| # | Frage | Klären in | Risiko falls negativ |
| --- | --- | --- | --- |
| Q1 | Unterstützt das Translation Framework das Paar `de` → `zh-Hans` direkt? | Phase 4, Task 4.1 | mittel — Pivot über Englisch oder manuelle Eingabe als Standard |
| Q2 | Enthält `SpeechTranscriber.supportedLocales` auf dem Zielgerät `zh_CN`? | Phase 9, Task 9.1 | mittel — Fallback `DictationTranscriber`, sonst Feature entfällt |
| Q3 | Erfüllt das Zielgerät die Hardware-Anforderungen von `SpeechTranscriber`? | Phase 9, Task 9.1 | mittel — wie Q2 |
| Q4 | Braucht `SpeechAnalyzer` `NSSpeechRecognitionUsageDescription`? | Phase 9, Task 9.2 | gering — beide Schlüssel werden gesetzt |
| Q5 | Welche `zh-CN`-Stimmen und welche Qualität liegen auf dem Gerät vor? | Phase 7, Task 7.1 | gering — Hinweis auf manuellen Stimmen-Download |
| Q6 | Ist die ICU-Pinyin-Qualität für den echten Kartenbestand ausreichend? | Phase 3, Task 3.4 | gering — Feld ist editierbar |
| Q7 | Reicht die automatische SwiftData-Migration über die Projektlaufzeit? | Phase 1, Task 1.6 | gering — `SchemaMigrationPlan` nachrüstbar |
| Q8 | Muss `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` für `Learning/` abgeschaltet werden? Das Xcode-26-Template setzt es im App-Target, wodurch auch unannotierter Code der Learning-Schicht auf dem Main-Actor landet. | Phase 5, Task 5.1 | gering — alternativ die betroffenen Typen einzeln `nonisolated` markieren; Analyse in [architecture.md §4](architecture.md#4-learning-engine) |

---

## 11. Quellen

Primärquellen (Apple Developer Documentation):

- [SwiftData](https://developer.apple.com/documentation/swiftdata) · [`@Model`](https://developer.apple.com/documentation/swiftdata/model())
- [TranslationSession](https://developer.apple.com/documentation/translation/translationsession) · [`init(installedSource:target:)`](https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:))
- [LanguageAvailability](https://developer.apple.com/documentation/translation/languageavailability) · [`status(from:to:)`](https://developer.apple.com/documentation/translation/languageavailability/status(from:to:))
- [Translating text within your app](https://developer.apple.com/documentation/Translation/translating-text-within-your-app)
- [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer) · [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber) · [`supportedLocales`](https://developer.apple.com/documentation/speech/speechtranscriber/supportedlocales) · [`installedLocales`](https://developer.apple.com/documentation/speech/speechtranscriber/installedlocales)
- [DictationTranscriber](https://developer.apple.com/documentation/speech/dictationtranscriber) · [AssetInventory](https://developer.apple.com/documentation/speech/assetinventory)
- [SFSpeechRecognizer](https://developer.apple.com/documentation/speech/sfspeechrecognizer)
- [AVSpeechSynthesizer](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer) · [AVSpeechSynthesisVoice](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice) · [`speechVoices()`](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice/speechvoices())
- [CFStringTransform](https://developer.apple.com/documentation/corefoundation/1542411-cfstringtransform)
- [Meet the Translation API — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10117/)
- [Bring advanced speech-to-text to your app with SpeechAnalyzer — WWDC25](https://developer.apple.com/videos/play/wwdc2025/277/)
- [iOS and iPadOS Feature Availability](https://www.apple.com/ios/feature-availability/)

Sekundärquellen (als solche gekennzeichnet, nicht als Beleg verwendet):
Entwickler-Blogbeiträge zur `SpeechTranscriber`-Locale-Liste und zu den
Berechtigungen von `SpeechAnalyzer`; NSHipster zu `CFStringTransform`.
