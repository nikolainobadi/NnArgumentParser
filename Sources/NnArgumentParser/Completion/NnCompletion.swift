//
//  NnCompletion.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/25/26.
//

/// Observers told how the command's run ended.
///
/// Register an observer — ending a log, recording telemetry, pointing the user at a log file — and
/// NnArgumentParser calls it with the run's ``NnRunOutcome`` once the command returns or throws.
public enum NnCompletion {
    /// Adds `observer` to this command scope's completion observers.
    ///
    /// Observers run in registration order, once, after the command returns or throws and before a
    /// failure is reported. A line an observer writes to stderr therefore comes just before the
    /// `Error:` line; stdout has no such guarantee, because piped stdout is flushed at exit.
    ///
    /// They don't run when the run was interrupted; register interrupt teardown with
    /// ``NnInterrupt/register(cleanup:)``.
    ///
    /// Under `testRun`, observers are told the run's outcome before it returns or rethrows.
    ///
    /// - Important: Registering outside a command scope traps, matching ``NnInterrupt/register(cleanup:)``.
    public static func register(observer: @escaping @Sendable (NnRunOutcome) -> Void) {
        NnStateScope.requiredBox(for: "NnCompletion.register(observer:)").append(observer, to: observersStorageKey)
    }
}

extension NnCompletion {
    /// The observers registered in `box`, in registration order.
    package static func observers(in box: NnStateBox) -> [@Sendable (NnRunOutcome) -> Void] {
        return box[observersStorageKey] as? [@Sendable (NnRunOutcome) -> Void] ?? []
    }

    /// Tells each observer registered in `box` about `outcome`, in registration order.
    package static func notify(_ outcome: NnRunOutcome, in box: NnStateBox) {
        for observer in observers(in: box) {
            observer(outcome)
        }
    }
}

// MARK: - Private Constants
private extension NnCompletion {
    static var observersStorageKey: String {
        return "NnArgumentParser.NnCompletion.observers"
    }
}
