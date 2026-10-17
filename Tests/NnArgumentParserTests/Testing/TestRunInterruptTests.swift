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

    @Test
    func `Registered cleanups are returned without being run`() async throws {
        let log = CleanupCallLog()

        let result = try await CleanupRoot.testRunCapturingCleanups(contextFactory: log, args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(result.interruptCleanups.count == 1)
        #expect(log.callCount == 0)
    }

    @Test
    func `A returned cleanup runs the command's teardown`() async throws {
        let log = CleanupCallLog()

        let result = try await CleanupRoot.testRunCapturingCleanups(contextFactory: log, args: [], interactionMode: .nonInteractive(assumeYes: false))
        result.interruptCleanups.forEach { $0() }

        #expect(log.callCount == 1)
    }

    @Test
    func `Returned cleanups are in reverse registration order`() async throws {
        let log = CleanupEntryLog()

        let result = try await OrderedCleanupRoot.testRunCapturingCleanups(contextFactory: log, args: [], interactionMode: .nonInteractive(assumeYes: false))
        result.interruptCleanups.forEach { $0() }

        #expect(log.entries == ["second", "first"])
    }

    @Test
    func `A cleanup registered after an await is returned`() async throws {
        let log = CleanupEntryLog()

        let result = try await OrderedCleanupRoot.testRunCapturingCleanups(contextFactory: log, args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(result.interruptCleanups.count == 2)
    }

    @Test
    func `A run that registers nothing returns no cleanups`() async throws {
        let result = try await SilentRoot.testRunCapturingCleanups(contextFactory: CleanupCallLog(), args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(result.interruptCleanups.isEmpty)
    }

    @Test
    func `Output matches what testRun returns`() async throws {
        let output = try await CleanupRoot.testRun(contextFactory: CleanupCallLog(), args: [], interactionMode: .nonInteractive(assumeYes: false))
        let result = try await CleanupRoot.testRunCapturingCleanups(contextFactory: CleanupCallLog(), args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(result.output == output)
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

private struct OrderedCleanupRoot: NnRootCommand {
    static var defaultFactory: CleanupEntryLog { CleanupEntryLog() }

    func run() async throws {
        let log = Self.contextFactory

        NnInterrupt.register(cleanup: { log.record("first") })
        await Task.yield()
        NnInterrupt.register(cleanup: { log.record("second") })
        NnOutput.write("ran")
    }
}

private struct SilentRoot: NnRootCommand {
    static var defaultFactory: CleanupCallLog { CleanupCallLog() }

    func run() async throws {
        NnOutput.write("ran")
    }
}

private final class CleanupEntryLog: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    var entries: [String] {
        return lock.withLock { recorded }
    }

    func record(_ entry: String) {
        lock.withLock { recorded.append(entry) }
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
