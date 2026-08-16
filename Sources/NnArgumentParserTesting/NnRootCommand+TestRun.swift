//
//  NnRootCommand+TestRun.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 2/17/26.
//

import Foundation
import NnArgumentParser

/// Lock for stdout capture - stdout is process-global so we serialize just this operation
private let stdoutLock = NSLock()

extension NnRootCommand {
    /// Runs the command in a test context and captures its standard output.
    ///
    /// Use this method in tests to execute commands and verify their printed output.
    /// The method captures everything written to stdout during command execution.
    ///
    /// - Parameters:
    ///   - contextFactory: An optional factory to inject for this test run.
    ///     If `nil`, uses the command's ``defaultFactory``.
    ///   - args: The command-line arguments to pass. Defaults to an empty array.
    ///   - interactionMode: The mode to apply for the duration of the run, applied after parsing
    ///     so it takes precedence over any parsed interactivity flags. Defaults to
    ///     ``InteractionMode/nonInteractive(assumeYes:)``. Pass `nil` to leave the decision to the
    ///     parsed arguments and the environment, which is what a test exercising the flags wants.
    /// - Returns: The captured standard output as a trimmed string.
    /// - Throws: Any error thrown by the command's `run()` method.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let output = try MyCommand.testRun(args: ["subcommand", "--flag"])
    /// XCTAssertEqual(output, "Expected output")
    /// ```
    ///
    /// - Note: The non-interactive default exists so a test that reaches a prompt fails instead of
    ///   blocking the suite on input that will never arrive. It only helps to the extent that the
    ///   command's factory consults ``InteractionMode/current`` when building its dependencies.
    @discardableResult
    public static func testRun(
        contextFactory: Factory? = nil,
        args: [String]? = [],
        interactionMode: InteractionMode? = .nonInteractive(assumeYes: false)
    ) throws -> String {
        defer { InteractionMode.reset() }

        if let contextFactory { self.contextFactory = contextFactory }
        return try captureOutput(args: args, interactionMode: interactionMode)
    }
}

// MARK: - Private Methods
private extension NnRootCommand {
    static func captureOutput(args: [String]?, interactionMode: InteractionMode?) throws -> String {
        stdoutLock.lock()
        defer { stdoutLock.unlock() }

        let pipe = Pipe()
        let readHandle = pipe.fileHandleForReading
        let writeHandle = pipe.fileHandleForWriting

        let originalStdout = dup(STDOUT_FILENO)
        dup2(writeHandle.fileDescriptor, STDOUT_FILENO)

        do {
            var command = try Self.parseAsRoot(args)

            if let interactionMode {
                InteractionMode.register(interactionMode)
            }

            try command.run()
        } catch {
            fflush(stdout)
            dup2(originalStdout, STDOUT_FILENO)
            close(originalStdout)
            writeHandle.closeFile()
            readHandle.closeFile()
            throw error
        }

        fflush(stdout)
        dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)
        writeHandle.closeFile()

        let data = readHandle.readDataToEndOfFile()
        readHandle.closeFile()

        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
