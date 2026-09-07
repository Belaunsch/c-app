//
//  TranslationService.swift
//  CApp
//

import Foundation
import Translation

/// German → Simplified Chinese, using Apple's on-device Translation framework.
///
/// The service only answers "can we translate at all, and how" and builds the
/// session configuration. The translation itself runs on the session that
/// SwiftUI's `translationTask` hands over — that modifier is also what asks
/// the user for permission to download language models, so we neither build
/// our own download infrastructure nor a second code path for it.
@MainActor
enum TranslationService {

    static var sourceLanguage: Locale.Language { Locale.Language(identifier: "de") }
    static var targetLanguage: Locale.Language { Locale.Language(identifier: "zh-Hans") }

    enum Availability: Equatable {
        /// Models are on the device; translation works right away.
        case installed
        /// The pair is supported, but the models still have to be downloaded.
        case downloadable
        /// This device cannot translate German to Simplified Chinese.
        case unsupported
    }

    struct Support: Equatable {
        let availability: Availability
        /// `true` when only the traditional models cover the pair, so the
        /// session has to ask for them explicitly.
        let requiresLowLatencyStrategy: Bool
        /// `false` when the availability was inferred from the language
        /// catalogue because `status(from:to:)` gave nothing usable. The UI
        /// must then promise less — see `Availability.downloadable`.
        let isConfirmed: Bool

        init(
            availability: Availability,
            requiresLowLatencyStrategy: Bool = false,
            isConfirmed: Bool = true
        ) {
            self.availability = availability
            self.requiresLowLatencyStrategy = requiresLowLatencyStrategy
            self.isConfirmed = isConfirmed
        }

        static let unsupported = Support(availability: .unsupported)
    }

    /// Checks whether the pair can be translated, and with which models.
    ///
    /// The order matters. `LanguageAvailability()` uses the default strategy
    /// for the SDK the app was built with, and Apple documents that apps
    /// built against the iOS 26.4 SDK or later default to **checking for
    /// Apple Intelligence models**. We build with the 26.5 SDK, so on a
    /// device without Apple Intelligence the default check can report
    /// "unsupported" even though the traditional models would do the job.
    /// Hence the second check with `.lowLatency` — see decision A16.
    static func support() async -> Support {
        let preferred = await LanguageAvailability()
            .status(from: sourceLanguage, to: targetLanguage)

        if let availability = availability(for: preferred), availability != .unsupported {
            return Support(availability: availability, requiresLowLatencyStrategy: false)
        }

        if #available(iOS 26.4, *) {
            let traditional = await LanguageAvailability(preferredStrategy: .lowLatency)
                .status(from: sourceLanguage, to: targetLanguage)
            if let availability = availability(for: traditional), availability != .unsupported {
                return Support(availability: availability, requiresLowLatencyStrategy: true)
            }
        }

        // Last resort before giving up: ask the catalogue instead of the pair.
        //
        // Measured in phase 4 on the simulator: `status(from:to:)` answers
        // "unsupported" for *every* pair there, including German to English,
        // because no models are present at all. If the device answered the
        // same way for a merely-not-downloaded pair, treating that as "this
        // device cannot translate" would switch the feature off for good and
        // never offer the download. So when the framework lists both
        // languages, we let the user try: `translationTask` is what asks for
        // the download, and a genuine failure still lands in the error path.
        if await catalogueContainsBothLanguages() {
            // Inferred, not measured — flagged so the UI does not promise a
            // download dialog that may never appear.
            return Support(availability: .downloadable, isConfirmed: false)
        }

        return .unsupported
    }

    /// Whether the framework knows German and Simplified Chinese at all.
    ///
    /// `supportedLanguages` reports maximal identifiers such as `de-Latn-DE`
    /// and `zh-Hans-CN`, so the comparison goes over language code and script
    /// rather than the plain identifier.
    private static func catalogueContainsBothLanguages() async -> Bool {
        let supported = await LanguageAvailability().supportedLanguages
        let hasGerman = supported.contains { $0.languageCode?.identifier == "de" }
        let hasSimplifiedChinese = supported.contains {
            $0.languageCode?.identifier == "zh" && $0.script?.identifier == "Hans"
        }
        return hasGerman && hasSimplifiedChinese
    }

    /// The configuration for `translationTask`.
    ///
    /// Without an explicit strategy the framework picks one itself and,
    /// per Apple's documentation, "automatically selects an appropriate
    /// alternative based on device capabilities and language availability".
    /// That is what we want in the normal case — quality first, with the
    /// framework's own fallback. Only when the availability check showed that
    /// *only* the traditional models cover the pair do we ask for them.
    static func makeConfiguration(requiresLowLatencyStrategy: Bool) -> TranslationSession.Configuration {
        if requiresLowLatencyStrategy, #available(iOS 26.4, *) {
            return TranslationSession.Configuration(
                source: sourceLanguage,
                target: targetLanguage,
                preferredStrategy: .lowLatency
            )
        }
        return TranslationSession.Configuration(
            source: sourceLanguage,
            target: targetLanguage
        )
    }

    private static func availability(for status: LanguageAvailability.Status) -> Availability? {
        switch status {
        case .installed: .installed
        case .supported: .downloadable
        case .unsupported: .unsupported
        @unknown default: nil
        }
    }
}
