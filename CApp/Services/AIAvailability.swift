//
//  AIAvailability.swift
//  CApp
//

import Foundation
import FoundationModels

/// Whether the on-device model can be offered, and what to say when it cannot.
///
/// Five states, because Apple gives three reasons for unavailability and the
/// language check adds a fourth way to fail. They are collapsed into **two UI
/// behaviours**, and which one a state gets follows a single question: *can the
/// user do anything about it?*
///
/// - Not fixable — `deviceNotEligible`, an unsupported language — the entry is
///   **hidden**. A permanently dead button is annoyance without benefit; the
///   same choice phase 7 made for the speaker when no `zh-CN` voice exists.
/// - Fixable or temporary — Apple Intelligence switched off, model still
///   downloading — the entry is **shown, disabled, with a reason**. Hiding it
///   would conceal a feature the user could switch on.
///
/// ## Never cached
///
/// The system changes this behind the app's back: Apple Intelligence can be
/// switched off while the app runs, and the model downloads „based on factors
/// like network status, battery level, and system load". Resolve on every
/// opening. Same reasoning as `AssetInventory.status(forModules:)` since
/// phase 9, and `SystemLanguageModel` is `Observable` so a view can follow it.
///
/// ## Why the language check only runs when the model is available
///
/// `supportsLocale(_:)` is synchronous, free and never throws — but when the
/// model is not installed it has nothing to answer from. Trusting it then would
/// turn a *temporary* `modelNotReady` into a *permanent* `languageUnsupported`,
/// which hides the entry for good. So the order is: Apple's own verdict first,
/// the languages only once the model says it is there.
nonisolated enum AIAvailability: Equatable, Sendable {
    /// Usable. Measured the case on the test device (iPhone 16 Pro, iOS 27.0).
    case available
    /// The device does not support Apple Intelligence. Not fixable.
    case deviceNotEligible
    /// German or Mandarin is missing from the model's languages. Not fixable.
    case languageUnsupported
    /// Apple Intelligence is switched off in the iOS settings. Fixable.
    case appleIntelligenceOff
    /// The model is still being prepared by the system. Temporary.
    case modelNotReady
    /// Apple named a reason this version does not know. Defensive only.
    ///
    /// Not a sixth documented state — the framework documents three reasons and
    /// the language check adds a fourth way to fail. This exists because mapping
    /// an unknown reason onto ``modelNotReady`` would make the app **say** „Das
    /// Modell wird vom System vorbereitet." about something it knows nothing
    /// about. Hard rule 9: document uncertainty instead of guessing. It behaves
    /// like the recoverable states — shown and disabled — because unknown is not
    /// the same as impossible, and hiding is the irreversible choice.
    case unavailableForUnknownReason

    // MARK: The two locales, by name

    /// Measured, not assumed: on the test device `Locale.current` is `en_DE`.
    /// A check through `Locale.current` would have returned `true` there and
    /// still asked the wrong question. Both target locales are named.
    static let germanLocale = Locale(identifier: "de_DE")
    static let chineseLocale = Locale(identifier: "zh_CN")

    // MARK: Resolving

    /// The pure rule. Everything testable about this type is testable here.
    static func resolve(
        _ availability: SystemLanguageModel.Availability,
        supportsGerman: Bool,
        supportsChinese: Bool
    ) -> AIAvailability {
        switch availability {
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceOff
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .available:
            // Only here is the language answer worth anything — see the note.
            return supportsGerman && supportsChinese ? .available : .languageUnsupported
        @unknown default:
            return .unavailableForUnknownReason
        }
    }

    /// The impure seam: asks the system, then applies the rule above.
    ///
    /// Deliberately a function and not a stored value — see „Never cached".
    static func current(_ model: SystemLanguageModel = .default) -> AIAvailability {
        resolve(
            model.availability,
            supportsGerman: model.supportsLocale(germanLocale),
            supportsChinese: model.supportsLocale(chineseLocale)
        )
    }

    // MARK: What the interface does with it

    /// Whether the entry appears at all.
    var showsEntry: Bool {
        switch self {
        case .available, .appleIntelligenceOff, .modelNotReady, .unavailableForUnknownReason: true
        case .deviceNotEligible, .languageUnsupported: false
        }
    }

    /// Whether the entry can be tapped.
    var isEnabled: Bool { self == .available }

    /// Why the entry is there but disabled. `nil` when there is nothing to say.
    var disabledReason: String? {
        switch self {
        case .appleIntelligenceOff:
            "Apple Intelligence ist ausgeschaltet. In den iOS-Einstellungen einschalten, dann steht die Erklärung zur Verfügung."
        case .modelNotReady:
            "Das Modell wird vom System noch vorbereitet. Später erneut versuchen."
        case .unavailableForUnknownReason:
            "Steht derzeit nicht zur Verfügung."
        case .available, .deviceNotEligible, .languageUnsupported:
            nil
        }
    }

    /// The line in the settings, in words, with the reason.
    ///
    /// It exists so that a hidden entry stays explainable: without it, a missing
    /// function is a riddle. There is no download button and no progress —
    /// the framework offers neither (`docs/apple-frameworks.md` §11.9).
    var settingsText: String {
        switch self {
        case .available:
            "Verfügbar. Erklärungen werden auf dem Gerät erzeugt."
        case .deviceNotEligible:
            "Dieses Gerät unterstützt Apple Intelligence nicht. Erklärungen stehen deshalb nicht zur Verfügung."
        case .languageUnsupported:
            "Das Modell auf diesem Gerät führt Deutsch oder Chinesisch nicht. Erklärungen stehen deshalb nicht zur Verfügung."
        case .appleIntelligenceOff:
            "Apple Intelligence ist ausgeschaltet. In den iOS-Einstellungen einschalten."
        case .modelNotReady:
            "Das Modell wird vom System vorbereitet."
        case .unavailableForUnknownReason:
            "Steht derzeit nicht zur Verfügung."
        }
    }
}
