//
//  InteractionMode+Storage.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 8/9/26.
//

import Foundation

// MARK: - Storage
public extension InteractionMode {
    /// The interaction mode for the current command scope.
    ///
    /// Read this wherever a picker or prompt-driven dependency is constructed — typically a
    /// command's factory — so the decision doesn't have to be threaded through initializers.
    ///
    /// When nothing has been registered, or no command scope is installed, falls back to
    /// ``resolve(nonInteractive:assumeYes:environment:isTerminal:)`` so the environment and terminal
    /// checks still apply. A command that never adopts the `--non-interactive` flag is therefore
    /// still safe when piped or run from a scheduled job.
    ///
    /// - Note: Stored in the command scope alongside ``NnRootCommand/contextFactory``. The scope
    ///   follows the command across `await`s, and each test run gets its own, so parallel tests
    ///   don't interfere with one another.
    static var current: InteractionMode {
        return NnStateScope.box?[storageKey] as? InteractionMode ?? resolve()
    }

    /// Records the interaction mode for the current command scope.
    ///
    /// Registration is deliberate rather than a settable property: the mode is decided once,
    /// when arguments are parsed, and read many times afterward. The registration ends with the
    /// scope, so there is nothing to reset.
    ///
    /// - Parameter mode: The mode to apply to subsequent ``current`` reads in this scope.
    ///
    /// - Important: Registering outside a command scope traps, because the mode would otherwise be
    ///   silently lost.
    static func register(_ mode: InteractionMode) {
        NnStateScope.requiredBox(for: "InteractionMode.register")[storageKey] = mode
    }
}


// MARK: - Private Constants
private extension InteractionMode {
    static var storageKey: String {
        return "NnArgumentParser.InteractionMode.current"
    }
}
