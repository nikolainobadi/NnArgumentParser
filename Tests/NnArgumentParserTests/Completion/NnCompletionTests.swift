//
//  NnCompletionTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/25/26.
//

import Testing
import Foundation
@testable import NnArgumentParser
import NnArgumentParserTesting

struct NnCompletionTests {
    @Test
    func `Observers are returned in registration order`() {
        let log = OutcomeLog()

        withIsolatedState {
            NnCompletion.register(observer: { _ in log.record("first") })
            NnCompletion.register(observer: { _ in log.record("second") })
            NnCompletion.register(observer: { _ in log.record("third") })

            for observer in NnCompletion.observers(in: currentBox()) {
                observer(.succeeded)
            }
        }

        #expect(log.entries == ["first", "second", "third"])
    }

    @Test
    func `A scope with no observers returns none`() {
        let count = withIsolatedState {
            NnCompletion.observers(in: currentBox()).count
        }

        #expect(count == 0)
    }

    @Test
    func `Notify calls each observer once with the outcome`() {
        let log = OutcomeLog()
        let outcome = NnRunOutcome.failed(message: "boom", exitCode: 1)

        withIsolatedState {
            NnCompletion.register(observer: { log.record("first: \($0)") })
            NnCompletion.register(observer: { log.record("second: \($0)") })

            NnCompletion.notify(outcome, in: currentBox())
        }

        #expect(log.entries == ["first: \(outcome)", "second: \(outcome)"])
    }
}


// MARK: - Unscoped Access
extension NnCompletionTests {
    #if compiler(>=6.2)
    @Test
    func `Registering an observer outside any scope traps`() async {
        await #expect(processExitsWith: .failure) {
            NnCompletion.register(observer: { _ in })
        }
    }
    #endif
}


// MARK: - SUT
private extension NnCompletionTests {
    func currentBox() -> NnStateBox {
        return NnStateScope.requiredBox(for: "NnCompletionTests")
    }
}


// MARK: - Test Doubles
private final class OutcomeLog: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    var entries: [String] {
        return lock.withLock { recorded }
    }

    func record(_ entry: String) {
        lock.withLock { recorded.append(entry) }
    }
}
