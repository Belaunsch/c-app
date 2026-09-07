# Architektur

Leitgedanke: **so wenig Struktur wie möglich, so viel wie nötig.** Die App ist
eine private Single-User-App ohne Backend. SwiftUI und SwiftData decken den
Bedarf ab; alles, was darüber hinausgeht, muss sich rechtfertigen.

Genau eine Abstraktion wird bewusst eingezogen: die **Learning Engine ist
reiner Swift-Code ohne SwiftUI- und SwiftData-Abhängigkeit**. Sie ist der Teil
mit echter Logik, und sie muss ohne Simulator testbar sein.

---

## 1. Schichten

```
┌──────────────────────────────────────────────────────────┐
│  Features (SwiftUI Views + @Observable View-State)       │
│  Learn · Cards · Settings                                │
└───────────────┬──────────────────────┬───────────────────┘
                │                      │
┌───────────────▼──────────┐  ┌────────▼───────────────────┐
│  Learning (pure Swift)   │  │  Services (System-APIs)    │
│  Gewichtung, Mini-Batch, │  │  Translation · Pinyin ·    │
│  Queue, Statusübergänge  │  │  TTS · SpeechRecognition   │
│  → nur Foundation        │  │                            │
└───────────────┬──────────┘  └────────┬───────────────────┘
                │                      │
┌───────────────▼──────────────────────▼───────────────────┐
│  Models (SwiftData)                                      │
│  Card · Tag · CardType · LearningStatus                  │
└──────────────────────────────────────────────────────────┘
```

Regeln:

- **Learning** importiert ausschließlich `Foundation`. Kein `SwiftUI`, kein
  `SwiftData`. Die Engine arbeitet auf Wertetypen (`CardSnapshot`), nicht auf
  `@Model`-Klassen.
- **Services** kapseln je genau ein System-Framework und geben Swift-eigene
  Typen und Fehler zurück. Kein Service kennt eine View.
- **Features** halten den UI-Zustand in `@Observable`-Klassen und rufen
  Learning und Services auf. Views selbst enthalten keine Logik über
  Darstellung hinaus.
- **Models** enthalten Daten und höchstens triviale abgeleitete Properties.

Was es bewusst **nicht** gibt — und warum:

| Verzichtet auf | Begründung |
| --- | --- |
| Repository-Layer über SwiftData | `ModelContext` und `@Query` sind bereits die Datenzugriffsschicht. Eine Hülle darüber bringt hier keinen Nutzen und kostet Codezeilen bei jeder Änderung. |
| DI-Framework | Services werden dort erzeugt, wo sie gebraucht werden, oder über `@Environment` weitergereicht. Bei vier Services ist ein Container Overhead. |
| Coordinator/Router | Die App hat zwei Tabs und flache Navigation. `NavigationStack` genügt. |
| Drittanbieter-State-Management | `@Observable`, `@State` und `@Query` reichen aus. |
| Protokolle „für Testbarkeit“ vor jedem Service | Die testrelevante Logik (Engine, Pinyin) ist ohnehin pur. Hardware-nahe Services werden auf dem Gerät getestet, nicht gemockt. Protokolle werden erst eingeführt, wenn ein Test sie konkret braucht. |

---

## 2. Ordnerstruktur

In Phase 0 festgelegt (Task 0.1): Target-Name **`CApp`**, Bundle-ID
**`de.belaunsch.CApp`**. Der nach außen sichtbare App-Name lässt sich später
jederzeit über `INFOPLIST_KEY_CFBundleDisplayName` ändern, ohne das Target
oder die Bundle-ID anzufassen — daraus wird kein Naming-Projekt gemacht.

