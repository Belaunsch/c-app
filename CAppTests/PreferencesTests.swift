//
//  PreferencesTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

/// The settings, and the three places a stored value reaches the app.
///
/// Every reader is tested against what can actually be in `UserDefaults`:
/// nothing, a stale value from a version that no longer exists, and a value
/// outside any range the UI can produce. The defaults database is editable
/// and survives app updates — "the picker can only write valid values" is
/// true of the picker, not of the store.
@MainActor
struct PreferencesTests {

    // MARK: - Speaking rate

    @Test("The persisted strings are pinned, so a rename cannot change them")
    func rawValuesArePinned() {
        // Same rule and same reason as `CardListArrangementTests`: these
        // strings live in `UserDefaults` and survive app updates. Renaming a
        // Swift case must stay a source-level decision — with implicit raw
        // values it would silently reset the speed on every installation, and
        // no round-trip test can see that, because writer and reader move
        // together.
        #expect(SpeechRate.slow.rawValue == "slow")
        #expect(SpeechRate.normal.rawValue == "normal")
        #expect(SpeechRate.fast.rawValue == "fast")
        #expect(SpeechRate.allCases.count == 3, "a fourth case needs its string pinned here too")

        // The keys are persisted just as literally.
        #expect(Preferences.speechRateKey == "settings.speechRate")
        #expect(Preferences.voiceIdentifierKey == "settings.voiceIdentifier")
        #expect(Preferences.batchSizeKey == "settings.batchSize")
        #expect(Preferences.automaticVoice == "")
    }

    @Test("The speeds are named by what they sound like")
    func rateTitles() {
        // User-facing German, tested like every other visible name in the
        // project (`CardDisplayTests`, `CardListArrangementTests`).
        #expect(SpeechRate.slow.title == "Langsam")
        #expect(SpeechRate.normal.title == "Normal")
        #expect(SpeechRate.fast.title == "Schnell")
        let titles = SpeechRate.allCases.map(\.title)
        #expect(Set(titles).count == titles.count, "two speeds under one name is a picker with a lie in it")
    }

    @Test("Every rate survives the round trip, and the values are the measured ones")
    func rateRoundTrip() {
        for rate in SpeechRate.allCases {
            #expect(Preferences.speechRate(from: rate.rawValue) == rate)
        }
        // Pinned literally: these three came from a device comparison in
        // phase 7, not from taste. Changing one silently changes what the
        // user hears under a label they already know.
        #expect(SpeechRate.slow.value == 0.40)
        #expect(SpeechRate.normal.value == 0.45)
        #expect(SpeechRate.fast.value == 0.50)
        #expect(SpeechRate.default == .normal, "what phase 7 shipped")
    }

    @Test("An unknown or missing rate falls back to what phase 7 shipped")
    func rateFallback() {
        #expect(Preferences.speechRate(from: nil) == .normal)
        #expect(Preferences.speechRate(from: "") == .normal)
        #expect(Preferences.speechRate(from: "veryFast") == .normal)
        #expect(Preferences.speechRate(from: "NORMAL") == .normal, "and it is case sensitive")
    }

    // MARK: - Voice

    @Test("An empty voice preference means automatic")
    func voiceAutomatic() {
        #expect(Preferences.voiceIdentifier(from: nil) == nil)
        #expect(Preferences.voiceIdentifier(from: Preferences.automaticVoice) == nil)
        #expect(Preferences.voiceIdentifier(from: "   ") == nil, "whitespace is not a choice")
        #expect(Preferences.voiceIdentifier(from: "com.apple.x") == "com.apple.x")
    }

    // MARK: - Batch size

    @Test("A missing batch size keeps the engine's default")
    func batchSizeDefault() {
        #expect(Preferences.batchSize(from: nil) == LearningParameters.batchSize)
        // `UserDefaults.integer(forKey:)` returns 0 for a missing key, so 0
        // has to mean "nothing stored" rather than "zero cards".
        #expect(Preferences.batchSize(from: 0) == LearningParameters.batchSize)
    }

