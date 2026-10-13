//
//  NnRequirementTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

import Testing
import NnArgumentParser

struct NnRequirementTests {
    @Test
    func `Asking a known requirement returns nil without calling the asker`() {
        var askCount = 0

        let answer = makeSUT(known: "configured").ask { _ in
            askCount += 1
            return "asked"
        }

        #expect(answer == nil)
        #expect(askCount == 0)
    }

    @Test
    func `Asking an unknown requirement calls the asker with its info`() {
        var receivedInfo: Int?

        let answer = makeSUT(unknown: 7).ask { info in
            receivedInfo = info
            return "asked"
        }

        #expect(answer == "asked")
        #expect(receivedInfo == 7)
    }
}


// MARK: - Resolve
extension NnRequirementTests {
    @Test
    func `Resolving a known requirement returns the known value and ignores the answer`() throws {
        #expect(try makeSUT(known: "configured").resolve(answer: "typed") == "configured")
    }

    @Test
    func `Resolving an unknown requirement returns the answer`() throws {
        #expect(try makeSUT(unknown: 7).resolve(answer: "typed") == "typed")
    }

    @Test
    func `Resolving an unknown requirement without an answer throws missingAnswer`() {
        #expect(throws: NnWorkflowError.missingAnswer) {
            try makeSUT(unknown: 7).resolve(answer: nil)
        }
    }

    @Test
    func `A missing answer describes itself`() {
        #expect(NnWorkflowError.missingAnswer.errorDescription == "A required value was neither known nor answered.")
    }
}


// MARK: - SUT
private extension NnRequirementTests {
    func makeSUT(known value: String) -> NnRequirement<String, Int> {
        return .known(value)
    }

    func makeSUT(unknown info: Int) -> NnRequirement<String, Int> {
        return .unknown(info)
    }
}