```
c-app/
├── CApp.xcodeproj
├── CApp/
│   ├── CAppApp.swift               App-Entry, ModelContainer-Setup
│   ├── RootView.swift              TabView: Lernen · Karten
│   ├── Assets.xcassets/            App-Icon-Slots, Akzentfarbe (Xcode-Template)
│   │
│   ├── Models/
│   │   ├── Card.swift              @Model
│   │   ├── Tag.swift               @Model
│   │   ├── CardType.swift          enum: word | sentence
│   │   ├── LearningStatus.swift    enum: new | weak | medium | good | secure
│   │   └── SampleData.swift        Vorschau-/Testdaten (nur DEBUG)
│   │
│   ├── Learning/                   ← reiner Swift-Code, nur Foundation
│   │   ├── CardSnapshot.swift      Wertetyp für die Engine
│   │   ├── CardWeighting.swift     Status → Gewicht
│   │   ├── BatchSelector.swift     gewichtete Auswahl ohne Zurücklegen
│   │   ├── SessionQueue.swift      Reihenfolge + Wiedereinstreuung
│   │   ├── StatusTransition.swift  Antwort → neuer Lernstatus
│   │   ├── SessionConfiguration.swift
│   │   └── SelfAssessment.swift    enum: again | hard | good | secure
│   │
│   ├── Services/
│   │   ├── PinyinService.swift             CoreFoundation, pur
│   │   ├── TranslationService.swift        Translation Framework
│   │   ├── SpeechSynthesisService.swift    AVSpeechSynthesizer
│   │   └── SpeechRecognitionService.swift  SpeechAnalyzer/SpeechTranscriber
│   │
│   ├── Features/
│   │   ├── Learn/
│   │   │   ├── SessionSetupView.swift      Inhalt + Richtung + Tags wählen
│   │   │   ├── LearnSessionView.swift
│   │   │   ├── LearnSessionModel.swift     @Observable, verbindet Engine + Context
│   │   │   ├── PromptGermanToChineseView.swift
│   │   │   ├── PromptAudioToGermanView.swift
│   │   │   └── SelfAssessmentBar.swift
│   │   ├── Cards/
│   │   │   ├── CardListView.swift          Liste, Suche, Filter
│   │   │   ├── CardFilterBar.swift
│   │   │   ├── CardEditorView.swift        Anlegen + Bearbeiten
│   │   │   ├── CardEditorModel.swift       @Observable
│   │   │   └── TranslationHostView.swift   unsichtbar, hält translationTask
│   │   └── Settings/
│   │       └── SettingsView.swift
│   │
│   └── Support/
│       ├── AppError.swift
│       └── String+Normalization.swift
│
├── CAppTests/
│   ├── TestSupport.swift               Container-Helfer, Tag-Typealias
│   ├── AppTabTests.swift               Phase 0
│   ├── CardModelTests.swift            Phase 1
│   ├── CardTagRelationshipTests.swift  Phase 1
│   ├── PersistenceTests.swift          Phase 1
│   ├── SampleDataTests.swift           Phase 1
│   ├── BatchSelectorTests.swift        Phase 5
│   ├── SessionQueueTests.swift         Phase 5
│   ├── StatusTransitionTests.swift     Phase 5
│   ├── CardWeightingTests.swift        Phase 5
│   └── PinyinServiceTests.swift        Phase 3
│
└── docs/
```

**Empfehlung für den VS-Code-Workflow:** Die Ordner unter `CApp/` als
*synchronisierte Ordner* („file system synchronized groups“, Xcode 16+) ins
Projekt einbinden. Dann landen neue Dateien, die in VS Code angelegt werden,
automatisch im Target — ohne manuelles Hinzufügen in Xcode und ohne ständige
Änderungen an `project.pbxproj`. In Phase 0 gemessen und bestätigt: drei
Dateioperationen erzeugten **null** Änderungen an `project.pbxproj`, und alle
`PBXSourcesBuildPhase`-Listen sind leer — die Mitgliedschaft kommt
ausschließlich aus der Synchronisation.

**Achtung, in Phase 0 auf die harte Tour gelernt:** Ein synchronisierter Ordner
nimmt **jede** Datei auf, auch versteckte. Fünf Platzhalter-Dateien namens
`.gitkeep` wurden als Ressourcen ins App-Bundle kopiert und kollidierten dort
auf demselben Ausgabepfad — der Build brach mit
`duplicate output file '…/CApp.app/.gitkeep'` ab.

Konsequenz: **keine Platzhalter-Dateien in leeren Ordnern.** Ein Ordner wird
mit seiner ersten echten Datei angelegt. Weil Git keine leeren Verzeichnisse
versioniert, ist die Ordnerliste oben die verbindliche Quelle für die
Struktur — nicht der Inhalt des Repositories. Wer künftig eine Datei nur zum
Ordner-Erhalt anlegen will, braucht dafür eine Ausnahme in der synchronisierten
Gruppe; einfacher ist es, darauf zu verzichten.

---

## 3. Datenmodell

### Umsetzung (in Phase 1 gebaut, Code in `CApp/Models/`)

