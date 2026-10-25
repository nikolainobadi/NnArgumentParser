//
//  TestRunCompletionTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/25/26.
//

import Testing
import Foundation
import NnArgumentParser
import NnArgumentParserTesting

struct TestRunCompletionTests {
    @Test
    func `testRun tells observers a successful run succeeded`() async throws {
        let log = OutcomeRecorder()

        try await ObservedRoot.testRun(contextFactory: log, args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(log.outcomes == [.succeeded])
    }

    @Test
    func `testRun tells observers a failed run failed, then rethrows the error`() async throws {
        let log = OutcomeRecorder()

        await #expect(throws: CompletionTestError.boom) {
            try await ObservedRoot.testRun(contextFactory: log, args: ["--fail"], interactionMode: .nonInteractive(assumeYes: false))
        }

        #expect(log.outcomes == [.failed(message: "boom", exitCode: 1)])
    }

    @Test
    func `testRunCapturingCleanups also notifies observers`() async throws {
        let log = OutcomeRecorder()

        _ = try await ObservedRoot.testRunCapturingCleanups(contextFactory: log, args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(log.outcomes == [.succeeded])
    }

    @Test
    func `testRun tells an observer registered in validate() about a validation failure`() async throws {
        let log = OutcomeRecorder()

        // ArgumentParser wraps a validation failure in its own internal error type.
        await #expect(throws: (any Error).self) {
            try await ValidatingRoot.testRun(contextFactory: log, args: [], interactionMode: .nonInteractive(assumeYes: false))
        }

        #expect(log.outcomes == [.failed(message: "invalid", exitCode: ExitCode.validationFailure.rawValue)])
    }

    @Test
    func `Observers registered in one testRun don't see another run`() async throws {
        let succeeding = OutcomeRecorder()
        let failing = OutcomeRecorder()

        async let first = ObservedRoot.testRun(contextFactory: succeeding, args: [], interactionMode: .nonInteractive(assumeYes: false))
        async let second: Void = expectFailure(of: failing)
        _ = try await (first, second)

        #expect(succeeding.outcomes == [.succeeded])
        #expect(failing.outcomes == [.failed(message: "boom", exitCode: 1)])
    }
}


// MARK: - Helpers
private func expectFailure(of log: OutcomeRecorder) async {
    await #expect(throws: CompletionTestError.boom) {
        try await ObservedRoot.testRun(contextFactory: log, args: ["--fail"], interactionMode: .nonInteractive(assumeYes: false))
    }
}


// MARK: - Test Doubles
private enum CompletionTestError: Error, Equatable, CustomStringConvertible {
    case boom

    var description: String {
        return "boom"
    }
}

private struct ObservedRoot: NnRootCommand {
    static var defaultFactory: OutcomeRecorder { OutcomeRecorder() }

    @Flag var fail = false

    func run() async throws {
        let log = Self.contextFactory

        NnCompletion.register(observer: { log.record($0) })
        try await Task.sleep(for: .milliseconds(5))

        if fail {
            throw CompletionTestError.boom
        }
    }
}

private struct ValidatingRoot: NnRootCommand {
    static var defaultFactory: OutcomeRecorder { OutcomeRecorder() }

    func validate() throws {
        let log = Self.contextFactory

        NnCompletion.register(observer: { log.record($0) })

        throw ValidationError("invalid")
    }

    func run() async throws { }
}

private final class OutcomeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [NnRunOutcome] = []

    var outcomes: [NnRunOutcome] {
        return lock.withLock { recorded }
    }

    func record(_ outcome: NnRunOutcome) {
        lock.withLock { recorded.append(outcome) }
    }
}
