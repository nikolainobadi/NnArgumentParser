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
    @discardableResult
    public static func testRun(contextFactory: Factory? = nil, args: [String]? = []) throws -> String {
        if let contextFactory { self.contextFactory = contextFactory }
        return try captureOutput(args: args)
    }
}

private extension NnRootCommand {
    static func captureOutput(args: [String]?) throws -> String {
        stdoutLock.lock()
        defer { stdoutLock.unlock() }

        let pipe = Pipe()
        let readHandle = pipe.fileHandleForReading
        let writeHandle = pipe.fileHandleForWriting

        let originalStdout = dup(STDOUT_FILENO)
        dup2(writeHandle.fileDescriptor, STDOUT_FILENO)

        do {
            var command = try Self.parseAsRoot(args)
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
