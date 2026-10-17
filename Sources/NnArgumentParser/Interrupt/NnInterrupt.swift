//
//  NnInterrupt.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

/// Cleanup steps to run when the command is interrupted by SIGINT or SIGTERM.
///
/// Register the app's own teardown — restoring the terminal, stopping child processes — and
/// NnArgumentParser runs it on interrupt without knowing what it does.
public enum NnInterrupt {
    /// Adds `cleanup` to this command scope's interrupt cleanups.
    ///
    /// Cleanups run in reverse registration order, like `defer`, so register a step before the
    /// steps that depend on it.
    ///
    /// Under `testRun`, nothing handles interrupts: the cleanup is kept with the run and discarded
    /// with it, never run. Use `testRunCapturingCleanups` to get a run's cleanups back and run them.
    ///
    /// - Important: Registering outside a command scope traps, matching ``NnOutput/register(writer:)``.
    public static func register(cleanup: @escaping @Sendable () -> Void) {
        NnStateScope.requiredBox(for: "NnInterrupt.register(cleanup:)").append(cleanup, to: cleanupsStorageKey)
    }
}

extension NnInterrupt {
    /// The cleanups registered in `box`, in run order: last registered first.
    ///
    /// Takes the box rather than reading the scope, because signal handling runs outside any task.
    package static func cleanups(in box: NnStateBox) -> [@Sendable () -> Void] {
        let registered = box[cleanupsStorageKey] as? [@Sendable () -> Void] ?? []

        return registered.reversed()
    }
}

// MARK: - Private Constants
private extension NnInterrupt {
    static var cleanupsStorageKey: String {
        return "NnArgumentParser.NnInterrupt.cleanups"
    }
}
