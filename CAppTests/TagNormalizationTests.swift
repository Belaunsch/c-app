//
//  TagNormalizationTests.swift
//  CAppTests
//

import Foundation
import SwiftData
import Testing
@testable import CApp

struct TagNormalizationTests {

    @Test("Casing does not create a second tag")
    func keyIgnoresCasing() {
        #expect(TagNormalization.key(for: "Essen") == TagNormalization.key(for: "essen"))
        #expect(TagNormalization.key(for: "Essen") == TagNormalization.key(for: "ESSEN"))
    }

    @Test("Surrounding whitespace does not create a second tag")
    func keyIgnoresSurroundingWhitespace() {
        #expect(TagNormalization.key(for: "  Essen  ") == TagNormalization.key(for: "Essen"))
    }

    @Test("Repeated inner whitespace does not create a second tag")
    func keyCollapsesInnerWhitespace() {
        #expect(
            TagNormalization.key(for: "Im   Restaurant")
                == TagNormalization.key(for: "Im Restaurant")
        )
    }

    @Test("Genuinely different names keep different keys")
    func differentNamesKeepDifferentKeys() {
        #expect(TagNormalization.key(for: "Essen") != TagNormalization.key(for: "Reisen"))
    }

    @Test("The stored spelling keeps the user's casing but is tidied up")
    func displayNamePreservesCasingAndTrims() {
        #expect(TagNormalization.displayName(for: "  Essen  ") == "Essen")
        #expect(TagNormalization.displayName(for: "im   Restaurant") == "im Restaurant")
        #expect(TagNormalization.displayName(for: "ESSEN") == "ESSEN")
    }

    @Test("Blank names are not valid tags")
    func blankNamesAreInvalid() {
        #expect(TagNormalization.isValid("") == false)
        #expect(TagNormalization.isValid("   ") == false)
        #expect(TagNormalization.isValid("\n\t") == false)
        #expect(TagNormalization.isValid("Essen"))
    }

    @MainActor
    @Test("An existing tag is found regardless of casing and whitespace")
    func existingTagIsFoundAcrossSpellings() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let food = Tag(name: "Essen")
        let travel = Tag(name: "Reisen")
        context.insert(food)
        context.insert(travel)
        try context.save()

        let tags = [food, travel]

        #expect(TagNormalization.existingTag(matching: "essen", in: tags) === food)
        #expect(TagNormalization.existingTag(matching: "  ESSEN ", in: tags) === food)
        #expect(TagNormalization.existingTag(matching: "Reisen", in: tags) === travel)
    }

    @MainActor
    @Test("A genuinely new name matches no existing tag")
    func newNameMatchesNothing() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let food = Tag(name: "Essen")
        context.insert(food)
        try context.save()

        #expect(TagNormalization.existingTag(matching: "Hotel", in: [food]) == nil)
    }

    @MainActor
    @Test("A blank name matches no existing tag, not even an empty-named one")
    func blankNameMatchesNothing() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let odd = Tag(name: "")
        context.insert(odd)
        try context.save()

        #expect(TagNormalization.existingTag(matching: "   ", in: [odd]) == nil)
    }
}
