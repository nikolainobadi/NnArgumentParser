//
//  NnWorkflowErrorTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

import Testing
import NnArgumentParser

struct NnWorkflowErrorTests {
    @Test
    func `A missing answer describes itself`() {
        #expect(NnWorkflowError.missingAnswer.errorDescription == "A required value was neither known nor answered.")
    }

    @Test
    func `Unsatisfied requirements are described one per line`() {
        let description = makeSUT(requirements: [
            .init(name: "version", flagHint: "<version>", remedy: "No version to release."),
            .init(name: "target", flagHint: "--target", remedy: "Two libraries: Core, UI.")
        ]).errorDescription

        #expect(description == """
        This run can't prompt, and these values are missing:
          version: No version to release. Pass <version>.
          target: Two libraries: Core, UI. Pass --target.
        """)
    }

    @Test
    func `A requirement without a flag hint ends at its remedy`() {
        let description = makeSUT(requirements: [
            .init(name: "release branch", flagHint: nil, remedy: "Run interactively to choose one.")
        ]).errorDescription

        #expect(description == """
        This run can't prompt, and these values are missing:
          release branch: Run interactively to choose one.
        """)
    }
}


// MARK: - SUT
private extension NnWorkflowErrorTests {
    func makeSUT(requirements: [NnUnsatisfiedRequirement]) -> NnWorkflowError {
        return .unsatisfiedRequirements(requirements)
    }
}
