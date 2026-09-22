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
│   │   ├── ReviewLog.swift         @Model, Antwort-Historie (Phase 11)
│   │   ├── SuggestionDecision.swift enum: accepted | declined (Phase 13)
│   │   └── SampleData.swift        Vorschau-/Testdaten (nur DEBUG)
│   │
│   ├── Learning/                   ← reiner Swift-Code, nur Foundation
│   │   ├── CardSnapshot.swift      Wertetyp für die Engine
│   │   ├── CardWeighting.swift     Status → Gewicht
│   │   ├── BatchSelector.swift     gewichtete Auswahl ohne Zurücklegen
│   │   ├── SessionQueue.swift      Reihenfolge + Wiedereinstreuung
│   │   ├── StatusTransition.swift  Antwort → neuer Lernstatus
│   │   ├── LearningParameters.swift Gewichte, Batchgröße (Default 7), Schwellen
│   │   ├── ReviewSignal.swift     ein Versuch als reiner Wert (Phase 11)
│   │   ├── AssistedAssessment.swift fragen oder weitergehen (Phase 11)
│   │   ├── AnswerNormalization.swift Vergleichsform für Antworten
│   │   ├── SessionConfiguration.swift
│   │   └── SelfAssessment.swift    enum: again | hard | good | secure
│   │
│   ├── Services/
│   │   ├── PinyinService.swift             CoreFoundation, pur (Phase 3)
│   │   ├── PinyinSyllable.swift            Silbe mit Ton, Unit und Fuß (Phase 6.5)
│   │   ├── ToneSandhi.swift                reine Regeln, nur Foundation (Phase 6.5)
│   │   ├── ChineseLexicon.swift            gebündelte CC-CEDICT-Daten
│   │   ├── PinyinTone.swift                Tonziffern zu Tonzeichen
│   │   ├── TranslationService.swift        Verfügbarkeit + Konfiguration (Phase 4)
│   │   ├── MandarinVoice.swift             reine Stimmenauswahl (Phase 7)
│   │   ├── SpeechSynthesisService.swift    AVSpeechSynthesizer (Phase 7)
│   │   ├── SpeechRecognitionService.swift  SpeechAnalyzer/SpeechTranscriber
│   │   ├── SpeechModelState.swift          Modellzustand → Text und Knöpfe (Phase 10)
│   │   ├── MandarinRecognitionLocale.swift reine Locale-Prüfung, testbar
│   │   ├── AIPrompts.swift                 Instructions + promptRevision (Phase 14)
│   │   ├── AIAvailability.swift            fünf Zustände, reine Regel (Phase 14)
│   │   └── CardExplanationGenerator.swift  @Generable + eine Anfrage (Phase 14)
│   │
│   ├── Features/
│   │   ├── Speech/
│   │   │   └── SpeakButton.swift           Lautsprecher + Hinweis (Phase 7)
│   │   ├── Learn/
│   │   │   ├── SessionSetupView.swift      Typ + Richtung + Kategorien, Start
│   │   │   ├── LearnCategorySelection.swift  Auswahlregel, testbar
│   │   │   ├── LearnSessionView.swift
│   │   │   ├── LearnSessionModel.swift     @Observable, verbindet Engine + Context
│   │   │   ├── PromptGermanToChineseView.swift
│   │   │   ├── PromptStage.swift          Stufen und Sichtbarkeit Modus B
│   │   │   ├── LearnRevealedAnswerView.swift  geteilter Endzustand beider Modi
│   │   │   ├── LearnDisplay.swift         deutsche Texte und Antwort-Labels
│   │   │   ├── SpeechCheck.swift          Vergleichsergebnis, rein und testbar
│   │   │   ├── RecordAnswerButton.swift   Mikrofonknopf, Zustandstabelle testbar
│   │   │   ├── SessionSpeechMode.swift   Session-Sprachmodus, rein (Phase 12)
│   │   │   ├── LearnFlow.swift            Flowregeln, rein und testbar (Phase 13)
│   │   │   ├── PromptAudioToGermanView.swift
│   │   │   └── RevealedDecisionBar.swift  Weiter oder Einstufungsfrage (Phase 13)
│   │   ├── Cards/
│   │   │   ├── CardListView.swift          Liste, Akkordeon, Filter, Sortierung
│   │   │   ├── CardListArrangement.swift  Sortierung, Sections, Akkordeonregel
│   │   │   ├── CardFilterSheet.swift       Status- und Kategoriefilter
│   │   │   ├── CardFilterSelection.swift   ausgewählte Filter, testbar
│   │   │   ├── CardFilter.swift            pure Filterlogik, testbar
│   │   │   ├── CardEditorView.swift        Anlegen + Bearbeiten
│   │   │   ├── CardEditorModel.swift       @Observable, Validierung, Merker
│   │   │   ├── LearningStatusCorrection.swift  Lernstand von Hand, testbar (Phase 13)
│   │   │   ├── CardExplanationEntry.swift  wo die Erklärung angeboten wird (Phase 14)
│   │   │   ├── CardExplanationSheet.swift  ein Sheet, zwei Einstiege (Phase 14)
│   │   │   ├── CardExplanationModel.swift  @Observable, Anfrage injizierbar (Phase 14)
│   │   │   ├── TagNormalization.swift      Duplikatvermeidung, Namensregeln
│   │   │   ├── TagListView.swift           Kategorien anlegen, umbenennen, löschen
│   │   │   ├── TagManagement.swift         Anlegen, Umbenennen, Löschen, testbar
│   │   │   ├── CardDisplay.swift           deutsche Anzeigenamen der Enums
│   │   │   └── (kein TranslationHostView — siehe §5)
│   │   └── Settings/
│   │       ├── SettingsView.swift          Sheet hinter dem Zahnrad (Phase 10)
│   │       └── SettingsDisplay.swift       deutsche Namen der Einstellungen
│   │
│   └── Support/
│       ├── AppError.swift              nutzersichtbare Fehler (Phase 2)
│       ├── Preferences.swift           Einstellungen, rein und testbar (Phase 10)
│       └── ChineseText.swift           Sprachauszeichnung für VoiceOver (Phase 10)
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

**Was Phase 13 an dieser Struktur geändert hat** (2026-09-21, oben schon
eingetragen): `SelfAssessmentBar.swift` ist **gelöscht** und durch
`RevealedDecisionBar.swift` ersetzt (*Weiter* oder die Einstufungsfrage), dazu
ist `LearnFlow.swift` mit den reinen Regeln des neuen Bedienflusses
hinzugekommen — Beschriftung des Aufdeck-Knopfes und, davon getrennt, „streut
wieder ein". `RecordAnswerButton.swift` behält seinen Namen und hat den
geteilten Zustand `[ Fertig ][ ■ ]` bekommen. In `Learning/` ist **keine**
Datei hinzugekommen; `AssistedAssessment.swift`, `ReviewSignal.swift`,
`SessionQueue.swift` und `SelfAssessment.swift` sind geändert. In `Models/` ist
`SuggestionDecision.swift` neu, und `ReviewLog.swift` hat die zwei neuen
Properties.

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
| `classificationEvidenceResetAt` | **Phase 13**, persistiert, optional | die Linie, ab der die assistierte Einstufung Evidenz lesen darf. Gesetzt bei einer Korrektur von Hand; `nil` = noch nie korrigiert |
| **`weight`** | **abgeleitet** | Reine Funktion aus `status` (+ Recency innerhalb der Session). Doppelte Speicherung würde nur inkonsistent werden können. |
| **`errorCount`** | **abgeleitet** | `reviewCount - correctCount` |
| **`accuracy`** | **abgeleitet** | `correctCount / reviewCount` |
| **`isNew`** | **abgeleitet** | `status == .new` |

Eine vollständige Antwort-Historie wurde bis Phase 10 **nicht** gespeichert:
Sie wurde für keine MVP-Funktion gebraucht und wäre der teuerste Teil des
Datenmodells gewesen. Der Satz, ein separates `ReviewLog`-Modell käme später
additiv hinzu und bräche nichts, stand hier seit Phase 1 als Vorhersage.

### `ReviewLog` (Phase 11)

**Die Vorhersage hat gehalten**, und sie ist nachgemessen worden statt
geglaubt: Ein Store, der mit dem Phase-10-Schema geschrieben wurde, öffnet mit
dem Phase-11-Schema ohne Migrationsplan und ohne Verlust (Q7 in
[apple-frameworks.md](apple-frameworks.md), `SchemaMigrationTests`).

Gebraucht wird die Historie von der assistierten Bewertung: Ohne Evidenz gibt
es keinen Vorschlag. Gespeichert wird deshalb genau das, was
[learning-engine.md §12](learning-engine.md) liest.

| Feld | Speicherung | Begründung |
| --- | --- | --- |
| `id` | persistiert | stabile Identität, wie bei `Card` |
| `reviewedAt` | persistiert | die zeitliche Ordnung der Evidenz |
| `direction` | persistiert | Modus A und B stellen verschiedene Fragen |
| `previousStatus` | persistiert | die Ausgangslage des Versuchs |
| `usedSpeech` | persistiert | ob überhaupt automatische Evidenz vorlag |
| `speechMatched` | persistiert, optional | die Evidenz selbst; `nil` ohne Sprache |
| `wasManualReveal` | persistiert | Aufdecken ist kein Wissensbeleg |
| `wasRetry` | persistiert | zweiter Anlauf im selben Batch |
| `assessment` | persistiert, optional | die Selbsteinschätzung, falls eine abgegeben wurde. **Ab Phase 13 immer `nil`** — das Feld bedeutet ausschließlich die historische Vierfachbewertung des alten Flows |
| `suggestedStatus` | **Phase 13**, persistiert, optional | der Status, den die App bei diesem Versuch vorgeschlagen hat. `nil` = kein Vorschlag |
| `suggestionDecision` | **Phase 13**, persistiert, optional | was aus dem Vorschlag wurde: `accepted` oder `declined`. `nil` = kein Vorschlag |
| `card` | Beziehung | `.cascade` von `Card` |
| **Rohaudio, Konfidenz, Zeitdauer** | **gibt es nicht** | Nie gemessen (harte Regel 7). Ein Feld, das existiert, wird irgendwann benutzt |
| **erkannter Wortlaut** | **gibt es nicht** | Für die Entscheidung zählt nur, ob er nach der Normalisierung passte. Den Text zu behalten wäre eine Sammlung gesprochener Äußerungen ohne Zweck |

Die Löschregel ist `.cascade` und damit eine andere als bei `tags` (`.nullify`):
Ein Eintrag beschreibt einen Versuch an **dieser** Karte und hat ohne sie keine
Bedeutung, während eine Kategorie ohne die Karte weiterbesteht.

Die Aggregate `reviewCount` und `correctCount` auf `Card` bleiben, wo sie
sind — sie wären jetzt zwar ableitbar, aber sie neu zu berechnen wäre eine
Änderung ohne Nutzen und mit Migrationsrisiko.

#### Die zwei Felder aus Phase 13

```swift
private(set) var suggestedStatusRaw: Int?        // LearningStatus?
private(set) var suggestionDecisionRaw: String?  // SuggestionDecision?
```

RawValues im Store aus demselben Grund wie bei `previousStatusRaw`, beide
Default `nil`, beide immer gemeinsam gesetzt oder gemeinsam `nil` (Invariante
mit Test). `SuggestionDecision` ist ein eigenes `nonisolated enum String` in
`Models/` mit ausgeschriebenen RawValues — sie sind Historie, dieselbe Regel
wie bei `SelfAssessment` und `SessionDirection`.

**Warum nicht ein Feld, und warum nicht das vorhandene `assessment`.** Vier
Tatsachen müssen ohne Raten auseinanderzuhalten sein: eine historische
Selbsteinschätzung, eine vorgeschlagene Einstufung, ihre Annahme und ihre
Ablehnung. `assessment` bedeutet „der Lernende hat eine der vier
Selbsteinschätzungen abgegeben". Eine Zustimmung zu einem Vorschlag der App
dort abzulegen, weil sie denselben Statusübergang erzeugt, würde die erste und
die dritte Tatsache **ununterscheidbar** machen — rückwirkend und ohne Weg
zurück, weil die Unterscheidung nirgends sonst festgehalten wäre. Der
Phase-13-Flow schreibt deshalb immer `assessment = nil`.

