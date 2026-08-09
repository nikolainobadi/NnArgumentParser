//
//  InteractionMode+Storage.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 8/9/26.
//

import Foundation

// MARK: - Storage
public extension InteractionMode {
    /// The interaction mode for the current thread.
    ///
    /// Read this wherever a picker or prompt-driven dependency is constructed — typically a
    /// command's factory — so the decision doesn't have to be threaded through initializers.
    ///
    /// When nothing has been registered, falls back to ``resolve(nonInteractive:assumeYes:environment:isTerminal:)``
    /// so the environment and terminal checks still apply. A command that never adopts the
    /// `--non-interactive` flag is therefore still safe when piped or run from a scheduled job.
    ///
    /// - Note: Backed by thread-local storage, matching ``NnRootCommand/contextFactory``.
    ///   Each thread carries its own value, so parallel tests don't interfere with one another.
    static var current: InteractionMode {
        return Thread.current.threadDictionary[storageKey] as? InteractionMode ?? resolve()
    }

    /// Records the interaction mode for the current thread.
    ///
    /// Registration is deliberate rather than a settable property: the mode is decided once,
    /// when arguments are parsed, and read many times afterward.
    ///
    /// - Parameter mode: The mode to apply to subsequent ``current`` reads on this thread.
    static func register(_ mode: InteractionMode) {
        Thread.current.threadDictionary[storageKey] = mode
    }

    /// Clears any registered mode for the current thread, restoring the default.
    ///
    /// Thread dictionaries outlive a single command run, so tests that register a mode should
    /// clear it afterward to avoid leaking state into whatever runs next on the same thread.
    static func reset() {
        Thread.current.threadDictionary.removeObject(forKey: storageKey)
    }
}

// MARK: - Private Constants
private extension InteractionMode {
    static var storageKey: String {
        return "NnArgumentParser.InteractionMode.current"
    }
}
