//
//  SpeakButton.swift
//  CApp
//

import SwiftUI

/// A speaker that says the Chinese out loud.
///
/// One component for all three places — the revealed card, the card list and
/// the editor — so the behaviour cannot drift between them.
///
/// ## Why a plain `Button` with `.borderless`
///
/// Phase 6 cost two device-test rounds on exactly this: a control inside a
/// `Form` row or a `List` row that loses its action. The lessons from A27 are
/// applied here rather than rediscovered:
///
/// - **A plain `Button`, no gesture of its own.** No container gesture, no
///   `simultaneousGesture`, no hit testing. The tap belongs to the button.
/// - **`.buttonStyle(.borderless)`** so the row does not become the button.
///   Without it, tapping anywhere in a card row would speak, and in a
///   `NavigationLink` row the two actions would fight.
///
/// ## Why it disappears instead of greying out
///
/// A speaker that cannot speak is worse than no speaker: it invites a tap
/// that does nothing. It is hidden when the device has no Mandarin voice, and
/// when the text is not usable Chinese.
struct SpeakButton: View {
    /// The Hanzi to speak. The **caller** decides what is current — the
    /// stored card in the list, the live text in the editor.
    let hanzi: String

    @Environment(SpeechSynthesisService.self) private var speech

    /// Whether *this* button's text is the one being spoken.
    ///
    /// `speech.isSpeaking` alone is global: in the card list it would fill
    /// every visible speaker at once, not the one that was tapped. Found by
    /// the review. Comparing the text is enough here and needs no per-button
    /// identity — two cards with the same Hanzi are the same sound.
    private var isSpeakingThis: Bool {
        Self.isSpeaking(hanzi, isSpeaking: speech.isSpeaking, spokenText: speech.spokenText)
    }

    /// Whether *this* text is the one playing. Pulled out for the same reason
    /// as `isVisible`: the audit showed the comparison could be deleted
    /// entirely without a single test failing, which would bring back the bug
    /// it was written to fix.
    static func isSpeaking(_ hanzi: String, isSpeaking: Bool, spokenText: String?) -> Bool {
        guard isSpeaking else { return false }
        return spokenText == hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the speaker belongs on screen at all.
    ///
    /// A static function rather than a condition buried in `body`, for the
    /// reason this project pulls every decision out of its view: a `body` is
    /// not reachable from a test, so a rule that lives only there is a rule
    /// nobody can falsify. The audit measured `body` at 0 % and showed that
    /// dropping either half of this condition passed the whole suite.
    static func isVisible(isAvailable: Bool, hanzi: String) -> Bool {
        isAvailable && SpeechSynthesisService.canSpeak(hanzi)
    }

    var body: some View {
        if Self.isVisible(isAvailable: speech.isAvailable, hanzi: hanzi) {
            Button {
                speech.speak(hanzi)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .symbolVariant(isSpeakingThis ? .fill : .none)
            }
            // The reason this exists at all: see the type's documentation.
            .buttonStyle(.borderless)
            .accessibilityLabel("Chinesisch vorlesen")
        }
    }
}

/// Tells the user once per app run that no Mandarin voice is installed.
///
/// The path into Settings is deliberately vague about the last step. Apple
/// renames these screens between versions, and a wrong navigation
/// instruction is worse than a general one.
///
/// Deliberately **not** `@Observable` and holding no presentation state.
///
/// It answers one question — "has this run already said it?" — and the view
/// owns the flag that drives the alert. An earlier version kept
/// `isPresented` here and bound the alert through a manual `Binding`; the
/// review pointed out that `body` then reads no observable property at all,
/// so the mutation would not reliably re-evaluate the view. Every other
/// alert in this app pairs such a binding with `presenting:`, and that
/// parameter is the in-body read that makes them work. This one had no
/// equivalent, so the state moved into the view where SwiftUI tracks it
/// without a caveat.
@MainActor
final class MissingVoiceNotice {
    private var shownThisRun = false

    static let message = """
        Für die Aussprache fehlt eine chinesische Stimme. Sie lässt sich in \
        den iOS-Einstellungen unter „Bedienungshilfen“ bei den gesprochenen \
        Inhalten nachladen.
        """

    /// Whether the notice should be shown now. `true` at most once per app
    /// run — there is no stored flag and no schema field, so a restart may
    /// ask again. That is intended: the situation is still true, and a
    /// permanent "never again" would hide something the user can fix.
    func shouldShow() -> Bool {
        guard Self.shouldShow(alreadyShown: shownThisRun) else { return false }
        shownThisRun = true
        return true
    }

    /// The decision on its own: show it if this run has not said it yet.
    ///
    /// Trivial today, and written down anyway — the audit could pin
    /// `isAvailable` to `true` without a test failing, so the whole
    /// "no voice" consequence rested on a `body` nobody can reach.
    static func shouldShow(alreadyShown: Bool) -> Bool {
        alreadyShown == false
    }
}
