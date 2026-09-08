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
│   ├── Resources/
│   │   └── ThirdParty/
│   │       └── CC-CEDICT/          Lexikondaten Dritter, CC BY-SA 4.0
│   │           ├── cedict-readings.txt    abgeleitet, 2,55 MB
│   │           ├── cedict-ambiguous.txt   abgeleitet, 6 KB
│   │           ├── LICENSE.txt
│   │           ├── ATTRIBUTION.md
│   │           └── SOURCE.md              Herkunft, Version, Änderungen
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
│   │   ├── PinyinService.swift             CoreFoundation, pur (Phase 3)
│   │   ├── TranslationService.swift        Verfügbarkeit + Konfiguration (Phase 4)
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
│   │   │   ├── CardFilterBar.swift         Status- und Kategoriefilter
│   │   │   ├── CardFilter.swift            pure Filterlogik, testbar
│   │   │   ├── CardEditorView.swift        Anlegen + Bearbeiten
│   │   │   ├── CardEditorModel.swift       @Observable, Validierung, Merker
│   │   │   ├── TagNormalization.swift      Duplikatvermeidung, Umbenennregeln
│   │   │   ├── TagListView.swift           Kategorien umbenennen und löschen
│   │   │   ├── TagManagement.swift          Umbenennen und Löschen, testbar
│   │   │   ├── CardDisplay.swift           deutsche Anzeigenamen der Enums
│   │   │   └── (kein TranslationHostView — siehe §5)
│   │   └── Settings/
│   │       └── SettingsView.swift
│   │
│   └── Support/
│       ├── AppError.swift              nutzersichtbare Fehler (Phase 2)
│       └── String+Normalization.swift  Phase 5
│
├── CAppTests/
│   ├── TestSupport.swift               Container-Helfer, Tag-Typealias
│   ├── AppTabTests.swift               Phase 0
│   ├── CardModelTests.swift            Phase 1
│   ├── CardTagRelationshipTests.swift  Phase 1
│   ├── PersistenceTests.swift          Phase 1
│   ├── SampleDataTests.swift           Phase 1
│   ├── CardFilterTests.swift           Phase 2
│   ├── CardEditorModelTests.swift      Phase 2
│   ├── TagNormalizationTests.swift     Phase 2
│   ├── CardDisplayTests.swift          Phase 2
│   ├── TagManagementTests.swift        Phase 2
│   ├── PinyinServiceTests.swift        Phase 3
│   ├── TranslationServiceTests.swift   Phase 4
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

Ausführliche Spezifikation: [learning-engine.md](learning-engine.md). In
Phase 5 gebaut, Code in `CApp/Learning/`.

Architektonisch relevant ist die Schnittstelle:

```swift
nonisolated struct CardSnapshot: Equatable, Hashable, Sendable {
    let id: UUID
    let status: LearningStatus
}
```

**Zwei Felder, nicht drei.** Die Planung hatte hier zusätzlich
`lastReviewedAt: Date?` vorgesehen. Keine Zeile der Engine braucht es: die
Gewichtung liest nur den Status, und alles nach der Auswahl arbeitet auf der
ID. Ein Feld, das niemand liest, ist ein Versprechen ohne Deckung — es kommt
dazu, wenn §11 (echtes Spaced Repetition) es tatsächlich braucht. Ebenso kein
`Identifiable`: die Konformität wird nirgends verwendet.

