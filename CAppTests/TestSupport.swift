//
//  TestSupport.swift
//  CAppTests
//

import Foundation
import SwiftData
@testable import CApp

/// Ein Container im Speicher, isoliert pro Test.
@MainActor
func makeInMemoryContainer() throws -> ModelContainer {
    try ModelContainer(
        for: CAppApp.schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

/// Ein echter Store auf der Platte an einem temporären Ort.
///
/// Nötig, um einen App-Neustart glaubwürdig zu prüfen: Ein neuer
/// `ModelContainer` auf derselben Datei liest genau das, was ein Neustart der
/// App lesen würde. Ein Test, der innerhalb desselben In-Memory-Containers
/// bleibt, könnte das nicht belegen.
struct TemporaryStore {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appending(path: "CAppTests-\(UUID().uuidString).store")
    }

    /// Öffnet den Store. Zwei Aufrufe hintereinander entsprechen zwei
    /// App-Starts auf derselben Datenbank.
    @MainActor
    func openContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CAppApp.schema,
            configurations: ModelConfiguration(url: url)
        )
    }

    /// Räumt Store-Datei und SQLite-Begleitdateien weg.
    func remove() {
        let manager = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let path = url.path(percentEncoded: false) + suffix
            try? manager.removeItem(at: URL(filePath: path))
        }
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
}

/// `Testing.Tag` und unser Modell `CApp.Tag` heißen gleich, weshalb `Tag` in
/// Testdateien, die beides importieren, nicht eindeutig ist. Diese
/// modulweite Festlegung sorgt dafür, dass `Tag` in den Tests immer das
/// Modell meint. Der Produktivcode ist nicht betroffen — er importiert
/// `Testing` nicht.
typealias Tag = CApp.Tag
