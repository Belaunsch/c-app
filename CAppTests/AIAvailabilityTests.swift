//
//  AIAvailabilityTests.swift
//  CAppTests
//

import Testing
import Foundation
import FoundationModels
@testable import CApp

@Suite("AI availability")
struct AIAvailabilityTests {

    // MARK: The five states

    @Test("Available with both languages is the only usable state")
    func availableWithBothLanguages() {
        let state = AIAvailability.resolve(.available, supportsGerman: true, supportsChinese: true)
        #expect(state == .available)
        #expect(state.showsEntry)
        #expect(state.isEnabled)
        #expect(state.disabledReason == nil)
    }

    @Test(
        "A missing target language hides the entry",
        arguments: [(false, true), (true, false), (false, false)]
    )
    func missingLanguageHidesTheEntry(languages: (german: Bool, chinese: Bool)) {
        let state = AIAvailability.resolve(
            .available,
            supportsGerman: languages.german,
            supportsChinese: languages.chinese
        )
        #expect(state == .languageUnsupported)
        // Not fixable by the user, so not shown.
        #expect(state.showsEntry == false)
        #expect(state.isEnabled == false)
    }

    @Test("An ineligible device hides the entry")
    func ineligibleDeviceHidesTheEntry() {
        let state = AIAvailability.resolve(
            .unavailable(.deviceNotEligible),
            supportsGerman: true,
            supportsChinese: true
        )
        #expect(state == .deviceNotEligible)
        #expect(state.showsEntry == false)
        #expect(state.isEnabled == false)
    }

    @Test("Apple Intelligence switched off shows a disabled entry with a reason")
    func appleIntelligenceOffExplains() {
        let state = AIAvailability.resolve(
            .unavailable(.appleIntelligenceNotEnabled),
            supportsGerman: true,
            supportsChinese: true
        )
        #expect(state == .appleIntelligenceOff)
        // Fixable, so it stays visible — hiding would conceal a switch the
        // user can flip.
        #expect(state.showsEntry)
        #expect(state.isEnabled == false)
        #expect(state.disabledReason?.isEmpty == false)
    }

    @Test("A model that is not ready shows a disabled entry with a reason")
    func modelNotReadyExplains() {
        let state = AIAvailability.resolve(
            .unavailable(.modelNotReady),
            supportsGerman: true,
            supportsChinese: true
        )
        #expect(state == .modelNotReady)
        #expect(state.showsEntry)
        #expect(state.isEnabled == false)
        #expect(state.disabledReason?.isEmpty == false)
    }

    // MARK: The precedence that keeps a temporary state temporary

    @Test("An unavailable model is never reported as an unsupported language")
    func unavailabilityBeatsTheLanguageAnswer() {
        // `supportsLocale` has nothing to answer from while the model is
        // missing. Believing it there would turn a download that finishes in a
        // minute into a permanently hidden feature.
        for reason in [
            SystemLanguageModel.Availability.UnavailableReason.modelNotReady,
            .appleIntelligenceNotEnabled
        ] {
            let state = AIAvailability.resolve(
                .unavailable(reason),
                supportsGerman: false,
                supportsChinese: false
            )
            #expect(state != .languageUnsupported)
            #expect(state.showsEntry, "a recoverable state must stay visible")
        }
    }

    @Test("An unknown future reason does not claim to be a download")
    func unknownReasonSaysNothingItCannotKnow() {
        // Hard rule 9 in one assertion: the app must not describe a reason it
        // does not know. Mapping this onto `modelNotReady` would have it say
        // „Das Modell wird vom System vorbereitet." about anything Apple adds.
        let state = AIAvailability.unavailableForUnknownReason
        #expect(state.showsEntry, "unknown is not the same as impossible")
        #expect(state.isEnabled == false)
        #expect(state.disabledReason?.contains("vorbereitet") == false)
        #expect(state.settingsText.contains("vorbereitet") == false)
        #expect(state != .modelNotReady)
    }

