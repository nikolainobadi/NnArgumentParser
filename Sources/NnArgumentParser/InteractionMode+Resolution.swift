//
//  InteractionMode+Resolution.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 8/9/26.
//

import Foundation

// MARK: - Resolution
public extension InteractionMode {
    /// The environment variable that suppresses prompting when set to any non-empty value.
    ///
    /// Follows the `NO_COLOR` convention: presence is what matters, not the value. `NO_PROMPT=0`
    /// therefore suppresses prompting just as `NO_PROMPT=1` does. Unset the variable to re-enable it.
    static var noPromptEnvironmentKey: String {
        return "NO_PROMPT"
    }

    /// Determines the interaction mode from an explicit flag, the environment, and the terminal.
    ///
    /// Prompting is suppressed when *any* of the following holds:
    /// 1. `nonInteractive` is `true` (the caller passed `--non-interactive`)
    /// 2. ``noPromptEnvironmentKey`` is set to a non-empty value
    /// 3. Standard input is not a terminal — a pipe, a redirect, or a scheduled job
    ///
    /// Condition 3 is what makes this safe by default. When stdin isn't a terminal there is no one
    /// to answer a prompt, so a command that prompts would hang or consume its own input. Detecting
    /// that can't break a working invocation, because there wasn't one.
    ///
    /// - Parameters:
    ///   - nonInteractive: Whether prompting was explicitly disabled by a flag.
    ///   - assumeYes: Whether confirmation prompts should be treated as approved.
    ///   - environment: The environment to inspect. Defaults to the current process environment.
    ///   - isTerminal: Whether standard input is a terminal. Defaults to a live `isatty` check.
    /// - Returns: The resolved mode.
    ///
    /// - Note: `environment` and `isTerminal` are injectable so the resolution rules can be tested
    ///   without mutating the process environment or attaching a pseudo-terminal.
    static func resolve(
        nonInteractive: Bool = false,
        assumeYes: Bool = false,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isTerminal: Bool = isatty(STDIN_FILENO) == 1
    ) -> InteractionMode {
        let noPromptIsSet = environment[noPromptEnvironmentKey].map({ !$0.isEmpty }) ?? false
        let shouldSuppressPrompts = nonInteractive || noPromptIsSet || !isTerminal

        return shouldSuppressPrompts ? .nonInteractive(assumeYes: assumeYes) : .interactive(assumeYes: assumeYes)
    }

    /// Resolves the mode from parsed flag values and registers it for the current thread.
    ///
    /// This is the bridge between argument parsing and ``current``. Parsed flags are only one of
    /// the inputs — the environment and terminal checks still apply when the flag is absent.
    ///
    /// - Parameters:
    ///   - nonInteractive: Whether prompting was explicitly disabled by a flag.
    ///   - assumeYes: Whether confirmation prompts should be treated as approved.
    static func register(nonInteractive: Bool, assumeYes: Bool) {
        register(resolve(nonInteractive: nonInteractive, assumeYes: assumeYes))
    }
}
