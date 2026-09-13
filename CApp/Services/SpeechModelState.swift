//
//  SpeechModelState.swift
//  CApp
//

import Speech

/// What the app knows about the Mandarin speech model, and what it may say
/// about it.
///
/// Separate from `SpeechRecognitionService` because none of this needs a
/// device: given a state, the text, the „prepare" button and the „remove"
/// button follow from three rules that a test can walk in full. The service
/// does the asking; this decides what the answer means. It is the same split
/// `RecordAnswerButton` makes for the recording phase, and it exists here for
/// a sharper reason — `canRemove` unlocks a destructive action whose only
/// undo needs an internet connection, so an inverted comparison must not be
/// something only a device test could catch.
///
/// ## Three of the cases are about this app, not about Apple
///
/// `.preparing`, `.downloading`, `.releasing`, `.released` and `.failed`
/// describe what **this app** is doing or has just done; `.assets` carries
/// Apple's own answer. The
/// distinction is what closes the hole the second review found: while the app
/// was downloading, the state still held Apple's last answer — „not loaded
/// yet" — so the settings screen offered the button again and a second tap
/// started a second download beside the first.
nonisolated enum SpeechModelState: Equatable {
    /// Nobody has asked yet.
    case unknown
    /// No transcriber on this device. Permanent.
    case deviceUnsupported
    /// A transcriber, but no Mainland Simplified locale. Also permanent, and
    /// a different sentence — „this device cannot do it at all" and „it
    /// cannot do Chinese" send the user to different places.
    case localeUnsupported
    /// This app is checking, reserving and asking. Nothing is downloading yet.
    case preparing
    /// This app is downloading the model right now.
    case downloading
    /// This app is giving the reservation back right now.
    case releasing
    /// The reservation was given back. Apple removes the data „at a later
    /// time", so a status read right afterwards still says „installed" — and
    /// saying „Bereit" then, next to a button offering to remove it again,
    /// is how a second tap produced „es gab keine Reservierung zurückzugeben"
    /// after a removal that had worked.
    case released
    /// The last attempt failed. The reason is in `modelFailure`; this case
    /// exists so the screen is not a dead end — it is the one failing state
    /// that offers another try.
    case failed
    /// Apple's own answer for the module the app actually uses.
    case assets(AssetInventory.Status)

    /// The line in the settings.
    var text: String {
        switch self {
        case .unknown: "Wird geprüft …"
        case .deviceUnsupported: "Auf diesem Gerät nicht verfügbar"
        case .localeUnsupported: "Für Chinesisch auf diesem Gerät nicht verfügbar"
        case .preparing: "Wird vorbereitet …"
        case .downloading: "Wird geladen …"
        case .releasing: "Wird entfernt …"
        case .released: "Freigegeben — das System löscht die Daten später"
        case .failed: "Nicht geladen"
        case .assets(let status):
            switch status {
            case .installed: "Bereit"
            case .downloading: "Wird geladen …"
            case .supported: "Noch nicht geladen"
            case .unsupported: "Nicht unterstützt"
            @unknown default: "Unbekannt"
            }
        }
    }

    /// Whether a „prepare" button would do anything.
    ///
    /// Three cases: something could be downloaded and is not
    /// (`.assets(.supported)`), the last attempt failed and deserves another
    /// try (`.failed`), or the model was just given back and could be fetched
    /// again (`.released`). Deliberately **not** `.unknown` — that is the
    /// moment before the first answer arrives, and a button offered then
    /// either does nothing or starts a download the app cannot yet say is
    /// needed. And deliberately not while this app is working: the review
    /// found the button sitting next to its own progress bar, inviting the
    /// second press that started a second download.
    var canPrepare: Bool {
        self == .assets(.supported) || self == .failed || self == .released
    }

    /// Whether there is something to give back.
    ///
    /// Strictly `.installed`. Removing is the one action here that costs
    /// something — the way back needs a connection — so it is offered only
    /// when there is demonstrably something on the device.
    var canRemove: Bool {
        self == .assets(.installed)
    }

    /// Whether **this app** currently owns the model state.
    ///
    /// The re-entry guard for `prepare()` and the reason a plain status read
    /// may not overwrite the state: a run in flight knows more than a
    /// measurement taken beside it. `.assets(.downloading)` is not included —
    /// that is Apple downloading on its own, which no run of ours owns and
    /// which a later status read may correct.
    var isBusy: Bool {
        self == .preparing || self == .downloading || self == .releasing
    }
}
