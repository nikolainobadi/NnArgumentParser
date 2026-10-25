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
    /// Runs the root command inside a fresh command scope, with interrupt handling installed.
    ///
    /// `@main` selects this over ArgumentParser's own `main()`, so the scope that holds the
    /// factory and interaction mode exists before parsing begins and survives every `await`.
    ///
    /// It parses and runs the command the way ArgumentParser's `main` does. Once SIGINT or SIGTERM
    /// has arrived, though, it neither prints the command's error nor exits; the interrupt's
    /// cleanups end the process instead. See ``NnInterrupt``.
    ///
    /// Without an interrupt, observers registered with ``NnCompletion/register(observer:)`` are
    /// told the run's outcome before a failure is reported.
    public static func main() async {
        await main(arguments: nil)
    }
}

extension NnRootCommand {
    /// ``main()`` with explicit arguments, so tests can drive it in an exit test.
    ///
    /// - Parameter arguments: The arguments to parse, or `nil` for the process's own.
    static func main(arguments: [String]?) async {
        let box = NnStateBox()

        await NnStateScope.$box.withValue(box) {
            let coordinator = NnInterruptCoordinator(
                box: box,
                isInterrupting: { NnInterruptSignal.received != 0 },
                terminate: { NnInterruptSignal.reraise($0) },
                writeError: { fputs($0, stderr) }
            )
            let installation = coordinator.install()
            let outcome = await parseAndRun(arguments: arguments)

            switch NnRunCompletion(outcome: outcome, isInterrupting: coordinator.isInterrupting) {
            case .finish:
                NnCompletion.notify(runOutcome(for: outcome), in: box)
            case .exit(let error):
                NnCompletion.notify(runOutcome(for: outcome), in: box)
                Self.exit(withError: error)
            case .park:
                await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in }
            }

            withExtendedLifetime(installation) { }
        }
    }
}

// MARK: - Private Helpers
private extension NnRootCommand {
    static var contextFactoryKey: String {
        return "\(Self.self).contextFactory"
    }

    /// Parses and runs the command as ArgumentParser's `main` does, returning the outcome instead
    /// of exiting on error.
    static func parseAndRun(arguments: [String]?) async -> Result<Void, any Error> {
        do {
            var command = try await asyncParseAsRoot(arguments)

            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }

            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
