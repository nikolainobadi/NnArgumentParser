//
//  NnRootCommand+TestRun.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 2/17/26.
//

import Foundation
import NnArgumentParser

/// Gate for stdout capture - stdout is process-global so we serialize just this operation
private let stdoutGate = AsyncStdoutGate()

extension NnRootCommand {
    /// Runs the command in a test context and captures its standard output.
    ///
    /// Use this method in tests to execute commands and verify their printed output.
    /// The method captures everything written to stdout during command execution.
    ///
    /// - Parameters:
    ///   - contextFactory: The factory to inject for this test run, or `nil` to use the command's
    ///     ``defaultFactory``.
    ///   - args: The command-line arguments to pass.
    ///   - interactionMode: The mode to apply for the duration of the run, applied after parsing
    ///     so it takes precedence over any parsed interactivity flags. Pass `nil` to leave the
    ///     decision to the parsed arguments and the environment, which is what a test exercising
    ///     the flags wants.
    /// - Returns: The captured standard output as a trimmed string.
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
    /// - Note: Each run gets its own command scope, so the injected factory and mode never leak
    ///   into another test. Pass a non-interactive mode so a test that reaches a prompt fails
    ///   instead of blocking the suite on input that will never arrive.
    @discardableResult
    public static func testRun(
        contextFactory: Factory?,
        args: [String]?,
        interactionMode: InteractionMode?
    ) async throws -> String {
        return try await NnStateScope.withFreshBox {
            if let contextFactory { self.contextFactory = contextFactory }
            return try await captureOutput(args: args, interactionMode: interactionMode)
        }
    }
}

// MARK: - Private Methods
private extension NnRootCommand {
    static func captureOutput(args: [String]?, interactionMode: InteractionMode?) async throws -> String {
        await stdoutGate.acquire()
        defer { stdoutGate.release() }

        let pipe = Pipe()
        let readHandle = pipe.fileHandleForReading
        let writeHandle = pipe.fileHandleForWriting

        let originalStdout = dup(STDOUT_FILENO)
        dup2(writeHandle.fileDescriptor, STDOUT_FILENO)

        do {
            var command = try await parse(args: args)

            if let interactionMode {
                InteractionMode.register(interactionMode)
            }

            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
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

    static func parse(args: [String]?) async throws -> ParsableCommand {
        if let asyncRoot = Self.self as? any AsyncParsableCommand.Type {
            return try await asyncRoot.asyncParseAsRoot(args)
        }

        return try parseAsRoot(args)
    }
}

// MARK: - AsyncStdoutGate
/// A lock whose waiters suspend rather than block, so it can be held across `await`.
private final class AsyncStdoutGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        await withCheckedContinuation { continuation in
            lock.withLock {
                if isHeld {
                    waiters.append(continuation)
                } else {
                    isHeld = true
                    continuation.resume()
                }
            }
        }
    }

    func release() {
        lock.withLock {
            if waiters.isEmpty {
                isHeld = false
            } else {
                waiters.removeFirst().resume()
            }
        }
    }
}
