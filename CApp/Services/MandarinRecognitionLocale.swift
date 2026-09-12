//
//  MandarinRecognitionLocale.swift
//  CApp
//

import Foundation

/// Deciding whether a locale the system handed back is the Mandarin this app
/// actually teaches.
///
/// ## Why this is a rule and not a string comparison
///
/// Apple's `supportedLocale(equivalentTo:)` is the documented way to turn a
/// request into one of the transcriber's own locales — but its contract has a
/// gap that matters here. The discussion says it returns a near-equivalent
/// "that shares the same `Locale.LanguageCode` value but has a different
/// `Locale.Region` value". **`Locale.Script` is not mentioned.** `zh-CN` and
/// `zh-TW` share the language code `zh`, so by the documented rule a request
/// for Mainland Mandarin may come back as Taiwan — Traditional characters,
/// against a card deck written in Simplified.
///
/// The phase-9 device spike measured that this does **not** happen on the
/// target device: all four spellings, including a bare `zh-Hans`, resolved to
/// `zh_CN` with `script=Hans`. That is a measurement, not a promise, and the
/// documented rule still says what it says. So the answer is validated rather
/// than trusted.
///
/// Nor is a string comparison an option. The same spike showed
/// `Locale.identifier` returning `zh_CN` with an underscore while
/// `identifier(.bcp47)` returns `zh-CN` with a hyphen — a comparison would
/// have silently depended on which property someone reached for.
nonisolated enum MandarinRecognitionLocale {

    /// What the app asks for.
    ///
    /// The fullest form available: language, script and region. Asking
    /// precisely is free, and it gives the system the best chance of an exact
    /// match rather than a near-equivalent.
    static let requested = Locale(identifier: "zh-Hans-CN")

    /// Whether a locale is Mainland Simplified Mandarin.
    ///
    /// Three checks, and the last two are deliberately conditional. The
    /// language code must be `zh` — that is not negotiable, and it is what
    /// rules out `yue` (Cantonese), which the device also offers. Script and
    /// region are checked **only when the locale carries them**: Foundation
    /// derives them for `zh_CN`, but a locale that states neither is not
    /// thereby wrong, and rejecting it would turn a missing detail into a
    /// failure.
    ///
    /// What this rejects, measured against the device's own list: `zh_TW` and
    /// `zh_HK` (both `Hant`), and `yue_CN` (language `yue`).
    static func isMainlandSimplified(_ locale: Locale) -> Bool {
        guard locale.language.languageCode?.identifier == "zh" else { return false }

        if let script = locale.language.script?.identifier, script != "Hans" {
            return false
        }
        if let region = locale.region?.identifier, region != "CN" {
            return false
        }
        return true
    }

    /// Accepts the system's answer, or refuses it.
    ///
    /// Separate from `isMainlandSimplified` so the call site reads as what it
    /// is — a decision with a consequence — and so the "wrong variant means
    /// unavailable" rule can be tested on its own. Silently transcribing into
    /// Traditional characters and comparing them against Simplified cards
    /// would produce mismatches the user cannot explain.
    static func accepted(_ locale: Locale?) -> Locale? {
        guard let locale, isMainlandSimplified(locale) else { return nil }
        return locale
    }
}
