//
//  RunOutcomeTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/25/26.
//

import Testing
@testable import NnArgumentParser

struct RunOutcomeTests {
    @Test
    func `Success maps to succeeded`() {
        #expect(OutcomeRoot.runOutcome(for: .success(())) == .succeeded)
    }

    @Test
    func `A thrown error maps to failed with its message, without the Error prefix`() throws {
        let outcome = OutcomeRoot.runOutcome(for: .failure(OutcomeTestError.boom))

        guard case .failed(let message, _) = outcome else {
            Issue.record("Expected .failed, got \(outcome)")
            return
        }

        #expect(message == "boom")
    }

    @Test
    func `A thrown error maps to failed with exit code 1`() {
        let outcome = OutcomeRoot.runOutcome(for: .failure(OutcomeTestError.boom))

        #expect(outcome == .failed(message: "boom", exitCode: 1))
    }

    @Test
    func `ExitCode(3) maps to failed with exit code 3`() {
        let outcome = OutcomeRoot.runOutcome(for: .failure(ExitCode(3)))

        guard case .failed(_, let exitCode) = outcome else {
            Issue.record("Expected .failed, got \(outcome)")
            return
        }

        #expect(exitCode == 3)
    }

    @Test
    func `ExitCode.success maps to succeeded`() {
        #expect(OutcomeRoot.runOutcome(for: .failure(ExitCode.success)) == .succeeded)
    }

    @Test
    func `CleanExit maps to succeeded`() {
        #expect(OutcomeRoot.runOutcome(for: .failure(CleanExit.message("done"))) == .succeeded)
    }
}


// MARK: - Test Doubles
private enum OutcomeTestError: Error, CustomStringConvertible {
    case boom

    var description: String {
        return "boom"
    }
}

private struct OutcomeRoot: NnRootCommand {
    static var defaultFactory: Void { () }

    func run() async throws { }
}
