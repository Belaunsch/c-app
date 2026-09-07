//
//  Tag.swift
//  CApp
//

import Foundation
import SwiftData

/// Eine inhaltliche Kategorie, zum Beispiel „Essen" oder „Reisen".
///
/// Tags sind vom `LearningStatus` einer Karte strikt getrennt: Der Tag sagt,
/// *worum* es geht, der Lernstatus, *wie gut* die Karte sitzt.
@Model
final class Tag {
    var name: String = ""

    /// Gegenstück zu `Card.tags`. Die Löschregel ist `.nullify`: Ein
    /// gelöschter Tag nimmt keine Karten mit, es verschwindet nur die
    /// Zuordnung. Die Inverse ist auf `Card.tags` deklariert.
    @Relationship(deleteRule: .nullify)
    var cards: [Card] = []

    init(name: String, cards: [Card] = []) {
        self.name = name
        self.cards = cards
    }
}