Und beide neuen Felder tragen: Ohne `suggestedStatus` wäre der Vorschlag nur
über die **heutige Fassung** der Einstufungsregel rekonstruierbar, und eine
Historie, deren Bedeutung an der aktuellen Regel hängt, ist keine Historie.
Ohne `suggestionDecision` wären Annahme und Ablehnung nicht unterscheidbar —
der Status der Karte liegt auf `Card` und wird vom nächsten Versuch
überschrieben, und es aus dem *nächsten* Eintrag zu folgern scheitert beim
jüngsten. **Semantische Eindeutigkeit vor der gesparten Property**; die
vollständige Gegenrechnung steht in
[learning-engine.md §13.10](learning-engine.md#1310-die-schemaänderung-zwei-felder-und-warum-genau-zwei).

Die Engine sieht davon **einen abgeleiteten Wert**, nicht beide Felder:
`ReviewSignal.declinedSuggestion`, gebildet an der Abbildungsgrenze wie
`Card → CardSnapshot`. Die Annahme braucht die Regel nicht — ein angenommener
Vorschlag hat den Status bewegt, sein Eintrag trägt also einen anderen
`previousStatus` und fällt durch die Gleichstatus-Regel schon heraus. Ein Feld,
das die Engine nie liest, kommt auch nicht in die Engine.

**Nicht ins Schema kommt** der Merker, ob eine Aufnahme auf dieser Karte
möglich war. Er entscheidet die Wiedereinstreuung innerhalb des laufenden
Versuchs, wird später von keiner Regel gelesen, und `wasManualReveal` trägt die
Evidenzseite schon.

**Und es sind die ersten neuen Properties auf einem bestehenden Modell.** Q7 war
für ein neues Modell plus Beziehung gemessen, für diesen Fall **nicht** — also
ist es nachgemessen worden: `SchemaMigrationTests.phase13PropertiesMigrateLightly`
schreibt einen Store mit dem nachgebauten **Phase-12-Schema** (dieselben
Entitätsnamen, `ReviewLog` ohne die beiden Felder) samt realer Historie und
öffnet dieselbe Datei mit dem Phase-13-Schema. Ergebnis: ohne
`SchemaMigrationPlan`, ohne Verlust, die beiden neuen Properties lesen auf jedem
Alteintrag als `nil`, und ein zweites Öffnen bestätigt, was tatsächlich auf der
Platte steht.

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

**Was Phase 13 an dieser Schnittstelle geändert hat** (2026-09-21):
`AssessmentOutcome` und `SessionQueue.assess(_:currentStatus:)` sind durch
`closeCurrentCard(reinserting:) -> Bool` ersetzt — der Eingang der Engine ist
nicht mehr eine Selbsteinschätzung, sondern der Abschluss eines Versuchs. Ein
Outcome-Objekt gibt es **nicht** mehr, und das ist eine Abweichung von der
Spezifikation mit Grund: Nach dem Umbau hatte es keinen Leser mehr. Der Status
wird nur bei *Bestätigen* geschrieben und kommt dort aus dem Vorschlag, „erster
Versuch im Batch" beantwortet `reinsertCount(for:)`, und das Batchende fragt der
Aufrufer mit `isFinished` ab. Zurückgegeben wird deshalb nur, **ob** eine Karte
geschlossen wurde. Die **Regeln** darunter bleiben unverändert:
Wiedereinstreuungsposition, `maxReinserts`, „ungesehene Karten zuerst",
Batchende. `StatusTransition` bleibt die einzige Stelle, an der ein Status
entsteht; sie wird ab Phase 13 vom Feature-Layer direkt aufgerufen, wenn der
Nutzer eine vorgeschlagene Einstufung bestätigt. Begründung und die
vollständige Liste in
[learning-engine.md §13.9](learning-engine.md#139-welche-phase-11-regeln-damit-ersetzt-sind).

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
  sie nicht selbst — sonst bricht die Ausgabe sofort ab) **und** den Delegate,
  denn `delegate` ist eine schwache Referenz. Erzeugt in `CAppApp`, verteilt
  über die Environment — kein Singleton, weil der `ModelContainer` schon so
  verfährt, und kein DI-Container.
- Spricht **Hanzi**, nie Pinyin (A31).
- Wählt die Stimme über die reine Funktion in `MandarinVoice.swift`:
  Mainland-Mandarin filtern (über den geparsten BCP-47-Tag, damit `zh-TW` und
  `yue-HK` draußen bleiben), dann `.premium` > `.enhanced` > `.default`.
  Auf dem Zielgerät wählt genau diese Ordnung seit der Installation von
  `Lili (Premium)` diese Stimme — ohne Sonderfall im Code, und im direkten
  Hörvergleich gegen Tingting bestätigt (Q5). Ein `if name == "Lili"` gibt es
  bewusst nicht: Es würde auf dem nächsten Gerät nur falsch liegen.
  **Innerhalb derselben Qualitätsklasse** entscheidet eine Liste bevorzugter
  Identifier. Sie wird erst gebraucht, wenn die beste installierte Klasse
  mehrere Stimmen enthält — der erste Gerätebestand war genau dieser Fall:
  neun `zh-CN`-Stimmen, alle `.default`, `voiceTraits` überall `0`, also kein
  technisches Kriterium. Diese Präferenz auf Tingting ist eine
  **Produktentscheidung aus einem physischen Hörvergleich** (Q5), keine
  Behauptung über technische Überlegenheit, und sie bleibt der Weg für Geräte
  ohne Premium- oder Enhanced-Stimme. Fällt sie aus, gilt der kleinste
  Identifier: willkürlich, aber stabil gegen die undokumentierte Reihenfolge
  von `speechVoices()`.
- Eigene Qualitätsordnung als `VoiceQuality`, weil
  `AVSpeechSynthesisVoiceQuality` nicht `Comparable` ist und Apple keine
  Rangfolge dokumentiert.
- **Die Audio-Session gehört dem Service.** `usesApplicationAudioSession` ist
  `true` (gemessen), der Synthesizer verwaltet sie also nicht selbst.
  `.playback` + `.voicePrompt`, je Äußerung aktiviert und am Ende mit
  `notifyOthersOnDeactivation` freigegeben — nicht dauerhaft aktiv gehalten.
- **Der neueste Tap ersetzt die laufende Wiedergabe**, und diese Logik stützt
  sich bewusst **nicht** auf die Delegate-Callbacks: `didCancel` feuert
  dokumentiert nicht verlässlich, und seine Reihenfolge gegenüber einem direkt
  folgenden `speak(_:)` ist nicht dokumentiert. Also wird der Zustand
  synchron beim Tap gesetzt, `stopSpeaking(at: .immediate)` bedingungslos
  aufgerufen, und ein Callback zu einer fremden Äußerung per
  `ObjectIdentifier` verworfen. Über den Actor-Hop reist nur diese Identität,
  weil `AVSpeechUtterance` nicht `Sendable` ist.
- `stop()` beim Verschwinden der Lernsession und des Editors: sonst redet die
  Karte in den nächsten Bildschirm, und es ist der einzige Teardown ohne
  Delegate-Callback.
- Meldet nach außen, ob überhaupt eine Mandarin-Stimme vorhanden ist, damit
  die UI den Knopf **ausblendet** statt ihn tot dastehen zu lassen, plus
  einmal pro App-Lauf ein Hinweis auf den Systemweg. Kein Schemafeld, kein
  dauerhaftes „nie wieder".

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

**Neu bewertet am 2026-09-12 (Task 10.11): die Entscheidung bleibt.** Jetzt
nicht mehr gegen eine Schätzung, sondern gegen den gebauten Bildschirm —
`SettingsView` hat fünf Abschnitte:

| Abschnitt | Einträge | oben vorhergesagt? |
| --- | --- | --- |
| Sprechtempo | ein segmentierter Picker mit drei Stufen | ja |
| Stimme | ein Picker, **nur wenn mehr als eine Mandarin-Stimme installiert ist** | ja |
| Lernen | ein Stepper für die Kartenzahl je Runde (5–10) | ja |
| Sprachmodelle | Status, „Vorbereiten", „Entfernen" mit Rückfrage | ja |
| Karten je Lernstand | fünf Zahlen, nur Anzeige | nein |

Drei bis vier bedienbare Stellen also, auf einem Gerät oft nur drei. Die
vorhergesagte Datenzurücksetzung ist **nicht** gebaut worden — sie stand in
keinem Task und wird auch nicht nachgereicht; eine Sammlung zu löschen ist
nichts, was hinter einem Zahnrad wohnen sollte. Dazugekommen sind allein die
Zahlen je Lernstand, und die sind keine Einstellung, sondern der Blick auf den
eigenen Bestand.

Das einzige Argument, das für einen Tab spricht, kommt von genau diesen
Zahlen: Sie sind die einzige Stelle der App, die den Gesamtbestand zeigt, und
sie liegen hinter einem Zahnrad in **einem** der beiden Tabs. Es wiegt nicht
schwer genug. Ein Drittel der Tab-Leiste würde dauerhaft für einen Bildschirm
belegt, den man nach dem Einrichten selten wieder öffnet, und die Alternative
ist nicht ein Tab, sondern — falls die Zahlen je öfter gebraucht werden — ihr
Platz in der Kartenübersicht, wo der Bestand ohnehin steht.

**Was die Entscheidung umstoßen würde:** mehr als etwa acht bedienbare
Einträge, eine zweite Ebene unterhalb der Einstellungen, oder eine Einstellung,
die man mitten in einer Session ändern will. Nichts davon ist in Sicht; die
beiden Post-v1-Phasen fügen Lernverhalten hinzu, keine Bedienknöpfe. Fällt
eines davon doch an, kostet der dritte Tab weiterhin wenige Zeilen.

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
| Spracherkennung nicht verfügbar / nicht erlaubt | Mikrofonteil der Lern-UI entfällt, der Rest der Karte funktioniert weiter (bis Phase 12: die Selbsteinschätzung; ab Phase 13 Aufdecken und *Weiter*) |
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

### Audit in Phase 10 (Task 10.3, 2026-09-12)

Die Tabelle oben ist die **Entscheidung**. Dies hier ist der **Befund**: jede
Fehlerquelle im Code aufgesucht, nicht aus dem Gedächtnis aufgezählt. Gesucht
wurde nach `catch`, `throw`, `try` und `AppError` in allen Dateien außerhalb
von `Learning/` — die Lernschicht wirft nicht und kennt keine Fehler.

**Ergebnis nach der Nacharbeit: kein einziges stilles `catch`.** Jeder
Fehlerpfad endet entweder in einem Alert, in einem sichtbaren Zustand oder
mindestens in einem `os.Logger`-Eintrag mit Begründung, warum der Nutzer davon
nichts erfahren muss. `try!` kommt im Projekt nicht vor, leere `catch {}`
ebenso wenig.

Beim ersten Durchgang stand hier dieselbe Aussage — und sie war falsch: Das
Review fand ein `try?` in `SpeechRecognitionService.stopEngine()`, das den
Fehler beim Freigeben der Aufnahme-Session spurlos verwarf (jetzt Zeile 10a).
Der einzige verbliebene `try?` steht in einem `#if DEBUG`-Preview und hat
seinen sichtbaren Ersatzzustand daneben.

Spalte *Prüfbar*: **Test** heißt, die Suite deckt es ab; **Gerät** heißt, nur
am Gerät auslösbar; **beides** heißt, die Logik hängt im Test, das Auslösen
gehört auf die Geräteliste; **Log** heißt, es gibt keine sichtbare Folge,
sondern nur einen `os.Logger`-Eintrag; **nicht getestet** steht da, wo weder
das eine noch das andere zutrifft — mit Begründung in derselben Zelle.

| # | Auslöser | Konkreter Fehler | Was der Nutzer sieht | Was er dann tun kann | Prüfbar |
| --- | --- | --- | --- | --- | --- |
| 1 | Übersetzung | `TranslationSession.translate` wirft (Modell fehlt, offline, Abbruch) | Fußnote im Editor: „Übersetzung nicht möglich. Hanzi kann manuell eingetragen werden." Kein Alert, kein `AppError` | Hanzi selbst eintippen; Speichern bleibt möglich | beides — `finishTranslationRun` im Test, der Wurf nur im Flugmodus |
| 2 | Übersetzung | Antwort ist leer | Fußnote: „Die Übersetzung war leer. Hanzi bitte manuell eintragen." | wie 1 | Test (`completeTranslation`) |
| 3 | Übersetzung | Antwort trifft ein, nachdem der Nutzer selbst Hanzi getippt hat | nichts — der getippte Wert bleibt, das Pinyin wird nachgezogen | nichts nötig | Test |
| 4 | Pinyin | Wort im Lexikon mehrdeutig, ICU rät | Hinweis unter dem Feld: Pinyin konnte nicht eindeutig bestimmt werden | Wert prüfen und überschreiben | Test (`PinyinCorpusTests`) |
| 5 | Pinyin | kein Hanzi, oder ICU liefert nichts | Feld bleibt leer, kein Dialog | von Hand ausfüllen | Test |
| 6 | Pinyin | gebündelte Lexikondatei fehlt oder ist unlesbar | nichts Unmittelbares — jedes Wort fällt auf ICU und wird als prüfbedürftig markiert | Werte prüfen; die App bleibt benutzbar | **nicht getestet** — strukturell: leere `readings` führen denselben Weg wie ein unbekanntes Wort, und die gebündelte Datei ist im Testbundle immer vorhanden; ein Injektionspunkt allein dafür wäre Produktivcode für einen Fall, den nur ein beschädigtes App-Bundle auslöst. Log vorhanden |
| 7 | TTS | keine Mandarin-Stimme installiert | Lautsprecher-Knöpfe **verschwinden**, dazu einmalig der Hinweis, wie Stimmen nachgeladen werden | Stimme in den iOS-Einstellungen laden — die App merkt es beim nächsten Start und im Betrieb | beides (`shouldNotice`, `MissingVoiceNotice` im Test) |
| 8 | TTS | gewählte Stimme wurde entfernt | nichts — die Automatik übernimmt die beste verbliebene | nichts nötig | Test (`PreferencesTests`) |
| 9 | TTS | `AVAudioSession` verweigert Kategorie oder Aktivierung | Alert „Aussprache nicht möglich" + Systemtext; `AppError.speechUnavailable` | OK, weiterlernen; Ton fehlt nur hier | Gerät (Session-Konflikt) |
| 10 | TTS | Deaktivieren der Session schlägt fehl | nichts — gesprochen wurde bereits | nichts nötig; nur Log, weil sonst fremde Apps gedämpft blieben | Log |
| 10a | Erkennung | Freigeben der Aufnahme-Session schlägt fehl | nichts — die Aufnahme ist ohnehin vorbei, der nächste Tipp konfiguriert neu | nichts nötig | Log — bis zum Phase-10-Review war das die **einzige** Stelle mit einem stummen `try?` |
| 10b | Erkennung | „Sprachmodell entfernen" gibt nichts frei, weil keine Reservierung gehalten wurde | `modelFailure = speechModelNotReleased`: „Es gab keine Reservierung zurückzugeben. Das Sprachmodell bleibt auf dem Gerät." | nichts — der Zustand ist unverändert, und das steht jetzt da | Test (`SpeechModelStateTests`, `SpeechModelWorkTests`) |
| 10c | Erkennung | Ein zweiter Tipp auf „Vorbereiten", während schon geladen wird | nichts — der Knopf ist weg, und der Lauf wird an der Quelle abgewiesen (`beginModelWork`) | warten; der Fortschritt steht daneben | Test (`SpeechModelWorkTests`) für die Regel, Gerät für den sichtbaren Ablauf |
| 10d | Erkennung | Ein überholter Modellauf kehrt aus seinem `await` zurück | nichts — er schreibt weder Zustand noch Fortschritt; der übernehmende Lauf beansprucht den Zustand beim Übernehmen und beendet ihn | nichts nötig | Test (`SpeechModelWorkTests`) |
| 10e | Erkennung | „Entfernen" hat erfolgreich freigegeben, Apple löscht erst später | „Freigegeben — das System löscht die Daten später"; der Entfernen-Knopf verschwindet | später erneut vorbereiten | Test (`SpeechModelStateTests`) |
| 10f | Erkennung | Das System hat einen Download selbst übernommen und beendet | die Statuszeile stimmt, **und** das Mikrofon wird wieder bedienbar: `refreshModelStatus()` zieht die Phase nach | normal weiterlernen | Gerät |
| 11 | Erkennung | Gerät oder Locale können kein Mandarin | Mikrofonknopf **ausgeblendet**, Satz darunter: „Dieses Gerät kann kein Mandarin erkennen. Alles andere funktioniert weiter." | normal weiterlernen, Selbsteinschätzung unberührt | beides (`RecordAnswerButton.note`) |
| 12 | Erkennung | Mikrofon nicht freigegeben | Knopf sichtbar aber tot, Satz: „Ohne Mikrofon geht alles andere weiter …" | Freigabe in den iOS-Einstellungen nachholen | beides |
| 13 | Erkennung | Modelle nach dem Versuch weiterhin nicht installiert | `AppError.speechAssetsUnavailable` mit dem **gemessenen** `AssetInventory`-Status im technischen Teil | später erneut versuchen, in den Einstellungen vorbereiten | Gerät |
| 14 | Erkennung | Reservierung oder Download scheitern (offline beim ersten Mal) | `AppError.speechAssetsFailed` + Systemtext | online gehen, erneut vorbereiten | Gerät (Flugmodus vor dem ersten Download) |
| 15 | Erkennung | Aufnahme oder Analyse brechen ab | `AppError.speechRecognitionFailed`, Knopf geht zurück auf „Antwort sprechen", Meldung darunter | erneut sprechen oder aufgeben | Gerät |
| 16 | Erkennung | nichts gesprochen | „Nichts erkannt. Noch einmal versuchen, oder aufgeben." — ausdrücklich **kein** Fehler und **kein** Urteil über die Aussprache | wiederholen | beides |
| 17 | SwiftData | Container lässt sich nicht öffnen | ganzseitige `PersistenceErrorView` statt Absturz | App neu starten; der Grund steht da | Gerät |
| 18 | SwiftData | `save()` beim Anlegen/Bearbeiten einer Karte scheitert | Alert `cardSaveFailed` **und** `rollback()` | erneut versuchen; nichts wurde halb geschrieben | **Gerät** — siehe Kasten unten |
| 18a | SwiftData | `save()` beim Setzen des Lernstands von Hand scheitert | Alert „Lernstand nicht gespeichert" + `rollback()`; eigener Zustand, nicht der des Löschens, damit die Meldung nicht über die falsche Aktion spricht | erneut wählen; der alte Stand steht noch | **Gerät** — derselbe nicht provozierbare Pfad wie 18 bis 21 |
| 19 | SwiftData | `save()` beim Löschen scheitert | Alert `cardDeleteFailed` + `rollback()`, die Karte bleibt sichtbar | erneut versuchen | **Gerät** |
| 20 | SwiftData | `save()` **während einer Session** scheitert | Alert, `rollback()`, die Karte bleibt aufgedeckt und der Vorschlag stehen | dieselbe Entscheidung erneut treffen | **Gerät** |
| 21 | SwiftData | Kategorie anlegen/umbenennen/löschen scheitert | `tagCreateFailed` / `tagRenameFailed` / `tagDeleteFailed`, jeweils mit Systemtext | erneut versuchen; der alte Zustand steht noch | **Gerät** |
| 22 | Eingabe | Kategoriename leer, zu lang oder doppelt | `tagNameRejected` mit dem konkreten Grund, **bevor** geschrieben wird | Namen ändern | Test |
| 23 | Eingabe | Karte ohne Deutsch oder ohne chinesisches Zeichen | `cardIncomplete` — der Speichern-Knopf ist ohnehin aus | Felder füllen | Test |
| 24 | SwiftData | `fetch` der Kategorien im Editor scheitert | nichts Sichtbares; es gilt die Liste der Ansicht, im schlechtesten Fall entsteht eine Kategorie doppelt (A13) | Kategorien in der Verwaltung zusammenführen | Log |
| 25 | SwiftData | `fetch` des Pools scheitert | Leerzustand „Keine passenden Karten" | Karte anlegen, Auswahl ändern | Log |
| 26 | Datenlage | Karte ohne chinesischen Text | wird beim Aufbau des Pools übersprungen — sie taucht in keiner Session auf | Hanzi ergänzen | Test |
| 27 | Datenlage | Karte wird gelöscht, während sie in der laufenden Session steckt | die Session überspringt sie beim nächsten Zugriff; ein eintreffendes Erkennungsergebnis wird verworfen und protokolliert | weiterlernen | Test |
| 28 | AI-Erklärung | `rateLimited` | eigene Meldung im Sheet, deutsch, ohne technischen Zusatz; das Sheet bleibt bedienbar, die Karte unberührt | einen Moment warten und *Neu erzeugen* tippen | **Gerät gemessen** — am 2026-09-21 im Vordergrund ab der zweiten Anfrage aufgetreten (`apple-frameworks.md` §12.1), also kein Randfall |
| 29 | AI-Erklärung | jeder andere `GenerationError` (Guardrail, Refusal, Decoding, Kontextfenster, Assets, fremde Sprache) | eine gemeinsame Meldung `explanationFailed`: „Die Erklärung konnte nicht erzeugt werden. An der Karte wurde nichts geändert." | erneut versuchen | Test |
| 29b | AI-Erklärung | eine Anfrage kehrt nicht zurück | **kein Ausgang aus dem Sheet**, solange sie läuft: *Fertig* deaktiviert, Wegwischen gesperrt. Das ist die Kehrseite der Sperre aus 29a, und sie ist bewusst in Kauf genommen — Apple sichert für `respond` unter iOS 26 weder Timeout noch Abbruch zu, und „wahrscheinlich gestoppt" wäre keine Grundlage für eine zweite Anfrage | App neu starten | **Gerät** — eigener Punkt in der finalen Abnahme, Nr. 8 |
| 29a | AI-Erklärung | `concurrentRequests` | **strukturell unmöglich:** die Session entsteht in der Anfrage und stirbt mit ihr. Eine zweite *parallele* Anfrage verhindern `isGenerating` **und** `.interactiveDismissDisabled(isGenerating)` samt deaktiviertem *Fertig* — ohne letztere war Schließen und Wiederöffnen ein Weg zu zwei laufenden Anfragen, gefunden vom Review | — | `CardExplanationTests.noSecondRequestWhileGenerating` für die Sperre; die Wegwisch-Sperre ist Codelesung, das Verhalten Gerät |

**Warum die fünf SwiftData-Schreibfehler nicht im Test stehen.** Der
Fehlerpfad ist nicht provozierbar: Ein `ModelContext`, der beim Speichern
wirft, lässt sich im Testbundle nicht herstellen — `allowsSave: false` wird im
vollen Suite-Lauf nicht geehrt, das steht seit Phase 2 in
`CardEditorModelTests` und `LearnSessionModelTests` mit Begründung. Die
Audit-Fassung dieser Tabelle hat hier zunächst **Test** behauptet; das war
falsch und ist korrigiert. Was tatsächlich getestet ist, sind die
*Vorbedingungen* — `canSave`, `TagNormalization.RenameProblem` und die
Statusübergänge; der Alert samt `rollback()` gehört auf die Geräteliste.

**Fehler haben seit dem 2026-09-13 zwei Adressaten.** `failure` gehört dem
Aufnahmepfad und wird auf der Lernkarte gelesen, `modelFailure` der
Modellverwaltung und wird in den Einstellungen gelesen. Vorher gab es nur
`failure`, und das Review fand die Folge: ein Erkennungsfehler aus einer
Lernsession stand unter „Sprachmodelle" und erklärte dort, die
Selbsteinschätzung gehe weiterhin — wahr, und über einen Bildschirm, auf dem
der Leser nicht war. Die Trennung gilt in beide Richtungen: Ein Lauf, den der
Nutzer in den Einstellungen startet, schreibt **nur** `modelFailure`; nur ein
Lauf aus dem Mikrofonpfad schreibt zusätzlich `failure`, weil nur dort eine
Meldung unter dem Mikrofonknopf hingehört.

`refreshModelStatus()` räumt beim Öffnen der Einstellungen `modelFailure` weg
— aber **nicht**, wenn der Zustand `.failed` ist. Die erste Fassung löschte
bedingungslos, und das Review fand, was das kostet: Eine vom Lernbildschirm
gestartete Vorbereitung scheitert, der Nutzer geht in die Einstellungen, um
nachzusehen, und der Bildschirm löscht die Erklärung beim Betreten. `.failed`
ist genau der Zustand, dessen Zweck diese Erklärung ist. Der Aufnahmefehler
bleibt in jedem Fall unangetastet.

**Zwei Stellen sind bewusst leise** — Zeile 24 und 25. Beide könnten dem
Nutzer nichts anbieten, was er nicht ohnehin sieht: Bei 25 ist der Leerzustand
die Aussage, bei 24 wäre ein Alert über einen fehlgeschlagenen internen
Lesevorgang genau die Art Meldung, die man wegtippt. Beide stehen im Log mit
Begründung im Code.

**Was hier nicht behauptet wird:** Die Zeilen mit *Gerät* sind damit **nicht**
geprüft. Sie stehen auf der Geräteliste dieser Phase, und erst deren Ergebnis
entscheidet über das Akzeptanzkriterium „Kein Fehlerfall führt zu einem
Absturz oder einem stillen Verschlucken".

### Was Phase 13 an dieser Tabelle geändert hat

Die Tabelle oben ist der **Befund vom 2026-09-12** und ist an den betroffenen
Zeilen nachgezogen. Phase 13 hat daran keine Fehlerklasse und keinen Pfad
geändert, aber **fünf** Zeilen haben einen anderen Wortlaut bekommen, weil der
Knopf, auf den sie verweisen, anders heißt:

| Zeile | was sich ändert |
| --- | --- |
| 11 (`unavailable`) | „Alles andere funktioniert weiter" bleibt; der Aufdeck-Knopf heißt auch hier *Aufgeben* — die Beschriftung ist in Modus A konstant, nur wieder eingestreut wird dort nichts |
| 12 (`permissionDenied`) | „tippe auf „Antwort zeigen“" → „tippe auf „Aufgeben“" |
| 15 (Aufnahme/Analyse bricht ab) | „erneut sprechen oder die Antwort zeigen" → *Aufgeben* |
| 16 („nichts gesprochen") | „Noch einmal versuchen, oder die Antwort zeigen." → *Aufgeben*; ausdrücklich weiterhin **kein** Urteil über die Aussprache |
| 20 (`save()` während einer Session) | „bleibt aufgedeckt und unbewertet" → die Karte bleibt aufgedeckt, und dieselbe Entscheidung (*Weiter*, *Bestätigen*, *Ablehnen*) ist erneut möglich |

Neu hinzu kommt **kein** Fehlerfall: *Stop* kann nicht scheitern — es verwirft,
und ein verworfener Versuch schreibt nichts.

### Leer- und Ladezustände (Task 10.4)

| Ort | Leer | Lädt |
| --- | --- | --- |
| Kartenliste, gar keine Karten | „Noch keine Wörter/Sätze" + Knopf „Karte anlegen" | — |
| Kartenliste, Suche/Filter ohne Treffer | „Keine Treffer", bei mehreren Kategorien mit dem Hinweis, dass **eine** genügt (A32) | — |
| Kategorienverwaltung | „Noch keine Kategorien" + Knopf | — |
| Lern-Setup | Erklärung, **warum** leer: Kategorien oder fehlender chinesischer Text — getrennt, weil das Kategorien-Beschuldigen nur bei Kategorien ehrlich ist | — |
| Laufende Session | „Keine passenden Karten" + „Karte anlegen" (Karte während der Session gelöscht) | — |
| Editor | — | Übersetzung: Spinner am Feld; Lexikon: lädt im `task` beim Erscheinen des Sheets (gemessen 46 ms auf dem Mac, Gerätewert steht auf der Liste) |
| Einstellungen | Kartenzahlen zeigen Nullen statt zu verschwinden | Sprachmodell: Statuszeile in jedem Zustand („Wird geprüft …", „Wird vorbereitet …", „Wird geladen …", „Noch nicht geladen", „Nicht geladen", „Bereit"), dazu ein `ProgressView`, solange Apples eigenes `Progress`-Objekt läuft. Vom ersten Tippen bis zum Ergebnis gehört der Zustand dem laufenden Vorgang: Der Vorbereiten-Knopf ist in dieser Zeit weg, und ein zweiter Lauf wird abgewiesen. Übergibt das System den Download an sich selbst, bleibt „Wird geladen …" stehen |
| Spracherkennung | — | „Wird vorbereitet …", „Sprachmodell wird geladen …", „Wird ausgewertet …" — jede Phase mit eigenem Text und Symbol |
| Datenspeicher defekt | `PersistenceErrorView` statt leerer App | — |

Kein Bereich zeigt im Leerfall eine leere Fläche, und kein Ladezustand ist
stumm. Was **nicht** existiert, ist ein Skelett-Layout oder ein Ladebalken beim
App-Start: Der Start liest nichts nach, und ein Platzhalter für etwas, das
sofort da ist, wäre eine erfundene Wartezeit.

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
| Automatische Mastery-Einschätzung | siehe §9.1 | mittel bis groß |
| Rolling Weighted Scheduler | siehe §9.2 | mittel |
| Beispielsätze zu einem Wort | Selbstbeziehung auf `Card` oder eigenes Modell | mittel |
| Echte Aussprachebewertung | eigener Service; die textuelle Vergleichsfunktion wird ersetzt, nicht erweitert | groß |
| iCloud-Sync | `ModelContainer` mit CloudKit-Konfiguration; erfordert, dass alle Properties optional oder mit Default sind | mittel |

Für den letzten Punkt eine praktische Vorsichtsmaßnahme, die **jetzt nichts
kostet**: Beim Modellentwurf in Phase 1 werden Properties mit sinnvollen
Defaults versehen. Falls iCloud-Sync später doch gewünscht ist, entfällt eine
schmerzhafte Migration. Das ist keine vorzeitige Optimierung, sondern eine
Konvention beim Schreiben des Modells.

### 9.1 Automatische Mastery-Einschätzung (Produktidee, nicht gebaut)

Aus dem Gerätetest der Phase 6: Zwei Konzepte wirkten für den Nutzer wie
dasselbe, und der manuelle Lernstatus im Karteneditor war deshalb eine Frage,
die niemand beim Anlegen einer Karte beantworten kann. Der Picker ist entfernt
(Task 6.10), der interne Status bleibt.

Langfristig soll die App den Kenntnisstand **selbst einschätzen**, statt ihn
abzufragen. Getrennt zu betrachtende Signale:

- die `SelfAssessment`s des Nutzers, **erster Versuch getrennt** von
  Wiederholungen — der erste Versuch ist der ehrliche Indikator
  ([learning-engine.md §6.1](learning-engine.md#61-statusänderung-nur-einmal-pro-mini-batch))
- zeitliche Stabilität: dieselbe Karte über mehrere Sessions und Tage
- die letzten *n* Reviews, nicht der Gesamtdurchschnitt
- ab Phase 9 zusätzlich der Recognition-Match als **weiteres** Signal

**Wichtig und nicht verhandelbar:** Die Spracherkennung in Phase 9 vergleicht
Text. Aus einem Match folgt **nicht** „korrekt ausgesprochen" — diese Aussage
darf die App nie treffen (CLAUDE.md, harte Regel 7).

Mögliche UX, noch nicht festgelegt: Bei ausreichender Evidenz schlägt die App
eine Stufe vor und hebt sie hervor, statt sie zu setzen — der Nutzer bestätigt
oder widerspricht. Kein Zwang, keine Wertung, kein automatisches Umschreiben
hinter dem Rücken des Nutzers.

**Was dafür fehlt:** `reviewCount` und `correctCount` sind Aggregate. Aussagen
wie „die letzten zehn Versuche waren richtig" lassen sich daraus **nicht**
ableiten. Dafür braucht es eine kleine Review-Historie — ein additives
`ReviewLog` oder eine Rolling History auf `Card`. Bewusst **jetzt nicht**
vorgezogen: Ohne den Konsumenten wäre es ein Schema mit unklarer Form.

**Seit Phase 11 gebaut, in Phase 13 zum Regelfall geworden.** Die hier als
„mögliche UX" beschriebene Idee — bei ausreichender Evidenz eine Stufe
*vorschlagen* statt sie zu setzen, der Nutzer bestätigt oder widerspricht — ist
ab Phase 13 die **einzige** Art, wie sich ein Lernstand automatisch bewegt; die
vier manuellen Tasten verlassen den Flow
([learning-engine.md §13](learning-engine.md#13-lernflow-und-assistierte-einstufung-phase-13)).
Von den vier oben genannten Signalen trägt damit nur eines: der
Recognition-Match. Die `SelfAssessment`s fallen als Signal weg, weil sie
niemand mehr abgibt, und zeitliche Stabilität ist weiterhin nicht kalibriert.
Die Folge ist benannt statt versteckt: Ohne Mikrofon bewegt sich kein
Lernstand von selbst ([§13.11](learning-engine.md#1311-was-das-kostet)).

### 9.2 Rolling Weighted Scheduler (Alternative, nicht gebaut)

Statt Mini-Batches könnte nach jeder Antwort probabilistisch die nächste Karte
aus dem **gesamten** Pool gezogen werden. Das würde das Arbeitsfenster ganz
auflösen und die Wiedereinstreuung als eigenes Konzept überflüssig machen.

Nicht in der Korrekturrunde der Phase 6 umgesetzt: Das dort beobachtete
Problem war ein Zyklus innerhalb des Fensters, und der ist mit zwei kleinen
Regeländerungen behoben (ungesehene Karten zuerst, `maxReinserts` = 1). Ein
neuer Scheduler hätte eine bewiesene, getestete Engine gegen eine unbewiesene
getauscht. Sollte sich das Batchmodell nach dem nächsten Gerätetest weiterhin
unnatürlich anfühlen, ist das die nächste zu evaluierende Architekturidee —
`BatchSelector` und `CardWeighting` bleiben dabei verwendbar, `SessionQueue`
würde entfallen.

---

## 10. Zusammenfassung der Architekturentscheidungen

| # | Entscheidung | Begründung |
| --- | --- | --- |
| A1 | Deployment Target iOS 26.0 | `SpeechAnalyzer` und der UI-freie `TranslationSession`-Initializer erfordern es; private App auf aktuellem Gerät |
| A2 | Learning Engine als reiner Swift-Code auf Wertetypen | einzige Stelle mit echter Logik → muss ohne Simulator testbar sein |
| A3 | Kein Repository-Layer, kein DI, kein Coordinator | SwiftData/SwiftUI decken den Bedarf ab |
| A4 | Gewicht und Fehlerzahl abgeleitet, nicht persistiert | vermeidet inkonsistente Zustände |
| A5 | Keine Antwort-Historie im MVP | für keine MVP-Funktion nötig, später additiv nachrüstbar |
| A6 | Zwei Tabs, Einstellungen per Sheet | Einstellungen sind selten benutzt; billig revidierbar. **In Phase 10 gegen den gebauten Bildschirm neu bewertet und bestätigt** (§6): drei bis vier bedienbare Stellen, davon eine nur bei mehreren Stimmen sichtbar |
| A7 | `TranslationHostView` nur für den Download-Pfad | Framework-bedingt; hält den Rest der Übersetzungslogik View-frei |
| A8 | Manuelle Bearbeitung schlägt Automatik immer | fachliche Kernanforderung, im Modell durch Merker abgesichert |
| A9 | Keine externen Dependencies | Wartbarkeit, kein Update-Zwang, kleinere Angriffsfläche |
| A10 | Kein Mocking von System-Frameworks | Aufwand/Nutzen bei dieser App-Größe |
| A11 | Kartenliste filtert in reinem Swift, nicht per dynamischem `#Predicate` | Ein `@Query` ohne Prädikat lädt sortiert, `CardFilter` verengt danach. Vermeidet die `fatalError`-Falle aus §3 vollständig, ist ohne View testbar, und bei einigen hundert Karten kostet es nichts. Neu bewerten, falls der Bestand vierstellig wird. |
| A12 | ~~Mehrere gewählte Tags werden mit **UND** verknüpft~~ — **überholt durch A32** | Ursprüngliche Begründung: Jeder Filter in der Kartenübersicht verengt das Ergebnis — Typ, Suche und Status ebenso. OR nur für Tags wäre inkonsistent und überraschend. Diese Konsistenz hat sich an der Benutzung als das falsche Ziel erwiesen — siehe A32. |
| A14 | ~~Neue Tags entstehen erst beim Speichern der Karte~~ **Neue Regel: `Hinzufügen` legt die Kategorie unmittelbar an** | **Überholt durch den Gerätetest der Phase 6.** Die alte Regel: Der Editor merkte getippte Namen nur vor, weil ein abgebrochener Editor sonst eine Kategorie hinterlassen hätte, die es in Phase 2 nicht löschen konnte. **Neue Regel:** `Hinzufügen` legt die Kategorie unmittelbar an und persistiert sie; sie bleibt bestehen, wenn die Karte abgebrochen wird, und ist für andere Karten verwendbar. Grund aus dem Gerätetest: Eine vorgemerkte Kategorie musste anders aussehen als eine echte — „neu"-Badge und rotes Minus —, und ein Tap darauf löschte statt auszuwählen. Damit gab es zwei Sorten Kategorie auf einem Bildschirm, von denen eine an einer Stelle löschbar war, an der Kategorien sonst gar nicht gelöscht werden können. Löschen und Umbenennen bleiben ausschließlich in `TagListView` mit Bestätigung (A15). Die Normalisierung aus A13 ist unverändert. |
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
| A25 | Filter hinter einem Knopf, Kategorienverwaltung daneben | Die Liste ist der Zweck des Bildschirms, die Filter werden gelegentlich benutzt — also bekommt die Liste den Platz. Lernstatus und Kategorien liegen zusammen auf einem Sheet hinter einem Symbol, das **gefüllt** ist, solange etwas filtert; `CardFilterSelection` beantwortet als Wertetyp „filtert etwas" und „wie viele Gruppen" und ist ohne View testbar. Die Filtersemantik selbst bleibt in `CardFilter` — sie war bei dieser Entscheidung unverändert und lautet seit A32 „ein Status, Kategorien mit ODER“. Die Kategorienverwaltung bleibt ein eigener Knopf: Sie **ändert** Daten, während der Filter nur die Ansicht einschränkt — beides in ein Menü zu legen würde zwei verschiedene Dinge gleich aussehen lassen. |
| A15 | Kategorien werden in place umbenannt, nie zusammengeführt | `TagManagement.rename` ändert die bestehende `Tag`-Entität. Ein neuer Tag plus Neuzuordnung würde dasselbe Ergebnis anstreben, aber jede Beziehung anfassen und dabei Fehler ermöglichen. Zielt der neue Name auf einen anderen bestehenden Tag, wird abgelehnt statt gemergt: Merging würde zwei Kategorien unumkehrbar verschmelzen, und der Nutzer hat kein Undo. |
| A26 | Kategorien im Lernen mit **ODER** — die zweite Hälfte, Kartenliste mit **UND**, ist **überholt durch A32** | Die beiden Bildschirme stellten zunächst verschiedene Fragen. Die Kartenliste fragt „welche Karte suche ich?" — dort verengt jeder Filter, und Kategorien mit ODER wären inkonsistent zu Typ, Suche und Status (A12 — dieses Argument ist durch A32 widerlegt). Der Lernbildschirm fragt „was soll ich jetzt üben?" — „Essen" und „Reisen" auszuwählen heißt „beides üben". Aus dem Gerätetest der Phase 6: Mit UND leerte die Auswahl einer zweiten Kategorie die Session, weil kaum eine Karte in zwei Kategorien liegt; wer den Stoff erweitern wollte, bekam das Gegenteil. Umgesetzt in `LearnSessionModel.matchesAnyCategory` (`tagKeys.isDisjoint(with:) == false`), keine Auswahl heißt weiterhin keine Einschränkung. Der **Kartentyp bleibt außerhalb dieser Regel** und läuft weiter über `CardFilter.apply(to:type:)` — Wörter und Sätze mischen sich nie, ODER gilt ausschließlich für Kategorien. Der Filter benannte den Unterschied im Fußtext, statt ihn erklären zu müssen: „Geübt wird alles aus **einer** der ausgewählten Kategorien." Diesen Filter gibt es seit A33 nicht mehr, und der Satz auch nicht: Er war über die Regel korrekt und über das Ergebnis irreführend — er klang, als werde nur eine der angekreuzten Kategorien benutzt. Auf dem Setup-Bildschirm steht jetzt „Geübt werden alle Karten aus den ausgewählten Kategorien." Beide Regeln standen in `categoryRulesAgreeBetweenContexts` direkt nebeneinander; seit A32 sichert derselbe Test die **Übereinstimmung** statt den Unterschied. |
| A27 | Eine Container-Gesture ist nie der tragende Weg für eine fachliche Aktion | Aus einer Regression im Gerätetest der Phase 6: Am Karteneditor hing ein Tastatur-Dismiss als `simultaneousGesture` an der `Form`. Simultane Erkennung **verschluckt** einen Tap nicht — aber sie **entzieht sich der Arbitrierung**: `simultaneousGesture` bedeutet ausdrücklich „zusätzlich zu den Gesten der Kinder erkennen", und sobald die Vorfahren-Gesture erkennt, wird der Touch im darunterliegenden UIKit-Control storniert (`cancelsTouchesInView`, Standard `true`). Der Druck des Buttons bricht ab, und zwar unabhängig vom Tastaturzustand — deshalb war der naheliegende Verdacht auf den Guard falsch, und deshalb blieb auch der zweite Tap wirkungslos. `.gesture` ohne Zusatz ist dagegen laut Doku „with a lower precedence than gestures defined by the view": erkennt das Kind, erkennt der Container gar nicht und kann nichts stornieren. Folge: Ein Tap auf `Hinzufügen` schloss nur die Tastatur, die Kategorie wurde nie angelegt, und weitere Taps blieben ebenso wirkungslos — unabhängig vom Tastaturzustand, weshalb der naheliegende Verdacht auf den Guard falsch war. Die zwischenzeitliche räumliche Eingrenzung (`SpatialTapGesture` gegen eine per `onGeometryChange` gemeldete Feldfläche) war doppelt falsch: Sie löste ein Problem, das bei Standardpriorität gar nicht existiert, und behielt die Ursache. **Regel:** Jeder fachliche Effekt liegt in der Aktion des Controls (`addCategory`, der Kategorie-Toggle). **Am Karteneditor gibt es deshalb gar keine Tap-Gesture mehr.** Die Annahme, dass die Standardpriorität von `.gesture` auch über die UIKit-Zellgrenze einer `Form`-Zeile trägt, hat der Gerätetest **widerlegt**: Die Kategorienzeilen ließen sich anschließend überhaupt nicht mehr an- oder abwählen — ausgewählt wurde eine Kategorie nur noch dadurch, dass man sie neu anlegte. Damit ist der in dieser Entscheidung vorgesehene Rückweg eingetreten und ausgeführt. Drei Varianten sind auf diesem Screen gemessen gescheitert: `simultaneousGesture` mit einem einfachen `TapGesture`, dieselbe räumlich eingegrenzt über `SpatialTapGesture` plus `onGeometryChange`, und `.gesture` mit Standardpriorität. **Keine weiteren Versuche** — auch nicht `highPriorityGesture`, Geometrie-Hit-Testing oder eine Delay-Konstruktion. Der Preis ist bewusst bezahlt: Ein Tap auf völlig freie Fläche schließt die Tastatur nicht mehr. Funktionierende Controls haben Vorrang. Der plattformeigene Weg aus einer Tastatur ist `scrollDismissesKeyboard(.interactively)`; er hängt an keiner Arbitrierung. **Rückweg, falls am Gerät doch ein Control eine Aktion verliert:** die Container-Gesture **entfernen** — dann kostet die freie Fläche eine Wischbewegung statt eines Taps. Nicht auf `simultaneousGesture` und nicht auf eine räumliche Eingrenzung ausweichen; beides ist gemessen gescheitert. Ein Button in einer `Form`-Zeile braucht außerdem `.buttonStyle(.borderless)`, sonst wirkt die ganze Zeile als Button und die Konkurrenzfläche wird unnötig groß. |
| A28 | Tonsandhi des dritten Tons nur **innerhalb einer Lexikoneinheit** | `你好` wird `níhǎo`, `展览馆` wird `zhánlánguǎn` — beide sind je **ein** CC-CEDICT-Stichwort, also eine sichere Domäne. Über eine Wortgrenze hinweg wird **nicht** angewandt: `我很好` bleibt `wǒ hénhǎo`, das führende `我` behält seinen dritten Ton. Grund ist keine Bequemlichkeit, sondern die Quellenlage — Duanmus Analyse lässt die Regel zyklisch je Fuß greifen und **optional** zwischen zwei Zweigen, und die konkrete Realisierung hängt an prosodischer Gruppierung, syntaktischer Verzweigung, Fokus und Sprechtempo. Eine automatische Entscheidung wäre so oft falsch wie richtig. Technisch trägt jede Silbe eine `unit`-Nummer (`PinyinSyllable`): ein Stichwort ist eine Unit, jeder Zerlegungsteil und jeder Fallback bekommt seine eigene. Damit steckt die Domänengrenze in der Datenstruktur und nicht in einer Bedingung im Regelcode. **Innerhalb einer Unit entscheidet zusätzlich die Verzweigung**, und zwar über eine zweite Nummer, den `foot`: Bei drei dritten Tönen gibt die Quelle zwei Muster — 双单格 `[[AB]C]` ergibt 2-2-3 (`展览馆` → `zhánlánguǎn`), 单双格 `[A[BC]]` ergibt 3-2-3 (`小老鼠` → `xiǎoláoshǔ`). Gleiche Tonfolge, verschiedenes Ergebnis; den Unterschied macht allein die Klammerung. `ToneSandhi` wendet die Regel deshalb **zyklisch** an: erst innerhalb des Fußes auf den lexikalischen Tönen, dann über die Fußgrenze auf dem **Oberflächenton** des Nachbarn. Im 双单格 trägt die Mittelsilbe dort noch ihren dritten Ton und wird geändert; im 单双格 ist sie schon zum zweiten Ton geworden und blockiert damit die erste Silbe. Die Klammerung steht nicht in den Daten, aber ein **Teil-Stichwort** ist ein brauchbarer Zeuge: `PinyinService.footSplit` fragt längstes Präfix und längstes Suffix ab, und genau eines von beiden entscheidet. Gemessen über die Dritt-Ton-Wörter des Corpus: 14 von 17 werden so entschieden, und alle 14 stimmen mit den Quellen. Sind beide oder keines Stichwort (`小雨伞` ist `小雨` **und** `雨伞`, `导火索` ist keines), wird in der Mitte geteilt — das ist die konservative Richtung: für ein rechtsverzweigendes Wort die Quellenform, für ein linksverzweigendes bloß der Wörterbuchton auf der ersten Silbe. Was es nie erzeugt, ist ein dritter Wert, den keine Quelle stützt — und genau das täte eine gleichförmige Anwendung von links. **Das war der erste Anlauf, und das Review hat ihn gefunden**: `小老鼠` kam als `xiáoláoshǔ` heraus, was weder Wörterbuch- noch Quellenform ist, und der Corpus meldete es als Erfolg, weil sein Sollwert aus derselben Annahme stammte. Kategorie E des Corpus steht seither von Hand. **Zwei weitere Regeln werden bewusst nicht angewandt:** dritter Ton vor **neutralem** Ton, weil die Variation nicht vorhersagbar ist — 北京语言大学s 现代汉语 gibt beide Realisierungen an, `214+轻声→35` (打扫, 想想) und `214+轻声→21` (李子, 姐姐) —, und der neutrale Ton selbst, der ausschließlich aus den Daten kommt. **`一` und `不` sind davon ausgenommen** und wirken lokal über Wortgrenzen: Ihre Regeln hängen am Zeichen und an der unmittelbar folgenden Silbe, nicht an einer prosodischen Domäne. Deshalb wird `一天` zu `yìtiān`, obwohl es kein Stichwort ist. Satzzeichen bleiben als tonlose Grenze in der Silbenkette erhalten (`PinyinSyllable.barrier`), sonst hätte `他不。对了` über den Punkt hinweg `bú` ergeben. |
| A31 | Die Sprachausgabe bekommt **Hanzi**, nie Pinyin — und ist von `needsReview` entkoppelt | Der Utterance-Text ist immer der chinesische Text der Karte. Das ist keine Bequemlichkeit, sondern die Grenze zwischen zwei Aufgaben: Unsere Pinyin-Schicht ist eine **sichtbare Lernhilfe** (A29), Apples Synthese ist die **hörbare Aussprache**. Gäbe man ihr eine lateinische Umschrift, würde sie Buchstaben aussprechen statt Chinesisch, und unsere Tonregeln würden zu einer zweiten Sprachsynthese, die niemand gebaut hat und niemand pflegt. Auch ein **von Hand korrigiertes** Pinyin ändert die Eingabe nicht: Es ist die Notiz des Nutzers an sich selbst, keine Aussprachevorschrift für Apple. Ebenso ausgeschlossen sind IPA, SSML, Audio-Postprocessing und Cloud-TTS — spricht Apple ein Hanzi reproduzierbar falsch, wird das dokumentiert und nicht heimlich umgangen. **Zweite Hälfte der Entscheidung:** `PinyinResolution.needsReview` sagt nichts über die Sprechbarkeit. `东西` trägt den Prüfhinweis, weil sich seine *Lesung* nicht eindeutig bestimmen lässt — Apple entscheidet sie selbst, und die Karte bleibt hörbar. Die beiden zu koppeln würde genau die Wörter stumm schalten, die man am dringendsten hören will. Umgesetzt in `SpeechSynthesisService.canSpeak`, das ausschließlich auf Han-Schrift prüft — dieselbe Frage, die der Pinyin-Resolver stellt, damit „brauchbares Chinesisch“ in der App eine Bedeutung hat. |
| A32 | Kategorien in der Kartenliste mit **ODER** statt UND — und die Liste ist ein **Akkordeon** | Zwei Änderungen, eine Ursache: Die Liste war zu hoch, um sie zu überblicken, und ihr Kategoriefilter beantwortete die falsche Frage. **Erstens die Semantik.** A12 hatte UND aus Konsistenz gewählt: Typ, Suche und Status verengen, also sollten Kategorien es auch. Gemessen an der Benutzung war das Konsistenz um den Preis des Nutzens — und zwar genau die Beobachtung, die schon im Gerätetest der Phase 6 den Lernbildschirm auf ODER gebracht hat (A26): In einer privaten Sammlung liegt kaum eine Karte in zwei Kategorien, also **leert** die zweite Auswahl das Ergebnis, statt es zu erweitern. Wer „Essen“ und „Reisen“ ankreuzt, will beides sehen. Damit gilt jetzt in **beiden** Bildschirmen dieselbe Regel, und die Kartenliste braucht eine Erklärung weniger. Die anderen Dimensionen bleiben unangetastet: Typ, Suche und Status verengen weiter, die Kategorien sind **eine ODER-Gruppe innerhalb einer UND-Kette**. Umgesetzt in `CardFilter.matchesTags` (`isDisjoint(with:) == false`, dieselbe Zeile wie in `LearnSessionModel.matchesAnyCategory`); Filterfußtext und Leerzustand sagen es beide. **Zweitens die Zeilenhöhe.** Eingeklappt zeigt eine Zeile nur den deutschen Text — einzeilig abgeschnitten, damit ein Satz die Zeile nicht vierzeilig macht — plus den Lautsprecher aus Phase 7. Hanzi, Pinyin und Kategorien erscheinen erst aufgeklappt. Höchstens **eine** Karte ist offen, und das ist keine Regel, die jemand durchsetzt: `CardExpansion.toggled` antwortet mit einem einzelnen Optional, es gibt also keinen Platz für eine zweite. Der Zustand wird **nicht** persistiert — nach dem Start soll eine ruhige Liste dastehen. **Drittens der Weg in den Editor.** Der Tap auf die Zeile bedeutet ausschließlich auf- und zuklappen; der Editor hängt allein am sichtbaren Stift, der mit den Details erscheint. Kein zweiter Tap, kein Long-Press, keine unsichtbare Affordanz. Damit liegen drei Tap-Ziele in einer Zeile, was genau die Lage aus A27 ist — angewandt wird deshalb die Lösung, die dort überlebt hat: **drei Geschwister-Buttons**, keine Container-Gesture, kein `simultaneousGesture`, kein Hit-Testing. Die Zeile trägt `.buttonStyle(.plain)`, die beiden Steuerungen `.borderless`. **Viertens die Sortierung.** Fünf Reihenfolgen in `CardListArrangement`, Standard bleibt Deutsch A–Z — die Reihenfolge, die die Liste vorher schon hatte, damit das neue Menü nichts verändert, bis jemand es benutzt. Jede Reihenfolge bricht Gleichstände über die stabile `id` auf, sonst sortiert sich die Liste zwischen zwei Neuzeichnungen um. `Kategorie A–Z` gruppiert in **echte Sections** statt nur unsichtbar zu sortieren, und dafür braucht es eine eigene Regel: Eine Karte mit drei Kategorien hätte drei plausible Plätze. `CardListArrangement.sectionTitle` entscheidet sich für genau einen — bei aktivem Filter die alphabetisch erste **ausgewählte** Kategorie, sonst die alphabetisch erste überhaupt, sonst `Ohne Kategorie`, das immer zuletzt steht. Weil die Funktion je Karte **eine** Antwort gibt, ist „keine Karte doppelt“ strukturell und nicht geprüft-und-gehofft; die naheliegende Implementierung — über die Kategorien laufen und ihre Karten sammeln — ist genau die, die dupliziert. Die Sortierauswahl wurde zunächst **nicht** persistiert, mit der Begründung, die App speichere keine einzige UI-Präferenz und dafür wäre ein Schemafeld nötig. Der zweite Teil war falsch — **überholt durch A33**, wo sie in `UserDefaults` landet. |
| A33 | Vier UX-Korrekturen nach dem Gerätetest: **eine** Animation, persistierte Sortierung, `+` in der Kategorienverwaltung, und die Kategorien im Lernen sind kein Filter mehr | **Erstens die Animation.** Auf- und Zuklappen wirkten am Gerät unsynchron: Details schienen von oben hereinzufliegen, verschwanden langsamer als sie kamen, und die Zeilenhöhe bewegte sich nach ihrem eigenen Takt. Ursache war nicht eine eigene Transition — es gab nie eine —, sondern dass SwiftUI die neuen `Text`-Zeilen als Einfügungen in eine `List` behandelt und jede für sich animiert, während `.animation(.default, …)` gleichzeitig die Höhe bewegt. Aufklappen ist **ein** Ereignis und muss als eine Bewegung lesen, also gibt es genau eine kurze Animation (`.easeInOut(duration: 0.15)`), gebunden an genau den einen Zustand, der sich ändert, und ausdrücklich **keine** `.transition` auf Hanzi, Pinyin oder Kategorien. **Und genau das ist eingetreten.** Der zweite Gerätetest meldete die Details weiterhin zeitlich versetzt und zusätzlich ein kurzes Wackeln des deutschen Textes. Also ist die Animation ersatzlos entfernt: keine `.animation` mehr auf der Liste, und der Zustandswechsel läuft in einer `Transaction` ohne Animation, weil sonst die implizite Animation des umgebenden Kontexts die Zeile weiterhin erreicht. Auf- und Zuklappen ist jetzt sofort. Das war keine schlecht gewählte Kurve: Eine `List` animiert die neuen Zeilen als Einfügungen, während die Höhe getrennt interpoliert, und diese beiden werden auch bei 0,15 Sekunden nicht zu einer Bewegung. `matchedGeometryEffect` oder eine eigene Geometrie-Lösung wären für eine Zeile, die höher wird, eine grobe Übertreibung gewesen — und hätten das Problem nicht gelöst, sondern verziert. Ruhiges UI schlägt Bewegung. **Zweitens die Sortierung, und damit eine Korrektur an A32.** Dort stand, die Sortierauswahl werde nicht persistiert, „dafür wäre ein Schemafeld nötig". Das war schlicht falsch: Eine lokale UI-Präferenz gehört nicht ins SwiftData-Schema, sondern in `UserDefaults`, und `@AppStorage` liefert genau das ohne eine Zeile Infrastruktur. Gespeichert wird der **Raw Value** als String, und die Cases tragen ihre Raw Values ausgeschrieben, weil ein Umbenennen sonst still die gespeicherte Wahl aller Nutzer entwerten würde. Gelesen wird ausschließlich über `CardSortOrder.restored(from:)`, das bei unbekanntem, leerem oder fehlendem Wert auf Deutsch A–Z zurückfällt — was in `UserDefaults` steht, hat irgendeine frühere oder künftige Version dort hinterlassen, und ein entfernter Case darf keinen leeren Bildschirm ergeben. Die Präferenz betrifft nur die Kartenliste; das Lernen hat keine Sortierung. **Drittens die Kategorienverwaltung.** Sie konnte bisher umbenennen und löschen, aber nicht anlegen — Kategorien entstanden nur nebenbei im Karteneditor. Jetzt gibt es das native `+` oben rechts als **primären** Einstieg. Es baut keine zweite Erstellungslogik: Normalisierung, Längengrenze und Duplikatprüfung kommen aus `TagNormalization`, dieselbe Quelle, aus der Umbenennen und der Editor schöpfen, und `TagNormalization.creationProblem` teilt sich sogar den Problemtyp mit dem Umbenennen, damit beide Wege denselben Namen akzeptieren. Was sich unterscheidet, ist allein das Ergebnis bei einem **bereits vergebenen** Namen: Der Editor wählt dann die vorhandene Kategorie aus, weil er sie für die gerade geschriebene Karte braucht; die Verwaltung meldet den Namen als vergeben, weil sie nichts auszuwählen hat. Neu anlegen können beide — das ist A14 und bleibt so. Deshalb behält `CardEditorModel.addNewTag` seinen eigenen Pfad, statt in diesen gebogen zu werden — sein Verhalten ist abgenommen und wird hier nicht angefasst. **Viertens das Learn-Setup.** Die Kategorien saßen dort hinter einem Trichtersymbol namens „Filter" — dieselbe Geste wie in der Kartenliste, aber die falsche Bedeutung. In der Kartenliste ist ein Filter administrativ: Er verbirgt Zeilen einer Liste, die es ohnehin gibt. Im Lernen **sind** die Kategorien die Wahl; „Was übe ich jetzt?" ist die ganze Frage des Bildschirms, und ihre Antwort lag hinter einem Symbol, das „hier ist etwas versteckt" sagt. Also stehen sie jetzt direkt auf dem Bildschirm, in der Reihenfolge der Entscheidung: Typ, Kategorien, Start. Kein Sheet, kein Filterknopf, kein Lernstatusfilter als Ersatz — der bliebe die Aufgabe der Gewichtung. Dargestellt als adaptives Raster aus Chips, ausgewählt über `.borderedProminent` gegen `.bordered`, weil das die plattformeigene Aussage „dieses ist gewählt" ist und Dark Mode wie Dynamic Type ohne Pflege übersteht. **Die Alle-Semantik ist ausdrücklich eine Darstellung, kein zweiter Zustand:** Die Auswahl bleibt `Set<String>`, leer heißt weiterhin „keine Einschränkung", und der Alle-Chip leuchtet genau dann, wenn die Menge leer ist. Ein eigenes Flag daneben wäre der Weg zu „alles gewählt und gleichzeitig nichts gewählt"; `LearnCategorySelection.isEverything` ist deshalb eine Funktion über die Menge und kein gespeicherter Wert. Verwalten bleibt draußen — und zwar aus dem **Learn-Setup**, nicht generell: Umbenennen und Löschen gibt es nur in der Kategorienverwaltung, Anlegen dort und im Karteneditor (A14). Hier nichts davon, denn eine unumkehrbare Aktion einen Fehltipp neben „Session starten" zu legen wäre die schlechteste Stelle dafür. |
| A34 | Der vollständig aufgedeckte Zustand ist in **beiden** Abfragerichtungen dieselbe View — und die Stufen davor bleiben getrennt | Modus A und Modus B stellen verschiedene Fragen und nehmen verschiedene Wege dorthin, zeigen aber am Ende **dieselben vier Dinge**: Lautsprecher, Hanzi, Pinyin, deutsche Bedeutung. Der Gerätetest der Phase 8 fand die Anordnung aus Modus B klarer als die aus Phase 6, also wurde Modus A darauf gezogen — großer Lautsprecher oben, das Deutsche als letzte Zeile statt als geschrumpfte Überschrift. Umgesetzt über eine geteilte `LearnRevealedAnswerView` statt über zwei Dateien, die sich heute einig sind: Zwei Kopien derselben Typografie laufen bei der dritten Änderung auseinander, und zwar unsichtbar, weil beide für sich weiter kompilieren. Mitgeteilt wird auch der große Lautsprecher (`LearnPromptSpeaker`), weil Modus B ihn schon **vor** dem Aufdecken braucht und eine zweite Kopie genau dieselbe Drift erzeugt hätte. **Bewusst nur der Endzustand.** Die Stufen davor sind wirklich verschieden — Modus A zeigt das Deutsche und bittet, das Chinesische zu sagen; Modus B spielt Ton und zeigt auf Wunsch die Schrift —, und eine View, die beides mit abdeckte, bräuchte je einen Parameter pro Unterschied und wäre keine geteilte Darstellung mehr, sondern eine Prompt-Abstraktion. **Nebenwirkung, bewusst in Kauf genommen:** In Modus A verschwindet damit die Animation, die das Schrumpfen des deutschen Textes weichzeichnete — es gibt kein Schrumpfen mehr, Aufdecken tauscht das ganze Layout. Und die Bewertungsleiste springt beim Aufdecken vom unteren Rand in die Mitte, weil der unaufgedeckte Zustand ein `Spacer`-Layout behält, das laut Vorgabe unverändert bleiben musste. **Zur Absicherung, offen gesagt:** Welche View bei welcher Stufe erscheint, entscheidet in `PromptAudioToGermanView` ein erschöpfender `switch` über `PromptStage` statt einer Bedingung. Das ist kein Stil, sondern die Lehre aus dem Prüflauf: Als dort eine Bedingung stand, hätte das Vertauschen zweier ähnlich klingender Regeln (`showsHanzi` statt `allowsAssessment`) die deutsche Bedeutung in den Zwischenschritt gestellt, ohne dass ein Test rot geworden wäre. Ein `switch` hat nichts zu vertauschen, und eine später hinzugefügte Stufe kompiliert nicht, bis jemand entscheidet, wohin sie gehört — nachgemessen. Gleichzeitig verloren drei Sichtbarkeitsregeln (`showsGerman`, `showsPinyin`, `showsSpeaker`) durch die geteilte View ihren letzten Aufrufer; sie sind entfernt worden, statt als Spiegel stehenzubleiben, den Tests abfragen und der Bildschirm nicht. **Was damit ausdrücklich nicht behauptet wird:** Dass ein Test das Durchsickern der Bedeutung fängt. Verschiebt jemand `.hanziShown` in den aufgedeckten Zweig, bleibt die Suite grün — gemessen. Getragen wird die Zusage von der Struktur (die verdeckte Anordnung enthält weder Deutsch noch Pinyin) und vom Gerätetest, und die Kommentare im Code sagen genau das und nicht mehr. |
| A35 | `ReviewLog` als eigenes Modell mit `.cascade` von `Card`, statt Aggregate auf `Card` | Ein Versuch ist eine Beobachtung mit eigenen Feldern; als Zähler auf der Karte wäre er nicht rekonstruierbar. `.cascade`, weil ein Eintrag ohne seine Karte nichts beschreibt — anders als `tags`, die `.nullify` sind |
| A36 | Automatisches Weitergehen ändert den Lernstand **nicht** — **in der Form überholt durch A40**, in der Substanz übernommen | Es spart eine Frage, die die App nicht rechtfertigen kann, und vergibt keine Beförderung, die niemand erteilt hat. Der Status bewegt sich nur über `StatusTransition` nach einem Tipp |
| A37 | Der Session-Sprachmodus startet Aufnahmen, beendet sie aber nicht | Q11 hat gemessen, dass auf iOS 26.6 kein Apple-Signal das Äußerungsende meldet und eine eigene Energieregel aus einem einzigen ruhigen Setting geraten wäre. Ein falsches Endpointing schadet mehr als ein zusätzlicher Tap |
| A38 | **Ein** Versuch pro Karte ohne Zutun, danach braucht es einen Tap | Ohne diese Grenze würde „Nichts erkannt" sofort die nächste Aufnahme starten, die wieder nichts fände — eine Schleife mit offenem Mikrofon |
| A39 | Ein Bedienelement armiert den Modus und startet die erste Aufnahme | Ein zweiter Schalter wäre eine zusätzliche Erklärung für ein Feature, dessen ganzer Zweck ein Tap weniger ist. Bewusst in Kauf genommene Folge: Wer genau eine gesprochene Antwort will, bekommt auf der nächsten Karte trotzdem eine Automatik |
| A30 | Die Zwischenrepräsentation trennt **Oberflächenton** und **Grundton** | `一个` steht als `yi1 ge5` und wird `yíge` gesprochen: Die `一`-Regel wird davon ausgelöst, was `个` **zugrunde** ist — ein vierter Ton —, nicht vom neutralen Ton an der Oberfläche. `PinyinSyllable` hält beides: `lexicalTone` ist die Oberfläche und bleibt in der Ausgabe neutral, `underlyingTone` ist der Auslöser. **Nur die `一`- und `不`-Regel lesen den Grundton.** Die Dritt-Ton-Regel bleibt bewusst auf dem Oberflächenton, weil dritter Ton vor *neutralem* Ton variabel ist und absichtlich nicht angewandt wird (A28) — ihr einen tieferen Auslöser zu geben würde eine dokumentierte Zurückhaltung in ein Raten verwandeln. Den Grundton liefert `cedict-base-tones.txt`, eine **Ableitung des schon gebündelten Assets** und keine neue Datenquelle: Dasselbe Zeichen erscheint in anderen Stichwörtern mit vollem Ton, `一个人` gibt `ge4`. Gezählt wird über alle reinen Han-Stichwörter, aufgeschrieben der vorherrschende Ton ab neun von zehn Vorkommen. **Vorherrschend statt eindeutig**, und das ist wesentlich: `个` liest `ge4` 86-mal, `ge5` 43-mal, `ge3` genau einmal — wer Eindeutigkeit verlangt, bekommt für den entscheidenden Fall keine Antwort. Dazu eine Mindestevidenz von fünf Vorkommen, aus dem Review: ohne sie ruhten 59 Zeilen auf ein bis drei Belegen, und `们 men` ergab 2 allein aus dem Ortsnamen 图们. 407 von 538 Neutralton-Silben bekommen damit einen Grundton; die 131 übrigen antworten `nil`, und `nil` heißt „keine Regel anwenden", nie „etwas auswählen". Vorberechnet statt zur Laufzeit gezählt, weil derselbe Zensus gemessen 314 ms kostet und `ChineseLexicon` auf dem Main Actor liegt — im `.task` des Editors wäre das ein merkbares Stocken. Aus dem Accuracy Pass der Phase 6.5, wo `一个` der höchstpriorisierte Fehler war. |
| A29 | Sichtbares Pinyin zeigt die **Lernaussprache**, nicht die Wörterbuchschreibung | `不对` steht im Feld als `búduì`, nicht als `bùduì`; `一点` als `yìdiǎn`, nicht `yīdiǎn`. Das ist eine bewusste Abweichung von der üblichen Schreibung, und sie ist normativ gedeckt: GB/T 16159-2012 §6.5.2 schreibt `„一"、„不"一般标原调，不标变调` und ergänzt im selben Absatz `在语言教学等方面，可根据需要按变调标写` — im Sprachunterricht darf nach der Tonveränderung geschrieben werden. Diese App **ist** Sprachunterricht. Angewandt wird nur, was obligatorisch und lokal entscheidbar ist (A28); alles Variable bleibt in der Wörterbuchform, was die harmlose Richtung ist, weil jedes Wörterbuch sie druckt. `PinyinResolution.transformations` sagt kategorial, welche Regelklasse gegriffen hat — `thirdTone`, `yi`, `bu` —, damit Tests und Benchmark das zuordnen können. **Keine Confidence-Werte und kein Ereignisprotokoll.** Eine Tonregel ändert `needsReview` nie in eine Richtung: Sie macht eine sichere Lesung nicht prüfbedürftig, und sie heilt kein Rateergebnis. |
| A40 | Der Lernflow stellt höchstens **eine binäre Frage** je Karte; die vier `SelfAssessment`-Tasten verlassen ihn (Phase 13) | *Nochmal / Schwer / Gut / Sicher* kam **nach** dem Aufdecken, und dort ist der Unterschied zwischen *Schwer* und *Gut* eine Stimmung, keine Beobachtung. Phase 11 hat die Frage nur im sauberen Fall gespart — in jedem anderen Fall stand sie weiter da, also war der Tap nie weg. Ab Phase 13 steht dort *Weiter*, und nur wo Evidenz für einen konkreten Schritt nach oben liegt, eine Zustimmungsfrage. Damit fällt auch das automatische Weitergehen aus A36 weg: Der aufgedeckte Zustand wird **immer** gezeigt, was zugleich den Phase-11-Vorbehalt „Kartenwechsel ohne Rückmeldung zu abrupt" erledigt |
| A41 | **„Aufgeben" ist die einzige Aussage über Nichtwissen** und der einzige Auslöser der Wiedereinstreuung — **Beschriftung und Wiedereinstreuung sind dabei zwei getrennte Prädikate** | Ohne *Nochmal* hätte §5 keinen Auslöser mehr, und die im Gerätetest der Phase 6 korrigierte Wiedereinstreuung — ungesehene zuerst, `maxReinserts` = 1 — wäre aus dem normalen Flow unerreichbar. Sie hängt jetzt an *Aufgeben*: Position und Obergrenze unverändert, aber **ohne** Statusänderung und ohne negative Evidenz, denn ein Downgrade gibt es nicht mehr. Ein Mismatch streut ausdrücklich **nicht** wieder ein — er ist keine negative Evidenz, und danach zu planen wäre eine Handlung auf ein Signal, dem die App nicht traut. **Die Trennung ist die eigentliche Entscheidung:** Der Knopf heißt in Modus A in jedem Zustand *Aufgeben*, auch ohne Mikrofonfreigabe und ohne Erkennung — ein Bedienelement, das sich je nach Mikrofonzustand umbenennt, ist schwerer zu lernen als eines, das es nicht tut. Wieder eingestreut wird aber nur, wenn eine Aufnahme möglich war, sonst würde auf einem Gerät ohne Erkennung **jeder Batch doppelt so lang**. Dass derselbe Knopf unsichtbar unterschiedlich weiterplant, ist vertretbar, weil der Unterschied reine Terminplanung ist — er berührt weder Lernstand noch Evidenz noch eine Aussage an den Lernenden |
| A42 | Eine Statusänderung braucht **Zustimmung**, und eine Ablehnung wird **persistiert** | Der Vorschlag war schon in Phase 11 nie ein Ergebnis; ab Phase 13 ist die Zustimmung der einzige Weg nach oben. Eine Ablehnung, die nur im Speicher lebt, wäre eine Höflichkeit für zehn Minuten — beim nächsten Start stünde derselbe Vorschlag wieder da. Sie setzt die positive Evidenz für genau diesen nächsten Status auf null und zählt selbst nicht als Treffer. Festgehalten wird das in **zwei** additiven, optionalen Feldern auf `ReviewLog` — `suggestedStatus` und `suggestionDecision` (`accepted`/`declined`) —, und `assessment` bleibt dabei ausdrücklich unberührt: Es bedeutet weiter „der Lernende hat eine der vier Selbsteinschätzungen abgegeben", und der neue Flow schreibt es **niemals**. Eine Zustimmung dort abzulegen, weil sie denselben Übergang erzeugt, würde historische Selbsteinschätzung und bestätigten Vorschlag rückwirkend ununterscheidbar machen. **Semantische Eindeutigkeit vor der gesparten Property**, Gegenrechnung in §3. Ausdrücklich **keine** zweite Bewertungshistorie und nichts davon in den `UserDefaults` |
| A43 | Evidenz zählt **je Richtung und je Ausgangsstatus** — das ersetzt den `.new`-Riegel aus Phase 11 | Phase 11 verweigerte `.new` jeden Vorschlag, weil eine von Hand zurückgesetzte Karte ihre Historie behält und sofort eine Beförderung angeboten bekommen hätte. Der Riegel war das richtige Verhalten aus dem falschen Grund: Er prüfte den Status, wo die **Herkunft** der Evidenz das Problem war. Zählt ein Lauf nur Versuche mit demselben `previousStatus`, ist die zurückgesetzte Karte ohne Evidenz, eine wirklich neue Karte kann ihren ersten Vorschlag bekommen, und zwei Beförderungen hintereinander sind unmöglich — drei Eigenschaften aus einer Bedingung. Die Richtungsregel steht daneben, weil ein Modus-B-Versuch keine Information über Modus A trägt und deshalb auch keine zerstören darf |
| A44 | Sprachausgabe entwaffnet den Session-Sprachmodus nur bei **verdeckter** Karte | Verengung der Phase-12-Regel, erzwungen durch A40: Der Lernende landet jetzt auf **jeder** Karte im aufgedeckten Zustand, in dem der große Lautsprecher steht. Einmal die Antwort anhören hätte den Sprachmodus jedes Mal gekostet und die Phase-12-Funktion praktisch abgeschafft. Der Grund der Regel — nie gleichzeitig sprechen und aufnehmen, und die Entscheidung darüber nicht wegnehmen — greift dort nicht: Die Aufnahme dieses Versuchs ist beendet, die nächste beginnt erst nach dem Kartenwechsel, und der stoppt die Sprachausgabe ohnehin. **Damit wird diese Reihenfolge tragend und ist festgeschrieben:** Sprachausgabe stoppen → Kartenwechsel → erst danach die automatische Aufnahme, an **einem** Beobachter je Kartenübergang. Nach der Verengung ist sie das Einzige, was Ton und Mikrofon noch auseinanderhält |
| A45 | Ein abgebrochener Aufnahmeversuch ist **kein** Versuch | *Stop* verwirft, ohne auszuwerten, aufzudecken oder etwas zu protokollieren: kein `ReviewLog`-Eintrag, kein `reviewCount`, keine Evidenz. Ohne diesen Weg kostet ein verstolpertes „Moment, nochmal" einen Versuch **und** ein Aufdecken. Der Sprachmodus bleibt dabei aktiv — abbrechen ist keine Entscheidung über die nächste Karte —, aber A38 gilt: Auf **derselben** Karte startet nichts von selbst nach, ein weiterer Anlauf braucht einen Tap |
| A46 | Der Lernstand wird **von Hand** in der Kartenübersicht korrigiert, und die Korrektur setzt eine **Evidenzgrenze** | Phase 13 nahm mit *Nochmal* und *Schwer* den letzten abwärts führenden Pfad heraus und verwies für die Korrektur auf §6.2 — das seit Phase 1 spezifiziert, aber nie gebaut war. Das unabhängige Review fand den Widerspruch; eingelöst statt umformuliert, weil eine Karte, die zwei zufällige Erkennungstreffer nach oben getragen haben, sonst dauerhaft dort bliebe und die False-Accept-Rate ungemessen ist. Kontextmenü auf der Zeile, kein Picker im Editor (Phase 6 hat ihn aus gutem Grund entfernt), kein Bestätigungsdialog. **Keine Lernantwort:** kein `ReviewLog`, keine Zähler, keine Wiedereinstreuung. **Aber eine Grenze:** `Card.classificationEvidenceResetAt`, weil die alten Reviews einer auf *Mittel* zurückgesetzten Karte nach der Gleichstatus-Regel sonst sofort erneut *Mittel → Gut* auslösen würden. Ein eigenes Feld, nachdem jedes vorhandene geprüft wurde — `lastReviewedAt` bewegt sich bei jedem Review, `previousStatus` ist das Feld, an dem der Fall scheitert. Gelesen wird die Grenze beim Übergeben der Historie, nicht in der Regel: so bleibt `Learning/` ohne Uhr |
| A47 | Die AI-Erklärung bekommt **keinen** Service in der Environment; eine `LanguageModelSession` entsteht je Anfrage und wird verworfen | Genau umgekehrt zu A31: `SpeechSynthesisService` **muss** seine `AVSpeechSynthesizer`-Instanz halten, weil Apple es verlangt. Hier verlangt Apple das Gegenteil — „For a single-turn interaction, create a new session each time" —, und eine gehaltene Session würde ihr 4096-Token-Fenster mit jeder Anfrage voller machen. `SystemLanguageModel.default` ist bereits eine geteilte, `Observable` Instanz, die Apples eigenes Beispiel direkt in der View hält; ein Service, der nichts hält, wäre eine Schicht um des Symmetriegefühls willen. **Nebeneffekt, der ein Fehlerfall erledigt:** Weil keine Session eine zweite Anfrage erlebt, ist `concurrentRequests` nicht abgefangen, sondern unmöglich |
| A48 | Das Erklärungs-Sheet bekommt **`ExplainedCard`** — vier Strings — und niemals eine `Card`, einen `ModelContext` oder das Sessionmodell | Die Phase verspricht, nichts zu ändern: nicht die Karte, nicht den Lernstand, nicht eine laufende Session. Ein Kommentar wäre die billigste Form dieses Versprechens, ein Test die zweitbilligste — beide prüfen nur, was jemand aufgeschrieben hat. Übergibt man dem Sheet stattdessen nichts, womit es schreiben könnte, trägt der **Compiler** die Grenze. Dasselbe gilt für den Zustand: `@State` in der View statt einer Eigenschaft auf `LearnSessionModel`, damit „das Nachschlagen berührt die Session nicht" eine strukturelle Tatsache ist und keine Behauptung |
| A49 | Die Beispielgrenze wird **in der App** erzwungen, nicht nur im Schema | `@Guide(.maximumCount(2))` sagt es dem Modell, und auf dem Gerät hat es sich in allen fünf Messungen daran gehalten. Eine Garantie ist das nicht: Apple beschreibt constrained sampling als Zusage über das **Format**, nicht über die Elementzahl. Ein Test darüber ließ sich außerdem nicht bauen — die `Codable`-Kodierung von `GenerationSchema` ändert sich beim Entfernen des Guides **nicht**, ein differenzieller Test war also mit und ohne Guide grün und damit wertlos (gemessen, nicht vermutet). `CardExplanation.shownExamples` schneidet deshalb auf zwei ab, und **das** ist falsifizierbar. Modellausgabe wird nicht darauf vertraut, ihre Seite der Abmachung zu halten |
| A50 | `AIAvailability` glaubt der Sprachprüfung **nur**, wenn das Modell verfügbar ist | `supportsLocale(_:)` ist synchron, kostenlos und wirft nicht — aber solange das Modell nicht installiert ist, hat es nichts, woraus es antworten könnte. Würde man ihm dort glauben, würde ein `modelNotReady`, das in einer Minute vorbei ist, als `languageUnsupported` gelesen und der Einstieg **dauerhaft** ausgeblendet. Also erst Apples eigenes Urteil, die Sprachen danach. Dieselbe Denkart wie bei der Locale-Validierung in Phase 9: Nicht jede API-Antwort beantwortet die Frage, die man gestellt hat |
| A51 | Auf dem **Lernbildschirm** erscheint der Erklärungs-Einstieg nur, wenn er benutzbar ist — überall sonst wird ein behebbarer Zustand sichtbar und begründet gezeigt | Zwei dokumentierte Ziele geraten hier aneinander: „sichtbar, deaktiviert, mit Erklärung" für die behebbaren Zustände, und Phase 13, die den Lernbildschirm gerade von Prosa befreit hat. Die Begründung ist kein Satz, sondern ein Dauerzustand — sie stünde unter **jeder** aufgedeckten Karte, die ganze Session lang, für jemanden, der Apple Intelligence nie einschaltet. Dazu hat dieser Stapel keinen `ScrollView`: Satzkarte plus Mismatch-Notiz plus Dreizeiler kann überlaufen. Aufgelöst zugunsten der Ruhe **am Lernort**, ohne die Erklärbarkeit zu verlieren: Der Grund steht im Kontextmenü der Kartenliste und in den Einstellungen. Vom unabhängigen Review aufgeworfen, nicht beiläufig entschieden |
| A52 | Die Modellanfrage der Erklärung ist eine **injizierbare Closure** in `CardExplanationModel`, nicht ein direkter Aufruf im `body` | Nachträglich eingeführt, weil das unabhängige Testaudit einen echten Mangel fand: Die beiden tragenden Zusagen der Phase — nichts wird geschrieben, kein Sessionzustand bewegt sich — waren mit „durch einen Test belegt" ausgezeichnet, und der Test rief drei **reine** Funktionen auf und verglich davor und danach. Das belegt, dass reine Funktionen rein sind; ein `context.insert` in der Erzeugen-Aktion wäre unbemerkt geblieben. Mit der Closure fährt der Test den echten Kontrollfluss: öffnen (keine Anfrage), einmal tippen (genau eine), aus der laufenden Anfrage erneut tippen (immer noch eine), Wurf (der vorige Text bleibt stehen), erneut (die Meldung ist weg) — und **danach** Kartenzahl, Inhalte, `ReviewLog` und Sessionzustand. **Kein Modell-Mock:** Die Closure trägt keine Aussage darüber, was eine Erklärung sagt; die Modellqualität ist am Gerät gemessen (§12) und wird nicht durch einen Fake nachgestellt. Präzedenz: `LearnSessionModel(generator:now:)` reicht Zufall und Uhr aus demselben Grund herein |
