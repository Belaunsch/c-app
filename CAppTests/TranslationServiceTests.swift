//
//  TranslationServiceTests.swift
//  CAppTests
//

import Foundation
import Testing
import Translation
@testable import CApp

/// `support()` needs the system's translation models, which a test host does
/// not have — the simulator reports every pair as unsupported. What is
/// testable is the language pair and the configuration, and those are worth
/// pinning: a wrong identifier would silently disable the whole feature.
@MainActor
struct TranslationServiceTests {

    @Test("The pair is German to Simplified Chinese")
    func languagePairIsGermanToSimplifiedChinese() {
        #expect(TranslationService.sourceLanguage.languageCode?.identifier == "de")
        #expect(TranslationService.targetLanguage.languageCode?.identifier == "zh")
        #expect(TranslationService.targetLanguage.script?.identifier == "Hans")
    }

    @Test("The configuration carries that pair")
    func configurationCarriesThePair() {
        let configuration = TranslationService.makeConfiguration(requiresLowLatencyStrategy: false)
        #expect(configuration.source?.languageCode?.identifier == "de")
        #expect(configuration.target?.languageCode?.identifier == "zh")
        #expect(configuration.target?.script?.identifier == "Hans")
    }

    @Test("The low-latency configuration carries the same pair")
    func lowLatencyConfigurationCarriesThePair() {
        let configuration = TranslationService.makeConfiguration(requiresLowLatencyStrategy: true)
        #expect(configuration.source?.languageCode?.identifier == "de")
        #expect(configuration.target?.script?.identifier == "Hans")
    }

    @Test("Support counts as confirmed unless it was inferred")
    func supportIsConfirmedByDefault() {
        #expect(TranslationService.Support(availability: .installed).isConfirmed)
        #expect(TranslationService.Support.unsupported.isConfirmed)
        #expect(
            TranslationService.Support(availability: .downloadable, isConfirmed: false).isConfirmed == false
        )
    }
}
