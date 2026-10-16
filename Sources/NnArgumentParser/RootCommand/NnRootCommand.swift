//
//  NnRootCommand.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 2/17/26.
//

import Foundation
import ArgumentParser

/// A protocol for root commands that support dependency injection via a context factory.
///
/// Conforming types provide a `Factory` type that creates dependencies needed by subcommands.
/// The factory is stored in the current command scope, enabling test-time injection without
/// global mutable state. The root command's `main()` installs that scope in production, and
/// `testRun` installs a fresh one per test run.
///
/// ## Example
///
/// ```swift
/// struct MyCommand: NnRootCommand {
///     typealias Factory = MyFactory
///     static var defaultFactory: Factory { MyFactory() }
/// }
/// ```
public protocol NnRootCommand: AsyncParsableCommand {
    /// The type responsible for creating dependencies used by this command and its subcommands.
    associatedtype Factory

    /// The default factory instance used when no test factory is injected.
    static var defaultFactory: Factory { get }
}

// MARK: - Helpers
extension NnRootCommand {
    /// The factory injected into the current command scope, or ``defaultFactory`` when none was.
    ///
    /// Production injects nothing; `testRun` injects its factory into that run's own scope. The
    /// scope follows the command across `await`s and into task-group children and `Task { }`.
    ///
    /// - Important: Reading this outside a command scope, including from `Task.detached`, traps
    ///   rather than silently falling back to ``defaultFactory``.
    public package(set) static var contextFactory: Factory {
        get {
            return NnStateScope.requiredBox(for: "contextFactory read")[contextFactoryKey] as? Factory ?? defaultFactory
        }
        set {
            NnStateScope.requiredBox(for: "contextFactory set")[contextFactoryKey] = newValue
        }
    }
}

// MARK: - Entry Points
extension NnRootCommand {
    /// Runs the root command inside a fresh command scope.
    ///
    /// `@main` selects this over ArgumentParser's own `main()`, so the scope that holds the
    /// factory and interaction mode exists before parsing begins and survives every `await`.
    public static func main() async {
        await NnStateScope.$box.withValue(NnStateBox()) {
            await Self.main(nil)
        }
    }
}

// MARK: - Private Helpers
private extension NnRootCommand {
    static var contextFactoryKey: String {
        return "\(Self.self).contextFactory"
    }
}
