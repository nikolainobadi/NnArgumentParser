//
//  NnTestRunResult.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/17/26.
//

/// What a command left behind after `testRunCapturingCleanups`: its output and its interrupt cleanups.
public struct NnTestRunResult: Sendable {
    /// The captured ``NnOutput/write(_:)`` output, trimmed, exactly as `testRun` returns it.
    public let output: String

    /// The cleanups the run registered with ``NnInterrupt/register(cleanup:)``, last registered first,
    /// which is the order production runs them in. None of them has been run.
    public let interruptCleanups: [@Sendable () -> Void]
}
