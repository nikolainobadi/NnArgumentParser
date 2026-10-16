//
//  WithIsolatedState.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import NnArgumentParser

/// Runs `body` in its own command scope, for tests that register a mode or read state without `testRun`.
public func withIsolatedState<T>(_ body: () throws -> T) rethrows -> T {
    return try NnStateScope.withFreshBox(body)
}

/// Runs `body` in its own command scope, for tests that register a mode or read state without `testRun`.
public func withIsolatedState<T>(_ body: () async throws -> T) async rethrows -> T {
    return try await NnStateScope.withFreshBox(body)
}

extension NnRootCommand {
    /// Runs `body` in its own command scope with `contextFactory` injected.
    public static func withIsolatedState<T>(contextFactory: Factory, _ body: () throws -> T) rethrows -> T {
        return try NnStateScope.withFreshBox {
            self.contextFactory = contextFactory
            return try body()
        }
    }

    /// Runs `body` in its own command scope with `contextFactory` injected.
    public static func withIsolatedState<T>(contextFactory: Factory, _ body: () async throws -> T) async rethrows -> T {
        return try await NnStateScope.withFreshBox {
            self.contextFactory = contextFactory
            return try await body()
        }
    }
}
