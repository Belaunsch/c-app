//
//  Preferences.swift
//  CApp
//

import Foundation

/// How fast the app speaks Mandarin.
///
/// Three presets, not a slider. The phase-7 device spike measured exactly
/// these three rates against the same sentence and the user judged them by
/// ear: `0.50` is understandable but too quick for learning, `0.45` is the
/// sweet spot, `0.40` is a usable slower option. A free-floating rate would
/// offer a hundred values of which three were ever tested.
nonisolated enum SpeechRate: String, CaseIterable, Identifiable, Sendable {
    // The raw values are **written out** rather than left to the compiler,
    // the same rule `CardSortOrder` follows and for the same reason: this
    // value is persisted in `UserDefaults` and survives app updates. With
    // implicit raw values, renaming a case would silently reset the speed
    // every existing installation had chosen — a rename is a source-level
    // decision, the stored string is a promise to the user. The strings below
    // are exactly what the implicit values were, so nothing has to migrate.
    case slow = "slow"
    case normal = "normal"
    case fast = "fast"

    var id: String { rawValue }

    /// The measured values. `AVSpeechUtterance.rate` takes a `Float`.
    var value: Float {
        switch self {
        case .slow: 0.40
        case .normal: 0.45
        case .fast: 0.50
        }
    }

    /// What phase 7 shipped, and therefore what an existing installation
    /// keeps until someone changes it.
    static let `default` = SpeechRate.normal
}

/// The app's local settings.
///
/// ## Why `UserDefaults` and not the store
///
/// None of this is card data. A speaking rate, a chosen voice and a batch
/// size describe how the app behaves for this person on this device — they
/// have no place in a SwiftData schema, they never sync, and putting them
/// there would mean a migration for every preference. `@AppStorage` reads the
/// same keys in the settings screen, so a change is live without a restart
/// and without a notification of our own.
///
/// ## Why every read goes through a function
///
/// What is in `UserDefaults` was written by some past or future version of
/// this app, or by nothing at all. A raw `Int` could be 0 or 99, a raw
/// `String` could name a rate that no longer exists. Each reader below turns
/// whatever it finds into a usable value, and each is a pure function so the
/// fallback can be tested rather than hoped for — the same shape
/// `CardSortOrder.restored(from:)` has had since A33.
nonisolated enum Preferences {

    // MARK: - Keys
    //
    // Written out and never derived. They live on the user's device and
    // outlive any refactoring in here; a renamed key silently discards a
    // setting and looks like the app forgot.

    static let speechRateKey = "settings.speechRate"
    static let voiceIdentifierKey = "settings.voiceIdentifier"
    static let batchSizeKey = "settings.batchSize"

    /// The value the voice preference carries when the app should choose.
    ///
    /// An empty string rather than a missing key, because `@AppStorage`
    /// binds a `String` and needs something to mean "automatic". It cannot
    /// collide with a real identifier: those are reverse-DNS names.
    static let automaticVoice = ""

    // MARK: - Speaking rate

    static func speechRate(from raw: String?) -> SpeechRate {
        guard let raw, let rate = SpeechRate(rawValue: raw) else { return .default }
        return rate
    }

    // MARK: - Voice

    /// The identifier the user picked, or `nil` for automatic selection.
    ///
    /// Trimmed, because an empty-after-trimming value means the same as no
    /// value. The identifier is stored, never the display name: names are
    /// localised and change between iOS versions, identifiers do not.
    static func voiceIdentifier(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Batch size

    /// Different cards per mini-batch, clamped to the documented range.
    ///
    /// `docs/learning-engine.md` §8 foresees 5 to 10 and this is where that
    /// range is enforced — not in `Learning/`, which takes a number and
    /// trusts it. A stored 0 would produce empty batches and a stored 500
    /// would turn a session into a single endless run; both are reachable by
    /// editing the defaults database, and neither may reach the engine.
    ///
    /// A missing value keeps `LearningParameters.batchSize`, so an
    /// installation from before this setting existed behaves exactly as it
    /// did.
    static let batchSizeRange = 5...10

    static func batchSize(from raw: Int?) -> Int {
        guard let raw, raw != 0 else { return LearningParameters.batchSize }
        return min(max(raw, batchSizeRange.lowerBound), batchSizeRange.upperBound)
    }

    // MARK: - Live reads for the services
    //
    // The settings screen binds `@AppStorage` to the same keys; these are for
    // the places that are not views.

    static func currentSpeechRate(_ defaults: UserDefaults = .standard) -> SpeechRate {
        speechRate(from: defaults.string(forKey: speechRateKey))
    }

    static func currentVoiceIdentifier(_ defaults: UserDefaults = .standard) -> String? {
        voiceIdentifier(from: defaults.string(forKey: voiceIdentifierKey))
    }

    static func currentBatchSize(_ defaults: UserDefaults = .standard) -> Int {
        // `integer(forKey:)` returns 0 for a missing key, which `batchSize`
        // reads as "nothing stored".
        batchSize(from: defaults.integer(forKey: batchSizeKey))
    }
}