```swift
// `nonisolated`, weil `Learning/` diese Typen aus nonisolated Code
// verwenden muss — siehe Q8 in apple-frameworks.md
nonisolated enum CardType: String, Codable, CaseIterable, Sendable {
    case word, sentence
}

nonisolated enum LearningStatus: Int, Codable, CaseIterable, Comparable, Sendable {
    case new = 0, weak = 1, medium = 2, good = 3, secure = 4
}

@Model
final class Card {
    var id: UUID

    // RawValue im Store, damit `#Predicate` filtern kann (siehe unten)
    private(set) var typeRaw: String
    private(set) var statusRaw: Int

    var type: CardType { get { ... } set { ... } }        // berechnet
    var status: LearningStatus { get { ... } set { ... } } // berechnet

    var german: String
    var hanzi: String
    var pinyin: String

    var createdAt: Date
    var lastReviewedAt: Date?
    var reviewCount: Int
    var correctCount: Int

    // Merker, damit die Automatik manuelle Korrekturen nie überschreibt
    var hanziWasEditedManually: Bool
    var pinyinWasEditedManually: Bool

    @Relationship(inverse: \Tag.cards)
    var tags: [Tag]
}

@Model
final class Tag {
    var name: String
    var cards: [Card]
}
```

Hinweise:

- `Card.id` ist eine eigene `UUID` zusätzlich zur `PersistentIdentifier` von
  SwiftData. Grund: stabile Identität für späteren Import/Export.
- Die Beziehung `Card ↔ Tag` ist many-to-many. Löschregel: Beim Löschen einer
  Karte werden Tags **nicht** gelöscht; beim Löschen eines Tags werden Karten
  **nicht** gelöscht (nur die Zuordnung verschwindet).
- **In Phase 1 gemessen (Task 1.4): Enums brauchen ein RawValue-Backing.**
  SwiftData *speichert* Codable-Enums korrekt — in Phase 1 als Zwischenstand
  gemessen, bevor auf RawValue-Backing umgestellt wurde; im Repository deckt
  seither kein Test diesen Pfad mehr ab. Aber es kann sie **nicht in einem
  `#Predicate` vergleichen**: Ein Filter gegen den Enum-Typ scheitert zur
  Laufzeit mit `SwiftDataError.unsupportedPredicate`, Klartext
  „Captured/constant values of type 'CardType' are not supported".
  Weil die Kartenübersicht in Phase 2 genau davon lebt (Wörter/Sätze
  umschalten, nach Lernstatus filtern), liegt der RawValue im Store:
  `typeRaw: String` und `statusRaw: Int`, dazu `type` und `status` als
  berechnete Properties darüber.
- Die beiden Raw-Properties sind `private(set)`: Geschrieben wird
  ausschließlich über `type` und `status`, gelesen werden sie auch von außen
  — sonst könnten Prädikate und `@Query` sie nicht verwenden. Die öffentliche
  Schreib-API des Modells bleibt damit wie ursprünglich entworfen.
- **Regel für Phase 2 und später:** In `#Predicate`, `@Query` **und
  `SortDescriptor`/`sortBy`** immer `typeRaw` bzw. `statusRaw` verwenden, nie
  `type` oder `status`. Ein Verstoß ist besonders unangenehm, weil er
  **compiliert** — `LearningStatus` ist `Comparable`, `SortDescriptor(\.status)`
  ist also gültiger Swift-Code — und erst beim Fetch zuschlägt, und zwar als
  **`fatalError`, nicht als `throw`**: `Couldn't find \Card.status on Card with
  fields [PropertyMetadata(name: statusRaw, …)]`. Fehlerbehandlung hilft
  dagegen nicht; eine nach Lernstatus sortierte Kartenliste stürzt ab. Deshalb
  nagelt ein Test die im Store liegenden Attribute fest.

### Persistiert vs. abgeleitet

Die Anforderungen nennen unter anderem „Gewicht bzw. Lernmetadaten“ und
„Anzahl Fehler“. Bewusste Entscheidung:

| Feld | Speicherung | Begründung |
| --- | --- | --- |
| `id` | persistiert | stabile Identität für Import/Export |
| `type` | persistiert | Kernunterscheidung Wort/Satz |
| `german`, `hanzi`, `pinyin` | persistiert | Inhalt |
| `tags` | persistiert | Beziehung |
| `status` | persistiert | Kern des Lernfortschritts |
| `createdAt` | persistiert | nicht rekonstruierbar |
| `lastReviewedAt` | persistiert | Basis für Recency und späteres Spaced Repetition |
| `reviewCount` | persistiert | nicht rekonstruierbar (keine Antwort-Historie) |
| `correctCount` | persistiert | dito |
| `hanziWasEditedManually`, `pinyinWasEditedManually` | persistiert | verhindert Überschreiben durch Automatik |
| **`weight`** | **abgeleitet** | Reine Funktion aus `status` (+ Recency innerhalb der Session). Doppelte Speicherung würde nur inkonsistent werden können. |
| **`errorCount`** | **abgeleitet** | `reviewCount - correctCount` |
| **`accuracy`** | **abgeleitet** | `correctCount / reviewCount` |
| **`isNew`** | **abgeleitet** | `status == .new` |

