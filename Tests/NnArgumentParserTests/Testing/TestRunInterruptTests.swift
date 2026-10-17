//
//  TestRunInterruptTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Testing
import Foundation
import NnArgumentParser
import NnArgumentParserTesting

struct TestRunInterruptTests {
    @Test
    func `A command that registers a cleanup runs normally, and the cleanup never runs`() async throws {
        let log = CleanupCallLog()

        let output = try await CleanupRoot.testRun(contextFactory: log, args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(output == "ran")
        #expect(log.callCount == 0)
    }
}


// MARK: - Test Doubles
private struct CleanupRoot: NnRootCommand {
    static var defaultFactory: CleanupCallLog { CleanupCallLog() }

    func run() async throws {
        let log = Self.contextFactory

        NnInterrupt.register(cleanup: { log.recordCall() })
        NnOutput.write("ran")
    }
}

private final class CleanupCallLog: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0

    var callCount: Int {
        return lock.withLock { calls }
    }

    func recordCall() {
        lock.withLock { calls += 1 }
    }
}