Bewusst **ohne** den Kartentext. Die Queue arbeitet mit IDs, deshalb zeigt
eine während der Session bearbeitete Karte beim nächsten Erscheinen ihren
neuen Inhalt, ohne dass die Engine davon etwas wissen muss
([learning-engine.md §9](learning-engine.md#9-randfälle)).

- Die Feature-Schicht (Phase 6) lädt Karten über den `ModelContext`, bildet
  sie auf `CardSnapshot` ab und übergibt sie der Engine.
- Die Engine liefert Auswahl und Reihenfolge zurück und entscheidet über
  Wiedereinstreuung — sie schreibt selbst **nichts** in die Datenbank und
  liest nie daraus.
- `AssessmentOutcome` ist die Antwort auf eine Selbsteinschätzung und trägt
  genau das, was die Feature-Schicht laut
  [§7](learning-engine.md#7-persistierte-änderungen-pro-antwort) schreiben
  muss: welche Karte, welche Antwort, ob es die **erste** Einschätzung im
  Batch war, der daraus folgende Status (`nil`, wenn er unverändert bleibt),
  ob die Karte wieder eingereiht wurde und ob der Batch beendet ist. Kein
  Event-System, kein Command-Bus.
- `StatusTransition` ist eine reine Funktion
  `(LearningStatus, SelfAssessment) -> LearningStatus`. Das Persistieren
  übernimmt die Feature-Schicht.
- `lastReviewedAt` setzt ebenfalls die Feature-Schicht. Die Engine hat keine
  Uhr — `Date()` im Berechnungspfad wäre genau die Nebenwirkung, die die
  Testfälle unprüfbar macht.
- Der Zufall wird über `inout some RandomNumberGenerator` hereingereicht,
  damit Tests mit einem festen Seed deterministisch laufen. Die Engine
  erzeugt nie selbst einen Generator.

Damit ist die gesamte Lernlogik ohne `ModelContainer`, ohne Simulator und
ohne Netzwerk testbar — gemessen: 27 Tests, jeder unter 25 ms.

**Actor-Isolation, in Phase 5 entschieden (Q8 geschlossen):** Das App-Target
behält `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; alle neun Dateien unter
`Learning/` sind einzeln `nonisolated`. Gemessen wurden beide Varianten mit
`SWIFT_STRICT_CONCURRENCY=complete`, weil erst das die Swift-6-Tauglichkeit
zeigt. Begründung und Zahlen in
[apple-frameworks.md §10, Q8](apple-frameworks.md#10-offene-technische-fragen-zu-klären-vor-der-jeweiligen-phase).
`project.pbxproj` blieb unverändert.

---

## 5. Services

Alle Services sind eigenständige Typen ohne gemeinsame Basisklasse und ohne
Protokollhierarchie. Jeder liefert entweder ein Ergebnis oder einen typisierten
Fehler.

### PinyinService

Beantwortet drei Fragen, jede von der Quelle, die sie am besten kann
(Entscheidung A22):

1. **Wo sind die Wortgrenzen?** `CFStringTokenizer` mit dem Locale
   `zh_Hans`. Chinesisch wird ohne Leerzeichen geschrieben, und ICUs
   Segmentierung ist darin gut — gemessen liefert sie `火车站`, `洗手间` und
   `明白` als je ein Token.
2. **Wie wird ein Wort gelesen?** `ChineseLexicon`, und nur es, sobald das
   Wort genau eine Lesung hat. Daher kommen die neutralen Töne, die ICU
   überhaupt nicht kennt.
3. **Was, wenn das Lexikon nichts sagen kann?** Dann, und nur dann, ICUs
   eigene Transkription — als `needsReview` gekennzeichnet.

Gesucht wird die **längste bekannte Phrase ab der aktuellen Position**,
geschnitten ausschließlich an ICUs Wortgrenzen. Das löst Mehrdeutigkeit aus
dem Kontext ohne eine einzige selbst geschriebene Regel: `东西` allein hat
zwei Lesungen und wird markiert, in `买东西` steht die Phrase im Lexikon und
ergibt `mǎi dōngxi`, `东西南北` ergibt `dōngxī nánběi`.

Rückgabe ist `PinyinResolution` mit `text`, `source`
(`lexicon` · `mixed` · `icuFallback` · `empty`) und dem daraus abgeleiteten
`needsReview`. Bewusst kategorial: **keine** Prozent- oder Confidence-Werte,
weil es die Genauigkeit nicht gibt, die eine Zahl behaupten würde.

Die beiden Schutzprüfungen aus Phase 4 bleiben vorgeschaltet: Die Quelle muss
Han-Schrift enthalten, und das Ergebnis muss wie eine Transkription aussehen
und nicht wie die durchgereichte Eingabe.

Grenzen siehe
[apple-frameworks.md §5](apple-frameworks.md#5-hanzi--pinyin-mit-tonzeichen)
und §10, Q6.

### ChineseLexicon

Lädt die gebündelten CC-CEDICT-Ableitungen und beantwortet genau zwei Fragen:
Wie liest sich dieses Wort, und ist das die einzige Lesung? Interpretiert
keine Bedeutung.

Gemessene Werte (Mac, Release-Build, Snapshot vom 2026-09-07):

| | |
| --- | --- |
| Datei lesen | 2 ms |
| Index aufbauen | 44 ms für 119.939 Einträge |
| Speicher | 10,0 MB resident |
| 80.000 Lookups | 2,4 ms |
| Satz segmentieren | 5 µs |
| Zuwachs Release-Bundle | 2,6 MB (1,3 MB → 4,1 MB) |

Deshalb: **einmal laden und behalten.** Keine Datenbank, keine Index-Dateien,
keine Cache-Verdrängung. Geladen wird aus dem `task` des Editors, damit die
44 ms in die Sheet-Animation fallen und nicht mitten in eine Eingabe.

### PinyinTone

Wandelt CC-CEDICTs Tonziffern in Tonzeichen: `dong1 xi5` → `dōngxi`. Rein,
deterministisch, ohne ICU — die eine Stelle der Kette, an der Korrektheit
vollständig aus der Eingabe entscheidbar ist. Ton 5 ist der neutrale Ton und
bekommt **kein** Zeichen; das ist der ganze Punkt.

### TranslationService

Hier liegt die einzige unangenehme Stelle der Architektur, und sie kommt vom
Framework:

- Der **Download** fehlender Sprachmodelle lässt sich nur über den
  SwiftUI-Modifier `.translationTask()` anstoßen — das System zeigt dabei
  Zustimmungsdialog und Fortschritt selbst an.
- Das **Übersetzen bei bereits installierten Sprachen** geht ab iOS 26 auch
  ohne View über `TranslationSession(installedSource:target:)`.

**In Phase 4 einfacher gelöst als geplant:** Es gibt **keine**
`TranslationHostView`. Der Karten-Editor selbst hält die
`TranslationSession.Configuration` in `@State` und trägt
`.translationTask(configuration)`. Dieser Modifier liefert die Session *und*
holt bei Bedarf die Systemzustimmung zum Modell-Download — beides über einen
Weg. Der direkte Initializer `TranslationSession(installedSource:target:)`
wird dadurch nicht gebraucht, und die zwei geplanten Codepfade fallen auf
einen zusammen. Eine erneute Übersetzung wird über `configuration.invalidate()`
ausgelöst.

`TranslationService` bleibt zuständig für die Frage, *ob* und *womit*
übersetzt werden kann (Entscheidung A16); die Übersetzung selbst läuft auf der
vom Modifier gelieferten Session.

Ablauf beim Übersetzen (Stand Phase 4):

1. `TranslationService.support()` prüfen — dreistufig, siehe A16.
2. Solange das Ergebnis noch nicht da ist, wird **nicht** automatisch
   übersetzt: sonst würde eine Konfiguration ohne die eventuell nötige
   Strategie festgeschrieben.
3. `.installed` oder `.downloadable` → beim Verlassen des deutschen Feldes
   `configuration` setzen bzw. `invalidate()`; `.translationTask` liefert die
   Session und holt nötigenfalls die Download-Zustimmung.
4. `.unsupported` → Automatik aus, Hinweis in der UI, manuelle Eingabe bleibt.
5. War die Verfügbarkeit nur aus dem Sprachkatalog geraten
   (`Support.isConfirmed == false`), verspricht die Meldung weniger.

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
stillen `catch {}`-Blöcke. Seit Phase 2 vorhanden, mit den Fällen
`cardIncomplete`, `cardSaveFailed` und `cardDeleteFailed`: Die Meldung ist
deutsch, das technische Systemdetail wird als zweiter Absatz angehängt statt
verworfen.

**In Phase 2 nachgeschärft:** Schlägt ein `context.save()` fehl, genügt der
Alert nicht — es wird zusätzlich `context.rollback()` aufgerufen. Sonst bleibt
die Änderung im Kontext liegen, die Liste zeigt eine gelöschte Karte schon als
verschwunden, und der nächste erfolgreiche Save an beliebiger Stelle committet
die angeblich fehlgeschlagene Aktion doch noch. Ein Alert, der die Unwahrheit
sagt, ist schlimmer als kein Alert.

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

**SwiftData-Modelle dürfen ihren Container nicht überleben.** In Phase 2 auf
die harte Tour gelernt: Eine Test-Fixture erzeugte Container und Karten in
einer Hilfsfunktion und gab nur die Karten zurück. Damit wurde der Container
freigegeben, und der erste Zugriff auf eine Property der überlebenden Karte
schlug im generierten Accessor mit `_assertionFailure` fehl — kein fangbarer
Fehler, sondern ein Absturz des ganzen Testprozesses. Weil alle Tests einen
Prozess teilen, meldeten anschließend **alle** übrigen Tests in 0,000 s
„failed", ohne Fehlermeldung; die Ursache stand nur im Crash-Report des
Simulators.

Konsequenz: Container in einer Test-Suite als **gespeicherte Property** halten
und in `init()` aufbauen. Eine Swift-Testing-Suite wird pro Test neu
instanziiert, dadurch lebt der Container garantiert so lange wie der Test.

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
| A11 | Kartenliste filtert in reinem Swift, nicht per dynamischem `#Predicate` | Ein `@Query` ohne Prädikat lädt sortiert, `CardFilter` verengt danach. Vermeidet die `fatalError`-Falle aus §3 vollständig, ist ohne View testbar, und bei einigen hundert Karten kostet es nichts. Neu bewerten, falls der Bestand vierstellig wird. |
| A12 | Mehrere gewählte Tags werden mit **UND** verknüpft | Jeder Filter in der Kartenübersicht verengt das Ergebnis — Typ, Suche und Status ebenso. OR nur für Tags wäre inkonsistent und überraschend. |
| A14 | Neue Tags entstehen erst beim Speichern der Karte | Der Editor merkt getippte Namen nur vor. Würde er sie sofort einfügen, hinterließe ein abgebrochener Editor den Tag dauerhaft — der `mainContext` speichert automatisch, und die App hat **keine** Funktion zum Löschen eines Tags. Ein Vertipper wäre damit unumkehrbar. |
| A13 | Tag-Deduplizierung über einen berechneten Schlüssel, ohne Schemafeld | „Essen", „essen" und „ESSEN" vergleichen sich über `TagNormalization.key`; die zuerst eingegebene Schreibweise bleibt sichtbar. Ein gespeichertes `normalizedName` wäre eine Schemaänderung samt Migration für eine Handvoll Tags. **Diakritika werden bewusst nicht gefaltet** (Produktentscheidung): „Café" und „Cafe" bleiben getrennt, weil „Grün" und „Grun" verschiedene Wörter sind und ein Zusammenführen die Daten stillschweigend umbenennen würde. Die **Suche** ist dagegen diakritikainsensitiv, damit Pinyin ohne Tonzeichen findbar bleibt — zwei verschiedene Zwecke, zwei verschiedene Regeln. |
| A16 | Übersetzungsstrategie: keine explizite Vorgabe, dafür ein dreistufiger Verfügbarkeitscheck | Ohne `preferredStrategy` wählt das Framework selbst und fällt laut Apple-Doku automatisch auf eine passende Alternative zurück — Qualität zuerst, ohne eigene Logik. Der Check läuft dreistufig: Standard, dann (ab iOS 26.4) `.lowLatency`, dann der Sprachkatalog. Grund für Stufe 2: Apps, die gegen das 26.4-SDK gebaut werden, prüfen standardmäßig auf Apple-Intelligence-Modelle, was auf Geräten ohne Apple Intelligence ein falsches „unsupported" ergeben kann. Grund für Stufe 3: Im Simulator meldet `status(from:to:)` **jedes** Paar als `unsupported`, auch `de → en` — würde die App das als Gerätegrenze deuten, wäre die Funktion dauerhaft aus. `TranslationSession.Strategy` gibt es erst ab iOS 26.4, das Target bleibt 26.0, deshalb `if #available`. |
| A17 | Die drei Textfelder sind eine Kette, die Herkunft jedes Werts wird live geführt | Deutsch → Hanzi → Pinyin. Ausgelöst wird beim Verlassen des Feldes, nicht pro Tastendruck. `hanziBaseline`/`pinyinBaseline` halten den letzten **abgeglichenen** Wert — was die App beim Laden oder Generieren hineingeschrieben hat, oder was der Nutzer beim letzten Editier-Ende darin stehen hatte. Alles, was davon abweicht, kam vom Nutzer. Wichtig: Der Abgleich läuft nicht nur beim Fokusverlust, sondern auch **bevor** die Automatik schreibt und **beim Speichern** — sonst hätte ein während der laufenden Übersetzung getippter Wert überschrieben werden können, und genau das ist der Normalablauf, weil der Sprung ins Hanzi-Feld die Übersetzung auslöst. Damit gilt ein generierter Wert nie als manuell (Q9), und ein manueller Wert wird nie still überschrieben. Zwei sichtbare Bedienelemente sind die einzige Freigabe zum Überschreiben — seit A21 je ein ↻ direkt im Feld, die Texte „Neu übersetzen" und „Pinyin neu erzeugen" leben als Accessibility-Labels weiter: Das ↻ am Hanzi-Feld erneuert Hanzi **und** das daraus abgeleitete Pinyin, das ↻ am Pinyin-Feld nur das Pinyin. Danach gilt der Wert wieder als automatisch. Bewusst **keine** generische Change-Tracking-Schicht: zwei Bools und zwei Strings. |
| A18 | Stale-Ergebnisse werden verworfen, nicht abgebrochen | Jeder Übersetzungslauf bekommt eine Nummer; ein Ergebnis wird nur angewandt, wenn seine Nummer noch aktuell ist **und** der deutsche Text sich nicht verändert hat. „Latest input wins" ohne Task-Verwaltung. |
| A19 | Der Editor synchronisiert seinen Zustand **vor** dem Speichern, nicht erst beim Fokusverlust | `reconcileForSave()` tut, was das Verlassen des Feldes getan hätte: normalisieren, Herkunft abgleichen, und das Pinyin neu ableiten, wenn es nicht zum Hanzi im Feld gehört — ein manuell korrigiertes Pinyin ausgenommen. Die Frage lautet ausdrücklich **„aus welchem Hanzi wurde dieses Pinyin erzeugt?"** (`pinyinSourceHanzi`) und nicht „hat sich das Hanzi seit dem letzten Abgleich geändert?". Die beiden fallen auseinander, sobald eine Übersetzung eintrifft, während der Nutzer ein eigenes Hanzi tippt: `completeTranslation` gleicht die Herkunft ab — schiebt also die Hanzi-Baseline vor — und bricht dann ab, ohne das Pinyin anzufassen. Die änderungsbasierte Regel sah danach „nichts geändert" und speicherte das Pinyin des alten Worts; im Test `decliningTranslationDoesNotLeaveAStalePinyin` festgenagelt und gegen die alte Regel als rot gemessen. Nebeneffekt derselben Frage: Ein vom Nutzer **geleertes** Pinyin hat das aktuelle Hanzi als Quelle und wird deshalb nicht hinter seinem Rücken nachgefüllt — „Pinyin kann leer bleiben" stimmt damit wieder. Grund ist ein echter Fehler aus dem Gerätetest der Phase 4: „Brot" ergab `面包`/`miànbāo`, das Hanzi wurde von Hand auf `水` korrigiert, und direkt aus dem Hanzi-Feld gespeichert stand `水` mit `miànbāo` in der Karte — die Lesung eines Worts, das nicht mehr auf der Karte war. Ein Tap auf die Toolbar verschiebt den Fokus nicht zuverlässig, also darf die Korrektheit nicht davon abhängen, dass SwiftUI vorher ein Fokusereignis liefert. Die Regel ist ohne View testbar. |
| A20 | Automatisches Pinyin nur aus echtem Hanzi, und veraltetes Pinyin wird geleert | `PinyinService` verlangt mindestens ein Han-Zeichen in der Quelle und ein plausibles Ergebnis (Details in [apple-frameworks.md §5](apple-frameworks.md#5-hanzi--pinyin-mit-tonzeichen)) — ICU reichte sonst Nicht-Chinesisch durch, im Gerätetest wurde aus `asdf` das Pinyin `asdf`. Lässt sich nichts ableiten, wird ein **automatisches** Pinyin geleert statt stehen gelassen: es gehörte zu einem anderen Hanzi. Ein **manuelles** Pinyin wird nie gelöscht, auch nicht vom Refresh. Dieselbe Prüfung gilt beim Speichern: Das Hanzi-Feld braucht mindestens ein Han-Zeichen, gemischter Text mit Han-Anteil bleibt erlaubt. |
| A21 | Return/„Fertig" gibt nur den Fokus frei, gearbeitet wird an einer Stelle | Die drei Felder sind einzeilig, damit Return überhaupt ein Submit auslöst; `onSubmit` setzt lediglich `focusedField = nil`, was die Tastatur schließt. Die eigentliche Arbeit hängt an der Fokusänderung (`endEditing(of:)`). Damit kann ein Tastendruck strukturell keine zwei Übersetzungen starten, ohne Merker im View. Zusätzlich merkt sich das Modell den zuletzt angefragten deutschen Text, sodass ein doppelter Aufruf auch dort nichts auslöst. Leerzeichen bleiben erlaubt — Sätze brauchen sie, Satz-Pinyin auch —, nur Zeilenumbrüche werden beim Abschluss zu Leerzeichen normalisiert. **Preis der Einzeiligkeit:** Ein langer Satz ist nur scrollend im Feld zu lesen. Wenn sich das im Gerätetest als störend erweist, ist der dokumentierte Ausweg `axis: .vertical` plus ein „Fertig" in einer `ToolbarItemGroup(placement: .keyboard)` — dann bleibt es bei genau einem Abschlussweg (`focusedField = nil`), nur ausgelöst über die Tastatur-Toolbar statt über die Return-Taste. |
| A22 | Das Lexikon ist die Primärquelle für Pinyin, ICU nur noch gekennzeichneter Fallback | Reine Transliteration reicht für eine Lern-App nicht: ICU kennt den neutralen Ton nicht (`谢谢`→`xièxiè` statt `xièxie`), verliert einzelne Tonzeichen (`钱`→`qian`) und wählt bei mehrdeutigen Zeichen inkonsistent. CC-CEDICT kodiert Ton 5 explizit, führt Wort- und Phraseneinträge und trennt mehrere Lesungen. Gemessen am Snapshot: **nur 1.250 von 121.189 Stichwörtern (1,03 %) haben tatsächlich verschiedene Lesungen**, und 1.249 davon sind ein bis drei Zeichen lang — mehrzeichige Wörter sind praktisch immer eindeutig. Der Aufwand liegt also fast vollständig in der Datenbeschaffung, nicht in der Disambiguierung. Daten als gebündeltes Asset, **keine** Laufzeit-Dependency; Herkunft und Lizenz in [SOURCE.md](../CApp/Resources/ThirdParty/CC-CEDICT/SOURCE.md). **Zwei bekannte Grenzen, bewusst so:** (1) Wer Deutsch tippt, Hanzi tippt und sofort speichert, speichert ein prüfbedürftiges Pinyin, ohne den Hinweis gesehen zu haben — der Editor darf nach Regel 5 nichts blockieren, und beim Wiederöffnen der Karte steht der Hinweis da, weil der Zustand abgeleitet wird. (2) 13 Einträge schreiben zwei Silben ohne Trennzeichen (`兙` liest `shi2ke4`, die metrischen Einheitenzeichen); solche Lesungen werden verworfen statt mit Ziffern ins Feld geschrieben. |
| A23 | Wortgrenzen von ICU, Lesungen vom Lexikon | Zwei getrennte Fragen, zwei getrennte Quellen. CC-CEDICT trennt **jede** Silbe und kodiert keine Wortgrenzen — `早上好` steht als `zao3 shang5 hao3` genau wie `火车站` als `huo3 che1 zhan4` —, also käme aus dem Lexikon allein `zǎoshanghǎo` heraus. Umgekehrt zerschneidet ein rein zeichenbasierter Longest Match Wörter falsch: `我不明白` wird zu `我`+`不明`+`白` und ergibt `wǒ bùmíng bái` statt `wǒ bù míngbai`. Beides gemessen. Deshalb: Kandidatengrenzen sind ausschließlich ICUs Tokengrenzen, und die Silben einer Phrase werden an genau diesen Grenzen wieder aufgeteilt. **Ein Token, das das Lexikon nicht als Stichwort kennt, wird davor in bekannte Wörter zerlegt** — ICU liefert `啤酒杯` als ein Token, CC-CEDICT hat dafür kein Stichwort, aber `啤酒` und `杯` stehen beide darin. Ohne diese Zerlegung erschiene der Prüfhinweis auf gewöhnlichen Wortkarten, an denen nichts unsicher ist. Die Zerlegung bricht ab, sobald ein Teil **mehrdeutig** ist: `东西风` in `东`+`西`+`风` zu schneiden würde ein selbstsicheres `dōngxīfēng` ergeben, obwohl `东西` genau das Wort ist, das ohne Kontext nicht entscheidbar ist. Dafür existiert die Mehrdeutigkeitsliste im Asset. Das ist tragfähig, weil ein reines Han-Stichwort **exakt eine Silbe pro Zeichen** hat — über alle 124.202 solchen Einträge geprüft, und im Code noch einmal geprüft statt angenommen. |
| A24 | Keine deutsche Bedeutungsauflösung in dieser Iteration | Das deutsche Feld wäre der natürliche Tiebreaker für die verbleibenden Mehrdeutigkeiten — `etwas` gegen `Osten und Westen` —, aber CC-CEDICTs Glossen sind **englisch**. Geprüfte Wege und warum keiner trägt: Apples Translation-Framework für Deutsch → Englisch macht die Pinyin-Erzeugung von einem zusätzlichen Sprachmodell abhängig, das nichts garantiert (und `TranslationSession` ist ohnehin nur über den View-Modifier zu bekommen); `NLEmbedding` ist einsprachig und kennt keine deutsch-englische Ausrichtung; eine eigene Wortliste wäre genau die verbotene Hardcode-Sammlung. Also **nicht geraten**: Was der chinesische Kontext nicht löst, wird ICU-Fallback mit `needsReview` und einem sichtbaren Hinweis. Der offene Weg ist eine deutschsprachige Lexikonquelle (HanDeDict, CH-DE-Dict) — erst nach Messung des Restbedarfs, siehe Roadmap Phase 4.5. |
| A25 | Filter hinter einem Knopf, Kategorienverwaltung daneben | Die Liste ist der Zweck des Bildschirms, die Filter werden gelegentlich benutzt — also bekommt die Liste den Platz. Lernstatus und Kategorien liegen zusammen auf einem Sheet hinter einem Symbol, das **gefüllt** ist, solange etwas filtert; `CardFilterSelection` beantwortet als Wertetyp „filtert etwas" und „wie viele Gruppen" und ist ohne View testbar. Die Filtersemantik selbst (ein Status, Kategorien mit UND) ist unverändert und bleibt in `CardFilter`. Die Kategorienverwaltung bleibt ein eigener Knopf: Sie **ändert** Daten, während der Filter nur die Ansicht einschränkt — beides in ein Menü zu legen würde zwei verschiedene Dinge gleich aussehen lassen. |
| A15 | Kategorien werden in place umbenannt, nie zusammengeführt | `TagManagement.rename` ändert die bestehende `Tag`-Entität. Ein neuer Tag plus Neuzuordnung würde dasselbe Ergebnis anstreben, aber jede Beziehung anfassen und dabei Fehler ermöglichen. Zielt der neue Name auf einen anderen bestehenden Tag, wird abgelehnt statt gemergt: Merging würde zwei Kategorien unumkehrbar verschmelzen, und der Nutzer hat kein Undo. |
