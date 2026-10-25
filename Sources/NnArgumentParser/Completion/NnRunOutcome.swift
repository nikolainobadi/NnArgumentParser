//
//  NnRunOutcome.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/25/26.
//

/// How a command's run ended, as told to observers registered with ``NnCompletion/register(observer:)``.
public enum NnRunOutcome: Sendable, Equatable {
    /// The command returned, or exited cleanly (`CleanExit`, `ExitCode.success`).
    case succeeded

    /// The command threw. `message` is ArgumentParser's `message(for:)`: the error's text, without
    /// the `Error: ` prefix or usage that the printed report adds. `exitCode` is `exitCode(for:)`.
    case failed(message: String, exitCode: Int32)
}