Eine vollständige Antwort-Historie (jede einzelne Antwort als eigenes Objekt)
wird **nicht** gespeichert. Sie wird für keine MVP-Funktion gebraucht und
wäre der teuerste Teil des Datenmodells. Falls später Statistiken über den
Zeitverlauf gewünscht sind, kommt ein separates `ReviewLog`-Modell hinzu —
das ist additiv und bricht nichts.

---

## 4. Learning Engine

Ausführliche Spezifikation: [learning-engine.md](learning-engine.md).

Architektonisch relevant ist nur die Schnittstelle:

```swift
struct CardSnapshot: Identifiable, Equatable {
    let id: UUID
    let status: LearningStatus
    let lastReviewedAt: Date?
}
```

- `LearnSessionModel` (Feature-Schicht) lädt Karten über den `ModelContext`,
  bildet sie auf `CardSnapshot` ab und übergibt sie der Engine.
- Die Engine liefert die Reihenfolge zurück und entscheidet über
  Wiedereinstreuung — sie schreibt selbst **nichts** in die Datenbank.
- `StatusTransition` ist eine reine Funktion
  `(LearningStatus, SelfAssessment) -> LearningStatus`. Das Persistieren
  übernimmt das `LearnSessionModel`.
- Der Zufall wird über `inout some RandomNumberGenerator` hereingereicht, damit
  Tests mit einem festen Seed deterministisch laufen.

Damit ist die gesamte Lernlogik ohne `ModelContainer`, ohne Simulator und
ohne Netzwerk testbar.

**Offener Punkt für Phase 5:** Das Xcode-26-Template setzt im App-Target
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (bei `SWIFT_VERSION = 5.0`).
Damit landet auch unannotierter Code unter `Learning/` standardmäßig auf dem
Main-Actor. Das verhindert die Tests nicht, steht aber quer zur Absicht von
A2, diese Schicht als reine, actor-freie Logik zu halten. In Phase 0 bewusst
unverändert gelassen, weil dort noch kein Code unter `Learning/` existiert und
eine Änderung ohne Anlass nur Risiko wäre. Vor der Umsetzung von Phase 5
bewusst entscheiden: Isolation für das Target abschalten, oder die betroffenen
Typen einzeln als `nonisolated` markieren.

---

## 5. Services

Alle Services sind eigenständige Typen ohne gemeinsame Basisklasse und ohne
Protokollhierarchie. Jeder liefert entweder ein Ergebnis oder einen typisierten
Fehler.

### PinyinService

- Rein funktional, kein Zustand, kein Netzwerk, keine Berechtigung.
- `CFStringTokenizer` mit `kCFStringTokenizerAttributeLatinTranscription` für
  wortweise Segmentierung; `CFStringTransform` mit
  `kCFStringTransformMandarinLatin` als Fallback.