    @Test("A stored batch size is clamped to the documented range")
    func batchSizeClamped() {
        // The range is 5 to 10 (`learning-engine.md` §8). Outside it the
        // engine would still do as it is told: 1 would make every batch a
        // single card, 500 would turn a session into one endless run. Both
        // are reachable by editing the defaults database.
        #expect(Preferences.batchSize(from: 5) == 5)
        #expect(Preferences.batchSize(from: 10) == 10)
        #expect(Preferences.batchSize(from: 1) == 5)
        #expect(Preferences.batchSize(from: -3) == 5)
        #expect(Preferences.batchSize(from: 500) == 10)
        #expect(Preferences.batchSizeRange == 5...10)
    }

    // MARK: - The batch size reaches both places it has to

    @Test("A larger batch really draws more cards")
    func batchSizeChangesTheBatch() {
        let pool = (0..<20).map { _ in CardSnapshot(id: UUID(), status: .weak) }
        var generator = AnyRandomNumberGenerator(SeededGenerator(seed: 11))

        let small = BatchSelector.selectBatch(from: pool, batchSize: 5, using: &generator)
        let large = BatchSelector.selectBatch(from: pool, batchSize: 10, using: &generator)

        #expect(small.count == 5)
        #expect(large.count == 10)
        #expect(Set(small.map(\.id)).count == 5, "different cards, not repeats")
    }

    @Test("The recency threshold moves with the batch size")
    func recencyThresholdFollows() {
        // The trap `BatchSelector` warned about since phase 5: passing a size
        // into the selection alone would leave this threshold at two times
        // seven, and every pool between the two numbers would silently lose
        // the damping §3.2 asks for.
        #expect(LearningParameters.minimumPoolSizeForRecency(batchSize: 5) == 10)
        #expect(LearningParameters.minimumPoolSizeForRecency(batchSize: 7) == 14)
        #expect(LearningParameters.minimumPoolSizeForRecency(batchSize: 10) == 20)

        // A pool of twelve is above the threshold for a batch of five and
        // below it for a batch of seven. The damping has to differ.
        #expect(CardWeighting.isRecencyActive(poolSize: 12, batchSize: 5))
        #expect(CardWeighting.isRecencyActive(poolSize: 12, batchSize: 7) == false)

        let damped = CardWeighting.effectiveWeight(
            for: .weak, wasInPreviousBatch: true, poolSize: 12, batchSize: 5
        )
        let undamped = CardWeighting.effectiveWeight(
            for: .weak, wasInPreviousBatch: true, poolSize: 12, batchSize: 7
        )
        #expect(damped < undamped, "the same pool, a different batch size, a different weight")
    }

    @Test("Everything without an explicit size behaves exactly as before")
    func defaultsAreUnchanged() {
        // Phase 5 to 9 called all of these without a batch size. The defaults
        // are what keeps those call sites — and their tests — meaning what
        // they meant.
        #expect(LearningParameters.batchSize == 7)
        #expect(LearningParameters.minimumPoolSizeForRecency() == 14)
        #expect(CardWeighting.isRecencyActive(poolSize: 14))
        #expect(CardWeighting.isRecencyActive(poolSize: 13) == false)
    }

    // MARK: - Voice selection with an explicit choice

    private func candidate(_ identifier: String, _ quality: VoiceQuality = .default) -> VoiceCandidate {
        VoiceCandidate(identifier: identifier, language: "zh-CN", quality: quality, name: identifier)
    }

    @Test("A chosen voice wins over the automatic ranking")
    func chosenVoiceWins() {
        let installed = [
            candidate("com.apple.voice.premium.zh-CN.A", .premium),
            candidate("com.apple.voice.compact.zh-CN.B"),
        ]
        // Automatic would take the premium one.
        #expect(MandarinVoiceSelection.best(from: installed)?.identifier
            == "com.apple.voice.premium.zh-CN.A")

