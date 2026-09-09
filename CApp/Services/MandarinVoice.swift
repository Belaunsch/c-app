//
//  MandarinVoice.swift
//  CApp
//

import Foundation

/// What the app knows about one installed voice, without AVFoundation.
///
/// The selection is the one part of speech synthesis that is decidable from
/// data alone, so it lives here as a value type and a pure function. That
/// keeps it testable without a simulator and without pretending an
/// `AVSpeechSynthesisVoice` can be constructed for a test.
///
/// `nonisolated` like the other pure types: the target defaults to
/// main-actor isolation, and a value type has no business requiring an actor
/// (Q8 in `docs/apple-frameworks.md`).
nonisolated struct VoiceCandidate: Equatable, Sendable {
    let identifier: String
    /// A BCP 47 tag, documented as such: `zh-CN`, `en-AU`.
    let language: String
    let quality: VoiceQuality
    /// Only for the report in `apple-frameworks.md` and for diagnostics.
    let name: String

    init(identifier: String, language: String, quality: VoiceQuality, name: String = "") {
        self.identifier = identifier
        self.language = language
        self.quality = quality
        self.name = name
    }
}

/// The three quality classes, in an order this app defines.
///
/// Apple's own `AVSpeechSynthesisVoiceQuality` does **not** conform to
/// `Comparable`, and no ordering is documented — the raw values happen to
/// increase with quality, but that is not a contract. So the ranking is
/// written down here, once, with an explicit `switch` that a new case cannot
/// silently join.
nonisolated enum VoiceQuality: Int, Comparable, CaseIterable, Sendable {
    case `default` = 0
    case enhanced = 1
    case premium = 2

    static func < (lhs: VoiceQuality, rhs: VoiceQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Picks the voice the app speaks Mandarin with.
///
/// Three steps, and the third is the interesting one.
///
/// 1. **Keep only Mainland Mandarin.** Matched on the parsed language tag,
///    not on string equality: `zh-CN` and `zh-Hans-CN` are the same request,
///    `zh-TW` and `yue-HK` are not. The device carries nine `zh-TW` voices
///    that would otherwise be candidates.
/// 2. **Rank by quality**, `premium` before `enhanced` before `default`.
/// 3. **Break the tie inside the winning class.** Only reached when the
///    winning class holds more than one voice. The device's first
///    measurement was exactly that case: *all nine* `zh-CN` voices reported
///    `.default`, with no technical criterion to separate them.
///    `voiceTraits` is `0` for all of them, so the documented
///    `isNoveltyVoice` filter does not apply either, and
///    `AVSpeechSynthesisVoice(language:)` is no help: its only documented
///    rule is "enhanced if available, default otherwise", which decides
///    nothing among nine `default` voices.
///
///    So the tie is broken by a **preferred-identifier list**, and that list
///    is a product decision from a physical listening comparison on
///    2026-09-09, not a claim about technical superiority — see Q5. Tingting
///    was clearly better than the Eloquence voice it was compared against.
///    A positive preference rather than an Eloquence blocklist: it says what
///    was tested instead of guessing about what was not.
///
///    Anything the list does not name falls back to the lexicographically
///    smallest identifier, which is stable but arbitrary — better than the
///    undefined order of `speechVoices()`.
///
/// Once `Lili (Premium)` was installed on that same device, step 2 decided on
/// its own and step 3 was never reached — measured, and confirmed by ear in a
/// direct comparison against Tingting (Q5). There is deliberately **no**
/// special case for Lili in this code: the quality order already picks it,
/// and a name check would only break on the next device.
nonisolated enum MandarinVoiceSelection {

    /// The identifier the listening test settled on, most preferred first.
    ///
    /// Deliberately small and deliberately documented as empirical. It is
    /// consulted only when the best installed class holds several voices;
    /// with an `.enhanced` or `.premium` Mandarin voice present, step 2
    /// decides first. For `Lili (Premium)` the listening test confirmed that
    /// Apple's class matches what one hears; for any **other** premium or
    /// enhanced voice the app takes Apple's classification on trust, which
    /// the phase-7 device test did not validate.
    static let preferredIdentifiers = ["com.apple.voice.super-compact.zh-CN.Tingting"]

    static func best(
        from candidates: [VoiceCandidate],
        preferring preferred: [String] = preferredIdentifiers
    ) -> VoiceCandidate? {
        let mandarin = candidates.filter { isMainlandMandarin($0.language) }
        guard let bestQuality = mandarin.map(\.quality).max() else { return nil }
        let contenders = mandarin.filter { $0.quality == bestQuality }

        for identifier in preferred {
            if let match = contenders.first(where: { $0.identifier == identifier }) {
                return match
            }
        }
        return contenders.min { $0.identifier < $1.identifier }
    }

    /// Whether a BCP 47 tag means Mandarin as spoken in mainland China.
    ///
    /// Parsed rather than compared: `language` is documented as BCP 47, and
    /// the same request can be written `zh-CN`, `zh-Hans-CN` or with a
    /// lowercase region. What must **not** pass is `zh-TW` and `zh-HK` —
    /// Mandarin in Taiwan reads some characters differently and Cantonese is
    /// another language entirely.
    static func isMainlandMandarin(_ tag: String) -> Bool {
        let language = Locale.Language(identifier: tag)
        guard language.languageCode == .chinese else { return false }
        guard let region = Locale.Language(identifier: tag).region else { return false }
        return region == Locale.Region("CN")
    }
}