- Vollständig unit-testbar.
- Grenzen (polyphone Zeichen, Versionsstabilität) siehe
  [apple-frameworks.md](apple-frameworks.md#5-hanzi--pinyin-mit-tonzeichen).

### TranslationService

Hier liegt die einzige unangenehme Stelle der Architektur, und sie kommt vom
Framework:

- Der **Download** fehlender Sprachmodelle lässt sich nur über den
  SwiftUI-Modifier `.translationTask()` anstoßen — das System zeigt dabei
  Zustimmungsdialog und Fortschritt selbst an.
- Das **Übersetzen bei bereits installierten Sprachen** geht ab iOS 26 auch
  ohne View über `TranslationSession(installedSource:target:)`.

Lösung: `TranslationHostView` ist eine leere View (`Color.clear.frame(width: 0,
height: 0)`) im Karten-Editor, die eine `TranslationSession.Configuration` hält
und ausschließlich für den Download-Pfad zuständig ist. Der Normalfall läuft
über den direkten Initializer im `TranslationService`.

Ablauf beim Übersetzen:

1. `LanguageAvailability.status(from: .german, to: .chineseSimplified)` prüfen.
2. `.installed` → direkt übersetzen.
3. `.supported` (noch nicht installiert) → Download über die Host-View
   anstoßen, Hinweis in der UI anzeigen.
4. `.unsupported` → Automatik dauerhaft ausblenden, manuelle Eingabe bleibt.

Der Service gibt Vorschläge zurück. Er schreibt nie direkt in die Karte.

### SpeechSynthesisService

- Hält **eine** langlebige `AVSpeechSynthesizer`-Instanz (das System retained
  sie nicht selbst — sonst bricht die Ausgabe sofort ab).
- Wählt beim Start die beste verfügbare `zh-CN`-Stimme
  (`.premium` > `.enhanced` > `.default`) und merkt sie sich.
- Meldet nach außen, ob überhaupt eine `zh-CN`-Stimme vorhanden ist, damit die
  UI im Zweifel einen Hinweis statt eines toten Buttons zeigt.

### SpeechRecognitionService

- Kapselt `SpeechAnalyzer` + `SpeechTranscriber` inklusive Locale-Reservierung
  und Modell-Download über `AssetInventory`.
- Liefert nach außen nur: Verfügbarkeitsstatus, Start/Stop und den erkannten
  Text.
- Der **Vergleich** von erkanntem Text und Soll-Hanzi gehört *nicht* in den
  Service, sondern als reine Funktion nach `Learning/` — dort ist er testbar.
- Kein Score, keine Aussprachebewertung (siehe
  [apple-frameworks.md](apple-frameworks.md#bewertung-der-antwort-bewusst-einfach-gehalten)).

---

## 6. Navigation

**Entscheidung: zwei Tabs — „Lernen“ und „Karten“. Einstellungen bekommen
keinen eigenen Tab.**

Begründung: Die Einstellungen umfassen absehbar eine Handvoll Einträge
(Stimme/Sprechgeschwindigkeit, Größe des Mini-Batches, Verwaltung der
Sprachmodelle, Datenzurücksetzung). Ein Drittel der Tab-Leiste dafür zu
belegen, gewichtet einen selten benutzten Bereich gleich stark wie die beiden
Kernfunktionen. Stattdessen: Zahnrad-Button in der Toolbar der Kartenübersicht,
der die Einstellungen als Sheet öffnet.

Diese Entscheidung ist billig revidierbar — falls die Einstellungen wachsen,
kostet ein dritter Tab wenige Zeilen. Neu bewerten am Ende von Phase 10.

Navigation innerhalb der Tabs:

- **Lernen:** `SessionSetupView` → `LearnSessionView` (per `NavigationStack`).
  Die Session-Auswahl ist bewusst ein eigener Schritt, weil Inhalt (Wörter
  oder Sätze) und Richtung vor jeder Session gewählt werden.
- **Karten:** `CardListView` → `CardEditorView` (Sheet für „Neu“, Push für
  „Bearbeiten“). „+“-Button prominent in der Toolbar.

---

## 7. Fehlerbehandlung

Grundsatz: **Automatik darf nie blockieren.**

| Fall | Verhalten |
| --- | --- |
| Übersetzung schlägt fehl / Sprache nicht installiert | Inline-Hinweis im Editor, Felder bleiben leer und editierbar, Speichern bleibt möglich |
| Pinyin-Erzeugung liefert leeren oder unplausiblen Wert | Feld bleibt leer, kein Fehlerdialog, manuelle Eingabe |
| Keine `zh-CN`-Stimme vorhanden | Play-Button ausgeblendet + einmaliger Hinweis, wie Stimmen nachgeladen werden |
| Spracherkennung nicht verfügbar / nicht erlaubt | Mikrofonteil der Lern-UI entfällt, Selbsteinschätzung funktioniert weiter |
| SwiftData-Schreibfehler | Alert mit Klartext, Aktion nicht stillschweigend verwerfen |
| Karte ohne Hanzi in einer Session | Karte wird beim Aufbau des Pools übersprungen |

Technisch: ein `AppError`-Enum in `Support/` für alles, was der Nutzer sehen
soll; Service-interne Fehler werden dorthin übersetzt. Keine `try!`, keine
stillen `catch {}`-Blöcke.

Kein Crash-Reporting, kein Logging-Framework. `os.Logger` reicht.

---

## 8. Testbarkeit

| Bereich | Testart |
| --- | --- |
| `BatchSelector`, `SessionQueue`, `StatusTransition`, `CardWeighting` | Unit-Tests mit festem RNG-Seed — schnell, deterministisch |
| `PinyinService` | Unit-Tests mit festen Wort-/Satzpaaren; erwartete Werte einmalig auf dem Gerät verifiziert |
| Antwortvergleich (Erkennung vs. Soll) | Unit-Tests der Normalisierungsfunktion |
| SwiftData-Modelle | leichte Integrationstests mit In-Memory-`ModelContainer` |
| Translation, TTS, Spracherkennung | **manuell auf dem Gerät**, mit Checkliste je Phase |

Es wird nicht versucht, System-Frameworks zu mocken. Der Aufwand steht in
keinem Verhältnis zum Nutzen bei einer App dieser Größe.

**Namenskollision im Testziel:** Unser Modell `Tag` heißt genauso wie
`Testing.Tag` aus dem Swift-Testing-Framework. In Testdateien, die beides
importieren, ist `Tag` deshalb mehrdeutig. Gelöst über eine einmalige
modulweite `typealias Tag = CApp.Tag` in `CAppTests/TestSupport.swift`. Der
Produktivcode ist nicht betroffen — er importiert `Testing` nicht.

---

## 9. Erweiterbarkeit

Die im Anforderungsdokument genannten späteren Lernmodi (Hanzi → Bedeutung,
Pinyin → Bedeutung, Deutsch → Hanzi schreiben, Audio → Hanzi, Satztraining,
Tonübungen, Statistiken, Spaced Repetition, Import/Export) werden **jetzt
nicht gebaut**. Die Architektur hält aber die passenden Nahtstellen offen:

| Erweiterung | Nahtstelle | Aufwand |
| --- | --- | --- |
| Weitere Abfragerichtungen | `SessionConfiguration.direction` um einen Case erweitern + eine neue Prompt-View. Engine bleibt unverändert. | klein |
| Echtes Spaced Repetition | `Card` um `dueDate`/`intervalDays` erweitern; `CardWeighting` multipliziert das Basisgewicht mit einem Überfälligkeitsfaktor. Die Engine-Schnittstelle bleibt gleich. | mittel |
| Statistiken über Zeit | additives `ReviewLog`-Modell | mittel |
| Import/Export | `Card` hat bereits eine stabile `UUID`; ein `Codable`-DTO plus `fileExporter`/`fileImporter` genügt | klein |
| Beispielsätze zu einem Wort | Selbstbeziehung auf `Card` oder eigenes Modell | mittel |
| Echte Aussprachebewertung | eigener Service; die textuelle Vergleichsfunktion wird ersetzt, nicht erweitert | groß |
| iCloud-Sync | `ModelContainer` mit CloudKit-Konfiguration; erfordert, dass alle Properties optional oder mit Default sind | mittel |

Für den letzten Punkt eine praktische Vorsichtsmaßnahme, die **jetzt nichts
kostet**: Beim Modellentwurf in Phase 1 werden Properties mit sinnvollen
Defaults versehen. Falls iCloud-Sync später doch gewünscht ist, entfällt eine
schmerzhafte Migration. Das ist keine vorzeitige Optimierung, sondern eine
Konvention beim Schreiben des Modells.

---

## 10. Zusammenfassung der Architekturentscheidungen

| # | Entscheidung | Begründung |
| --- | --- | --- |
| A1 | Deployment Target iOS 26.0 | `SpeechAnalyzer` und der UI-freie `TranslationSession`-Initializer erfordern es; private App auf aktuellem Gerät |
| A2 | Learning Engine als reiner Swift-Code auf Wertetypen | einzige Stelle mit echter Logik → muss ohne Simulator testbar sein |
| A3 | Kein Repository-Layer, kein DI, kein Coordinator | SwiftData/SwiftUI decken den Bedarf ab |
| A4 | Gewicht und Fehlerzahl abgeleitet, nicht persistiert | vermeidet inkonsistente Zustände |
| A5 | Keine Antwort-Historie im MVP | für keine MVP-Funktion nötig, später additiv nachrüstbar |
| A6 | Zwei Tabs, Einstellungen per Sheet | Einstellungen sind selten benutzt; billig revidierbar |
| A7 | `TranslationHostView` nur für den Download-Pfad | Framework-bedingt; hält den Rest der Übersetzungslogik View-frei |
| A8 | Manuelle Bearbeitung schlägt Automatik immer | fachliche Kernanforderung, im Modell durch Merker abgesichert |
| A9 | Keine externen Dependencies | Wartbarkeit, kein Update-Zwang, kleinere Angriffsfläche |
| A10 | Kein Mocking von System-Frameworks | Aufwand/Nutzen bei dieser App-Größe |
