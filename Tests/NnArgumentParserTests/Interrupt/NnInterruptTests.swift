//
//  NnInterruptTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Testing
import Foundation
@testable import NnArgumentParser
import NnArgumentParserTesting

struct NnInterruptTests {
    @Test
    func `Cleanups run in reverse registration order`() {
        let log = CleanupLog()

        withIsolatedState {
            NnInterrupt.register(cleanup: { log.record("first") })
            NnInterrupt.register(cleanup: { log.record("second") })
            NnInterrupt.register(cleanup: { log.record("third") })

            runCleanups()
        }

        #expect(log.entries == ["third", "second", "first"])
    }

    @Test
    func `A scope with no registrations has no cleanups`() {
        let count = withIsolatedState {
            NnInterrupt.cleanups(in: currentBox()).count
        }

        #expect(count == 0)
    }

    @Test
    func `A cleanup registered after an await lands in the run's list`() async throws {
        let log = CleanupLog()

        try await withIsolatedState {
            NnInterrupt.register(cleanup: { log.record("before") })
            try await Task.sleep(for: .milliseconds(5))
            NnInterrupt.register(cleanup: { log.record("after") })

            runCleanups()
        }

        #expect(log.entries == ["after", "before"])
    }
}


// MARK: - Isolation
extension NnInterruptTests {
    @Test
    func `Concurrent scopes keep separate cleanup lists`() async throws {
        let firstLog = CleanupLog()
        let secondLog = CleanupLog()

        async let first: Void = registerThenRun(name: "first", log: firstLog)
        async let second: Void = registerThenRun(name: "second", log: secondLog)
        _ = try await (first, second)

        #expect(firstLog.entries == ["first"])
        #expect(secondLog.entries == ["second"])
    }

    @Test
    func `Concurrent registrations in one scope are all kept`() async {
        let log = CleanupLog()

        await withIsolatedState {
            await withTaskGroup(of: Void.self) { group in
                for index in 0..<50 {
                    group.addTask { NnInterrupt.register(cleanup: { log.record("\(index)") }) }
                }
            }

            runCleanups()
        }

        #expect(log.entries.count == 50)
    }
}


// MARK: - Unscoped Access
extension NnInterruptTests {
    #if compiler(>=6.2)
    @Test
    func `Registering a cleanup outside any scope traps`() async {
        await #expect(processExitsWith: .failure) {
            NnInterrupt.register(cleanup: { })
        }
    }
    #endif
}


// MARK: - SUT
private extension NnInterruptTests {
    func currentBox() -> NnStateBox {
        return NnStateScope.requiredBox(for: "NnInterruptTests")
    }

    func runCleanups() {
        for cleanup in NnInterrupt.cleanups(in: currentBox()) {
            cleanup()
        }
    }

    func registerThenRun(name: String, log: CleanupLog) async throws {
        try await withIsolatedState {
            NnInterrupt.register(cleanup: { log.record(name) })
            try await Task.sleep(for: .milliseconds(5))

            runCleanups()
        }
    }
}


// MARK: - Test Doubles
private final class CleanupLog: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    var entries: [String] {
        return lock.withLock { recorded }
    }

    func record(_ entry: String) {
        lock.withLock { recorded.append(entry) }
    }
}