        // The user asked for the other one, and gets it.
        #expect(MandarinVoiceSelection.best(
            from: installed,
            chosenIdentifier: "com.apple.voice.compact.zh-CN.B"
        )?.identifier == "com.apple.voice.compact.zh-CN.B")
    }

    @Test("A chosen voice that is gone falls back instead of falling silent")
    func chosenVoiceDisappeared() {
        let installed = [candidate("com.apple.voice.premium.zh-CN.A", .premium)]

        // The identifier names a voice deleted in the iOS settings. Honouring
        // it would leave `voice == nil` and the speaker would vanish with no
        // explanation — the worst of the possible failures, because it looks
        // like the app broke.
        let resolved = MandarinVoiceSelection.best(
            from: installed,
            chosenIdentifier: "com.apple.voice.premium.zh-CN.GONE"
        )
        #expect(resolved?.identifier == "com.apple.voice.premium.zh-CN.A")
    }

    @Test("A chosen voice from another language is refused")
    func chosenVoiceMustStillBeMandarin() {
        let installed = [
            candidate("com.apple.voice.premium.zh-CN.A", .premium),
            VoiceCandidate(identifier: "com.apple.voice.de-DE.Anna", language: "de-DE",
                           quality: .premium, name: "Anna"),
        ]
        // A stored identifier from another language — reachable by editing
        // the defaults, or if a future version ever offered other languages.
        // Reading a Chinese card aloud in German is not a fallback.
        let resolved = MandarinVoiceSelection.best(
            from: installed,
            chosenIdentifier: "com.apple.voice.de-DE.Anna"
        )
        #expect(resolved?.identifier == "com.apple.voice.premium.zh-CN.A")
    }

    @Test("The settings list offers only Mainland Mandarin, best first")
    func voiceListIsOrdered() {
        let installed = [
            candidate("com.apple.voice.compact.zh-CN.B"),
            VoiceCandidate(identifier: "tw", language: "zh-TW", quality: .premium, name: "Meijia"),
            candidate("com.apple.voice.premium.zh-CN.A", .premium),
            VoiceCandidate(identifier: "de", language: "de-DE", quality: .premium, name: "Anna"),
        ]
        let listed = MandarinVoiceSelection.mandarinVoices(from: installed)

        #expect(listed.map(\.identifier) == [
            "com.apple.voice.premium.zh-CN.A",
            "com.apple.voice.compact.zh-CN.B",
        ], "Taiwan and German are not choices here")
    }

    // MARK: - The stored values actually reach the services

    /// A suite of its own, emptied before use and removed afterwards.
    ///
    /// The precise claim, because the wording matters: what is emptied is
    /// **this suite**, not the app's whole defaults database. Whether a
    /// suite-named `UserDefaults` also reads through to the app domain is not
    /// settled here and does not need to be — every test below either writes
    /// the value it then reads, or checks a fallback that the pure functions
    /// in `Preferences` already pin independently of any store.
    private func withScratchDefaults(_ name: String, _ body: (UserDefaults) throws -> Void) throws {
        let suite = "PreferencesTests.\(name)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    @Test("With nothing stored under these keys, the shipped behaviour applies")
    func readersWithNothingStored() throws {
        // The first launch after the update, and the reason `batchSize`
        // treats 0 as "nothing stored": `integer(forKey:)` cannot tell the
        // two apart.
        //
        // This is the one test here that reads keys it never writes. If a
        // suite turned out to inherit values from the app's own domain, it
        // would go red on a machine where the app had been used — never
        // silently green. The rules themselves are pinned independently of
        // any store by `rateFallback`, `voiceAutomatic` and `batchSizeDefault`.
        try withScratchDefaults("empty") { defaults in
            #expect(Preferences.currentSpeechRate(defaults) == .normal)
            #expect(Preferences.currentVoiceIdentifier(defaults) == nil)
            #expect(Preferences.currentBatchSize(defaults) == LearningParameters.batchSize)
        }
    }

    @Test("What the settings screen writes is what the services read")
    func readersSeeWhatWasWritten() throws {
        // The seam this covers is the key strings and the types: the picker
        // writes a `String` under `speechRateKey`, the stepper an `Int` under
        // `batchSizeKey`. A typo in either constant, or reading the wrong
        // type back, would leave every setting silently ineffective — the
        // failure the pure functions above cannot see, because they never
        // touch the store.
        try withScratchDefaults("written") { defaults in
            defaults.set(SpeechRate.fast.rawValue, forKey: Preferences.speechRateKey)
            defaults.set("com.apple.voice.premium.zh-CN.Lili", forKey: Preferences.voiceIdentifierKey)
            defaults.set(10, forKey: Preferences.batchSizeKey)

            #expect(Preferences.currentSpeechRate(defaults) == .fast)
            #expect(Preferences.currentVoiceIdentifier(defaults) == "com.apple.voice.premium.zh-CN.Lili")
            #expect(Preferences.currentBatchSize(defaults) == 10)
        }
    }

    @Test("A nonsense value in the store is still clamped on the way out")
    func readersClampStoredNonsense() throws {
        // The defaults database is editable and survives app updates, so the
        // guard has to sit at the reader, not only at the control.
        try withScratchDefaults("nonsense") { defaults in
            defaults.set("subsonic", forKey: Preferences.speechRateKey)
            defaults.set("   ", forKey: Preferences.voiceIdentifierKey)
            defaults.set(9_999, forKey: Preferences.batchSizeKey)

            #expect(Preferences.currentSpeechRate(defaults) == .normal)
            #expect(Preferences.currentVoiceIdentifier(defaults) == nil)
            #expect(Preferences.currentBatchSize(defaults) == 10)
        }
    }

    @Test("The keys are namespaced, so nothing collides with a future one")
    func keysAreDistinctAndNamespaced() {
        let keys = [
            Preferences.speechRateKey,
            Preferences.voiceIdentifierKey,
            Preferences.batchSizeKey,
        ]
        #expect(Set(keys).count == keys.count)
        #expect(keys.allSatisfy { $0.hasPrefix("settings.") })
    }

    // MARK: - The settings screen's own rule about a vanished voice

    @Test("A stored voice that is still installed stays chosen")
    func voiceChoiceSurvives() {
        let installed = [candidate("com.apple.voice.premium.zh-CN.A", .premium),
                         candidate("com.apple.voice.compact.zh-CN.B")]
        #expect(SettingsView.voiceChoice("com.apple.voice.compact.zh-CN.B", amongst: installed)
            == "com.apple.voice.compact.zh-CN.B")
    }

    @Test("A stored voice that is gone falls back to automatic")
    func voiceChoiceFallsBack() {
        // The service already switches to the automatic rule, so the app
        // speaks correctly either way — but the picker would find no matching
        // tag and show no selection at all, which reads as if something broke.
        let installed = [candidate("com.apple.voice.premium.zh-CN.A", .premium)]
        #expect(SettingsView.voiceChoice("com.apple.voice.premium.zh-CN.GONE", amongst: installed)
            == Preferences.automaticVoice)
    }

    @Test("A stored identifier with stray whitespace comes back usable")
    func voiceChoiceNormalises() {
        // The check trims, so the value passes — and the raw value used to be
        // written back untrimmed, so the picker, which matches tags exactly,
        // showed no selection at all. Exactly the failure this function is
        // there to prevent, produced by the function itself.
        let installed = [candidate("com.apple.voice.premium.zh-CN.A", .premium)]
        #expect(SettingsView.voiceChoice("  com.apple.voice.premium.zh-CN.A  ", amongst: installed)
            == "com.apple.voice.premium.zh-CN.A")
    }

    @Test("Automatic stays automatic, and an empty list discards nothing that was valid")
    func voiceChoiceEdges() {
        #expect(SettingsView.voiceChoice(Preferences.automaticVoice, amongst: [])
            == Preferences.automaticVoice)
        #expect(SettingsView.voiceChoice("   ", amongst: []) == Preferences.automaticVoice)
        // With no Mandarin voice installed there is nothing a stored
        // identifier could name, so dropping it is the truthful outcome — and
        // the speaker is hidden in that case anyway.
        #expect(SettingsView.voiceChoice("com.apple.voice.premium.zh-CN.A", amongst: [])
            == Preferences.automaticVoice)
    }

    // MARK: - Status counts

    @Test("The status counts come from the cards, and add up")
    func statusCounts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        for status in [LearningStatus.new, .new, .weak, .good, .good, .good] {
            context.insert(Card(type: .word, german: "x", hanzi: "苹果", status: status))
        }
        try context.save()

        let cards = try context.fetch(FetchDescriptor<Card>())
        #expect(SettingsView.count(of: .new, in: cards) == 2)
        #expect(SettingsView.count(of: .weak, in: cards) == 1)
        #expect(SettingsView.count(of: .medium, in: cards) == 0)
        #expect(SettingsView.count(of: .good, in: cards) == 3)
        #expect(SettingsView.count(of: .secure, in: cards) == 0)

        let total = LearningStatus.allCases.reduce(0) { $0 + SettingsView.count(of: $1, in: cards) }
        #expect(total == cards.count, "every card is counted exactly once")
    }
}
