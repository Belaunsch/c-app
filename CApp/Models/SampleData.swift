//
//  SampleData.swift
//  CApp
//

#if DEBUG
import Foundation
import SwiftData

/// Beispieldaten für SwiftUI-Previews und Tests.
///
/// Der gesamte Typ steht unter `#if DEBUG` und ist im Release-Build nicht
/// vorhanden. Die App schreibt beim normalen Start **keine** Beispieldaten in
/// den persistenten Benutzerstore: Der produktive Container in `CAppApp`
/// kennt diesen Typ nicht, und `makePreviewContainer()` legt seinen Store
/// ausschließlich im Speicher an.
enum SampleData {

    /// Die inhaltlichen Kategorien der Beispieldaten.
    static let tagNames = [
        "Alltag", "Essen", "Restaurant", "Reisen", "Hotel",
        "Familie", "Smalltalk", "Verben", "Zahlen",
    ]

    /// Ein Container mit Beispieldaten, ausschließlich im Speicher.
    ///
    /// Für Previews gedacht. `#Preview` nimmt eine nicht-werfende Closure,
    /// deshalb muss der Fehlerfall dort behandelt werden:
    ///
    /// ```swift
    /// #Preview {
    ///     if let container = try? SampleData.makePreviewContainer() {
    ///         RootView().modelContainer(container)
    ///     } else {
    ///         Text("Vorschaudaten nicht verfügbar")
    ///     }
    /// }
    /// ```
    @MainActor
    static func makePreviewContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: Card.self, Tag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        insert(into: container.mainContext)
        return container
    }

    /// Legt Tags und Karten im übergebenen Kontext an.
    ///
    /// Speichert bewusst nicht selbst — der Aufrufer entscheidet, wann und ob
    /// gespeichert wird.
    static func insert(into context: ModelContext) {
        var tags: [String: Tag] = [:]
        for name in tagNames {
            let tag = Tag(name: name)
            context.insert(tag)
            tags[name] = tag
        }

        for (offset, seed) in seeds.enumerated() {
            let card = Card(
                type: seed.type,
                german: seed.german,
                hanzi: seed.hanzi,
                pinyin: seed.pinyin,
                status: seed.status,
                createdAt: .now.addingTimeInterval(-Double(seeds.count - offset) * 3600),
                lastReviewedAt: lastReviewedAt(for: seed.status),
                reviewCount: counts(for: seed.status).reviews,
                correctCount: counts(for: seed.status).correct,
                tags: seed.tags.compactMap { tags[$0] }
            )
            context.insert(card)
        }
    }

    // MARK: - Rohdaten

    private struct Seed {
        let type: CardType
        let german: String
        let hanzi: String
        let pinyin: String
        let status: LearningStatus
        let tags: [String]
    }

    /// 20 Wortkarten und 10 Satzkarten über alle Lernstufen.
    private static let seeds: [Seed] = [
        // 20 Wortkarten
        Seed(type: .word, german: "Apfel", hanzi: "苹果", pinyin: "píngguǒ", status: .secure, tags: ["Essen"]),
        Seed(type: .word, german: "Wasser", hanzi: "水", pinyin: "shuǐ", status: .secure, tags: ["Essen", "Alltag"]),
        Seed(type: .word, german: "Reis", hanzi: "米饭", pinyin: "mǐfàn", status: .good, tags: ["Essen", "Restaurant"]),
        Seed(type: .word, german: "Tee", hanzi: "茶", pinyin: "chá", status: .good, tags: ["Essen"]),
        Seed(type: .word, german: "Bier", hanzi: "啤酒", pinyin: "píjiǔ", status: .medium, tags: ["Essen", "Restaurant"]),
        Seed(type: .word, german: "Familie", hanzi: "家庭", pinyin: "jiātíng", status: .medium, tags: ["Familie"]),
        Seed(type: .word, german: "Mutter", hanzi: "妈妈", pinyin: "māma", status: .secure, tags: ["Familie"]),
        Seed(type: .word, german: "Vater", hanzi: "爸爸", pinyin: "bàba", status: .secure, tags: ["Familie"]),
        Seed(type: .word, german: "Hotel", hanzi: "酒店", pinyin: "jiǔdiàn", status: .weak, tags: ["Hotel", "Reisen"]),
        Seed(type: .word, german: "Bahnhof", hanzi: "火车站", pinyin: "huǒchēzhàn", status: .medium, tags: ["Reisen"]),
        Seed(type: .word, german: "Flughafen", hanzi: "机场", pinyin: "jīchǎng", status: .weak, tags: ["Reisen"]),
        Seed(type: .word, german: "essen", hanzi: "吃", pinyin: "chī", status: .good, tags: ["Verben", "Essen"]),
        Seed(type: .word, german: "trinken", hanzi: "喝", pinyin: "hē", status: .good, tags: ["Verben", "Essen"]),
        Seed(type: .word, german: "gehen", hanzi: "走", pinyin: "zǒu", status: .medium, tags: ["Verben"]),
        Seed(type: .word, german: "sprechen", hanzi: "说", pinyin: "shuō", status: .weak, tags: ["Verben"]),
        Seed(type: .word, german: "eins", hanzi: "一", pinyin: "yī", status: .secure, tags: ["Zahlen"]),
        Seed(type: .word, german: "zwei", hanzi: "二", pinyin: "èr", status: .secure, tags: ["Zahlen"]),
        Seed(type: .word, german: "drei", hanzi: "三", pinyin: "sān", status: .good, tags: ["Zahlen"]),
        Seed(type: .word, german: "Rechnung", hanzi: "账单", pinyin: "zhàngdān", status: .new, tags: ["Restaurant"]),
        Seed(type: .word, german: "danke", hanzi: "谢谢", pinyin: "xièxie", status: .secure, tags: ["Smalltalk", "Alltag"]),

        // 10 Satzkarten
        Seed(type: .sentence, german: "Ich möchte etwas essen.", hanzi: "我想吃点东西。", pinyin: "wǒ xiǎng chī diǎn dōngxi", status: .medium, tags: ["Restaurant", "Essen"]),
        Seed(type: .sentence, german: "Wo ist die Toilette?", hanzi: "洗手间在哪里？", pinyin: "xǐshǒujiān zài nǎlǐ", status: .weak, tags: ["Alltag"]),
        Seed(type: .sentence, german: "Die Rechnung, bitte.", hanzi: "请结账。", pinyin: "qǐng jiézhàng", status: .new, tags: ["Restaurant"]),
        Seed(type: .sentence, german: "Wie viel kostet das?", hanzi: "这个多少钱？", pinyin: "zhège duōshao qián", status: .good, tags: ["Alltag"]),
        Seed(type: .sentence, german: "Ich verstehe nicht.", hanzi: "我不明白。", pinyin: "wǒ bù míngbai", status: .good, tags: ["Smalltalk"]),
        Seed(type: .sentence, german: "Sprechen Sie Englisch?", hanzi: "你会说英语吗？", pinyin: "nǐ huì shuō Yīngyǔ ma", status: .weak, tags: ["Smalltalk"]),
        Seed(type: .sentence, german: "Ich hätte gern ein Zimmer.", hanzi: "我想要一个房间。", pinyin: "wǒ xiǎng yào yí ge fángjiān", status: .new, tags: ["Hotel"]),
        Seed(type: .sentence, german: "Wo ist der Bahnhof?", hanzi: "火车站在哪里？", pinyin: "huǒchēzhàn zài nǎlǐ", status: .medium, tags: ["Reisen"]),
        Seed(type: .sentence, german: "Guten Morgen!", hanzi: "早上好！", pinyin: "zǎoshang hǎo", status: .secure, tags: ["Smalltalk", "Alltag"]),
        Seed(type: .sentence, german: "Ich komme aus Deutschland.", hanzi: "我来自德国。", pinyin: "wǒ láizì Déguó", status: .good, tags: ["Smalltalk"]),
    ]

    // MARK: - Abgeleitete Lernmetadaten

    /// Hält die Zähler plausibel zum Lernstatus, damit Previews keine
    /// widersprüchlichen Karten zeigen (etwa `secure` mit null Wiederholungen).
    private static func counts(for status: LearningStatus) -> (reviews: Int, correct: Int) {
        switch status {
        case .new: (0, 0)
        case .weak: (4, 1)
        case .medium: (6, 4)
        case .good: (9, 8)
        case .secure: (14, 14)
        }
    }

    private static func lastReviewedAt(for status: LearningStatus) -> Date? {
        guard status != .new else { return nil }
        let daysAgo = Double(status.rawValue)
        return .now.addingTimeInterval(-daysAgo * 86_400)
    }
}
#endif
