//
//  NnStateScope.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Foundation

/// The state a single command run carries: its injected factory and its registered interaction mode.
///
/// A box lives exactly as long as the scope that installed it, so ending a run discards its state —
/// there is nothing to reset.
package final class NnStateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any] = [:]

    package init() { }

    package subscript(key: String) -> Any? {
        get { lock.withLock { values[key] } }
        set { lock.withLock { values[key] = newValue } }
    }
}

/// Binds an ``NnStateBox`` to the current task.
///
/// Task-locals follow a task across thread hops and are inherited by task-group children and
/// `Task { }`, so state registered while parsing is still visible after any `await` in `run()`.
/// There is deliberately no process-wide fallback: a root command's `main()` installs the scope in
/// production, and `testRun` installs one per test run.
package enum NnStateScope {
    @TaskLocal package static var box: NnStateBox?

    /// Returns the current box, trapping when no scope is installed.
    ///
    /// A missing scope means state would silently fall back to production defaults — a test running
    /// real dependencies, or a registered mode lost — so the failure is made loud instead.
    package static func requiredBox(for operation: String) -> NnStateBox {
        guard let box else {
            preconditionFailure("\(operation) outside a command scope. Run commands through their root command's main(), run tests through testRun, and don't read command state from Task.detached.")
        }

        return box
    }

    /// Runs `body` inside a fresh, empty scope.
    package static func withFreshBox<T>(_ body: () throws -> T) rethrows -> T {
        return try $box.withValue(NnStateBox(), operation: body)
    }
}
