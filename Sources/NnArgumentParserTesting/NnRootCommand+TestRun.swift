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
    ///   and discarded with it, never run.
    @discardableResult
    public static func testRun(
        contextFactory: Factory?,
        args: [String]?,
        interactionMode: InteractionMode?
    ) async throws -> String {
        return try await NnStateScope.withFreshBox {
            let buffer = NnOutputBuffer()
            NnStateScope.requiredBox(for: "testRun")[NnOutputBuffer.storageKey] = buffer

            if let contextFactory { self.contextFactory = contextFactory }

            var command = try await asyncParseAsRoot(args)

            if let interactionMode {
                InteractionMode.register(interactionMode)
            }

            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }

            return buffer.contents.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
