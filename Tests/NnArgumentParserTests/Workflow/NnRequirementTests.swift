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
}


// MARK: - Report
extension NnRequirementTests {
    @Test
    func `Reporting a known requirement returns nil`() {
        let report = makeSUT(known: "configured").report(name: "version", flagHint: "<version>") { _ in "unused" }

        #expect(report == nil)
    }

    @Test
    func `Reporting an unknown requirement carries the name, flag hint, and a remedy built from info`() {
        let report = makeSUT(unknown: 7).report(name: "version", flagHint: "<version>") { info in "Seen \(info) candidates." }

        #expect(report == .init(name: "version", flagHint: "<version>", remedy: "Seen 7 candidates."))
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
