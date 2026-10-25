//
//  NnRootCommand+TestRun.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 2/17/26.
//

import Foundation
import NnArgumentParser

extension NnRootCommand {
    /// Runs the command in a test context and captures its output.
    ///
    /// Use this method in tests to execute commands and verify their output. The method captures
    /// everything the command writes through ``NnOutput/write(_:)`` during the run; plain `print`
    /// calls go to stdout and are not captured. A writer registered with
    /// ``NnOutput/register(writer:)`` is ignored while the run captures output.
    ///
    /// - Parameters:
    ///   - contextFactory: The factory to inject for this test run, or `nil` to use the command's
    ///     ``defaultFactory``.
    ///   - args: The command-line arguments to pass.
    ///   - interactionMode: The mode to apply for the duration of the run, applied after parsing
    ///     so it takes precedence over any parsed interactivity flags. Pass `nil` to leave the
    ///     decision to the parsed arguments and the environment, which is what a test exercising
    ///     the flags wants.
    /// - Returns: The captured output as a trimmed string.
    /// - Throws: Any error thrown by the command's `run()` method.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let output = try await MyCommand.testRun(
    ///     contextFactory: MockFactory(),
    ///     args: ["subcommand", "--flag"],
    ///     interactionMode: .nonInteractive(assumeYes: false)
    /// )
    /// #expect(output == "Expected output")
    /// ```
    ///
    /// - Note: Each run gets its own command scope and output buffer, so the injected factory,
    ///   mode, and output never leak into another test, and runs can execute in parallel. Pass a
    ///   non-interactive mode so a test that reaches a prompt fails instead of blocking the suite
    ///   on input that will never arrive.
    ///
    /// - Note: A run installs no interrupt handling and never touches the process's signal handlers.
    ///   Cleanups the command registers with ``NnInterrupt/register(cleanup:)`` are kept with the run
    ///   and discarded with it, never run. To test them, use
    ///   ``testRunCapturingCleanups(contextFactory:args:interactionMode:)``.
    ///
    /// - Note: Observers registered with ``NnCompletion/register(observer:)`` are told the run's
    ///   outcome, including a parse failure, before this returns or rethrows. What they write
    ///   through ``NnOutput/write(_:)`` is in the returned output only when the run succeeds.
    @discardableResult
    public static func testRun(
        contextFactory: Factory?,
        args: [String]?,
        interactionMode: InteractionMode?
    ) async throws -> String {
        return try await runInFreshScope(contextFactory: contextFactory, args: args, interactionMode: interactionMode).output
    }

    /// Runs the command like ``testRun(contextFactory:args:interactionMode:)``, and also returns the
    /// interrupt cleanups it registered.
    ///
    /// No interrupt is simulated and no cleanup is run. The test decides when to run them, then
    /// asserts on the outcome in its fakes. Completion observers are notified as under `testRun`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let result = try await MyCommand.testRunCapturingCleanups(
    ///     contextFactory: factory,
    ///     args: ["watch"],
    ///     interactionMode: .nonInteractive(assumeYes: false)
    /// )
    ///
    /// result.interruptCleanups.forEach { $0() }
    /// #expect(factory.terminal.wasRestored)
    /// ```
    ///
    /// - Returns: The captured output and the registered cleanups, last registered first.
    /// - Throws: Any error thrown by the command's `run()` method.
    public static func testRunCapturingCleanups(
        contextFactory: Factory?,
        args: [String]?,
        interactionMode: InteractionMode?
    ) async throws -> NnTestRunResult {
        let run = try await runInFreshScope(contextFactory: contextFactory, args: args, interactionMode: interactionMode)

        return .init(output: run.output, interruptCleanups: NnInterrupt.cleanups(in: run.box))
    }
}

// MARK: - Private Methods
private extension NnRootCommand {
    /// Parses and runs the command in its own scope, returning its output and the scope's state.
    static func runInFreshScope(
        contextFactory: Factory?,
        args: [String]?,
        interactionMode: InteractionMode?
    ) async throws -> (output: String, box: NnStateBox) {
        return try await NnStateScope.withFreshBox {
            let buffer = NnOutputBuffer()
            let box = NnStateScope.requiredBox(for: "testRun")
            box[NnOutputBuffer.storageKey] = buffer

            if let contextFactory { self.contextFactory = contextFactory }

            do {
                var command = try await asyncParseAsRoot(args)

                if let interactionMode {
                    InteractionMode.register(interactionMode)
                }

                if var asyncCommand = command as? AsyncParsableCommand {
                    try await asyncCommand.run()
                } else {
                    try command.run()
                }
            } catch {
                NnCompletion.notify(runOutcome(for: .failure(error)), in: box)
                throw error
            }

            NnCompletion.notify(runOutcome(for: .success(())), in: box)

            return (buffer.contents.trimmingCharacters(in: .whitespacesAndNewlines), box)
        }
    }
}