    @Test("Every state says something in the settings")
    func everyStateHasSettingsText() {
        let all: [AIAvailability] = [
            .available, .deviceNotEligible, .languageUnsupported,
            .appleIntelligenceOff, .modelNotReady, .unavailableForUnknownReason
        ]
        for state in all {
            #expect(state.settingsText.isEmpty == false)
        }
        // And the five documented ones differ — one shared sentence would tell
        // the user nothing. The defensive fallback shares its wording with
        // nothing either, but it is allowed to be vague, because it *is* vague.
        #expect(Set(all.map(\.settingsText)).count == all.count)
    }

    // MARK: The locales are named, not taken from the environment

    @Test("The checked locales are German and Mainland Chinese, by name")
    func localesAreNamed() {
        #expect(AIAvailability.germanLocale.identifier == "de_DE")
        #expect(AIAvailability.chineseLocale.identifier == "zh_CN")
        // Measured on the device: `Locale.current` was `en_DE` there. The two
        // lines above already carry the promise; a comparison against
        // `Locale.current` cannot fail and would only look like a test.
    }

    // MARK: Where the entry may appear

    @Test("The card list offers the entry exactly when the state is shown")
    func listEntryFollowsVisibility() {
        // Recoverable states appear greyed out with their reason — there is room
        // for it in a menu.
        #expect(CardExplanationEntry.isOfferedInList(.available))
        #expect(CardExplanationEntry.isOfferedInList(.appleIntelligenceOff))
        #expect(CardExplanationEntry.isOfferedInList(.modelNotReady))
        #expect(CardExplanationEntry.isOfferedInList(.unavailableForUnknownReason))
        #expect(CardExplanationEntry.isOfferedInList(.deviceNotEligible) == false)
        #expect(CardExplanationEntry.isOfferedInList(.languageUnsupported) == false)
    }

    @Test("A covered learning card never offers an explanation")
    func coveredCardHasNoEntry() {
        // Whatever the model says — a covered card's explanation would be the
        // answer currently being asked for.
        let all: [AIAvailability] = [
            .available, .deviceNotEligible, .languageUnsupported,
            .appleIntelligenceOff, .modelNotReady, .unavailableForUnknownReason
        ]
        for state in all {
            #expect(CardExplanationEntry.isOfferedOnLearningCard(state, isRevealed: false) == false)
        }
    }

    @Test("The learning card offers it only when it is actually usable")
    func revealedCardNeedsAUsableModel() {
        // A51, and the stricter rule of the two. The learning screen gets no
        // greyed-out button and no explanatory text: it would stand under every
        // revealed card for the whole session, and that stack has no
        // `ScrollView`. The reason stays reachable in the list and the settings.
        //
        // This lived at the call site until the second audit pointed out that a
        // rule in a `body` is a rule no test can reach — removing it there would
        // have broken a user-visible promise with every test green.
        #expect(CardExplanationEntry.isOfferedOnLearningCard(.available, isRevealed: true))
        for unusable: AIAvailability in [
            .appleIntelligenceOff, .modelNotReady, .unavailableForUnknownReason,
            .deviceNotEligible, .languageUnsupported
        ] {
            #expect(
                CardExplanationEntry.isOfferedOnLearningCard(unusable, isRevealed: true) == false,
                "no dead button and no standing explanation on the learning card"
            )
        }
    }

    @Test("The two entry points really differ")
    func theTwoRulesAreNotTheSame() {
        // If they ever collapse into one, one of the two documented goals is
        // gone — either the reason becomes unreachable or the learning screen
        // grows permanent prose.
        #expect(CardExplanationEntry.isOfferedInList(.appleIntelligenceOff))
        #expect(CardExplanationEntry.isOfferedOnLearningCard(.appleIntelligenceOff, isRevealed: true) == false)
    }
}
