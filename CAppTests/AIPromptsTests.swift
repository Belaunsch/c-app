//
//  AIPromptsTests.swift
//  CAppTests
//

import Testing
import Foundation
import CryptoKit
@testable import CApp

@Suite("AI prompts")
struct AIPromptsTests {

    @Test("The instructions pin German and carry Apple's exact locale phrase")
    func instructionsPinTheLanguage() {
        let instructions = AIPrompts.explanationInstructions
        #expect(instructions.contains("ausschließlich auf Deutsch"))
        // Quoted verbatim from Apple's documentation: it is a trained token
        // sequence, so a paraphrase would not do the same job.
        #expect(instructions.contains("The person's locale is de_DE."))
        #expect(AIPrompts.localePhrase == "The person's locale is de_DE.")
    }

    @Test("The instructions forbid every claim hard rule 7 forbids")
    func instructionsForbidJudgement() {
        let instructions = AIPrompts.explanationInstructions
        #expect(instructions.contains("Aussprache"))
        #expect(instructions.contains("Töne"))
        #expect(instructions.contains("Bewertung"))
        #expect(instructions.contains("Punktzahl"))
        #expect(instructions.contains("Prozentwert"))
        #expect(instructions.contains("Erfinde keine Grammatikregeln"))
    }

    @Test("The card's text goes into the prompt")
    func promptCarriesTheCard() {
        let request = AIPrompts.explanationRequest(german: "ein bisschen", hanzi: "一点")
        #expect(request.prompt.contains("一点"))
        #expect(request.prompt.contains("ein bisschen"))
    }

    @Test("The card's text never reaches the instructions")
    func instructionsStayFreeOfUserText() {
        // The property, not the habit: whatever goes in, the instructions come
        // back byte-identical to the constant. An interpolation at the wrong
        // place fails here.
        let distinctive = "ZZ-Kartentext-ZZ"
        let request = AIPrompts.explanationRequest(german: distinctive, hanzi: distinctive)
        #expect(request.instructions == AIPrompts.explanationInstructions)
        #expect(request.instructions.contains(distinctive) == false)
    }

    @Test("Two different cards share one instruction text")
    func instructionsAreConstantAcrossCards() {
        let first = AIPrompts.explanationRequest(german: "Apfel", hanzi: "苹果")
        let second = AIPrompts.explanationRequest(german: "essen", hanzi: "吃")
        #expect(first.instructions == second.instructions)
        #expect(first.prompt != second.prompt)
    }

    @Test("The instruction and its revision are pinned together")
    func revisionTracksTheInstruction() {
        // The first version of this test only pinned the number — so it failed
        // when someone raised the revision (the *allowed* move) and stayed green
        // when someone edited the instruction **without** raising it, which is
        // the move the rule forbids. Exactly backwards.
        //
        // Pinning both together fixes the direction: change the wording and this
        // fails until the revision and the measurement line follow
        // (`docs/apple-frameworks.md` §12.7).
        // A digest rather than a length: two different wordings can be the same
        // length, so a length would let a real change through. `SHA256` from
        // CryptoKit — a system framework, like every other dependency here.
        let digest = SHA256.hash(data: Data(AIPrompts.explanationInstructions.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()

        #expect(AIPrompts.promptRevision == 1)
        #expect(
            hex == "efdf1d5f275e0d4b4e699b55dffb8b8f9ac8e5404393ca34cf3ba1b198d5293c",
            "the instruction changed — raise promptRevision and add a measurement line"
        )
    }
}
