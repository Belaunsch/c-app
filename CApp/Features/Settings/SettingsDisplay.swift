//
//  SettingsDisplay.swift
//  CApp
//

import Foundation

// User-facing names for the settings. Here rather than on `Preferences`,
// which is a pure type in `Support/` — the same split `CardDisplay` and
// `LearnDisplay` make for the models and the learning layer.

extension SpeechRate {
    /// Named by what the learner hears, not by the number.
    ///
    /// `0.45` means nothing to anybody; „Normal" does. The values are in the
    /// type and in `apple-frameworks.md` Q5, where the measurement that
    /// produced them is recorded.
    var title: String {
        switch self {
        case .slow: "Langsam"
        case .normal: "Normal"
        case .fast: "Schnell"
        }
    }
}
