//
//  NnOutputWriterTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Testing
import Foundation
import NnArgumentParser
import NnArgumentParserTesting

struct NnOutputWriterTests {
    @Test
    func `Output written in a scope reaches its registered writer in order`() {
        let writer = RecordingOutputWriter()

        withIsolatedState {
            NnOutput.register(writer: writer)
            NnOutput.write("first")
            NnOutput.write("second")
        }

        #expect(writer.lines == ["first", "second"])
    }

    @Test
    func `The writer receives the text exactly as written, without a trailing newline`() {
        let writer = RecordingOutputWriter()

        withIsolatedState {
            NnOutput.register(writer: writer)
            NnOutput.write("  spaced text  ")
        }

        #expect(writer.lines == ["  spaced text  "])
    }
}


// MARK: - Test Capture
extension NnOutputWriterTests {
    @Test
    func `A test run captures output even when the command registers a writer`() async throws {
        let writer = RecordingOutputWriter()

        let output = try await WriterRegisteringRoot.testRun(contextFactory: writer, args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(output == "captured")
        #expect(writer.lines.isEmpty)
    }
}


// MARK: - Concurrency
extension NnOutputWriterTests {
    @Test
    func `Each concurrent write from a task group reaches the writer exactly once`() async {
        let writer = RecordingOutputWriter()
        let expected = (0..<50).map { "line \($0)" }

        await withIsolatedState {
            NnOutput.register(writer: writer)

            await withTaskGroup(of: Void.self) { group in
                for line in expected {
                    group.addTask { NnOutput.write(line) }
                }
            }
        }

        #expect(writer.lines.sorted() == expected.sorted())
    }

    @Test
    func `Output written after a suspension point still reaches the writer`() async throws {
        let writer = RecordingOutputWriter()

        try await withIsolatedState {
            NnOutput.register(writer: writer)
            try await Task.sleep(for: .milliseconds(5))
            NnOutput.write("after await")
        }

        #expect(writer.lines == ["after await"])
    }

    @Test
    func `Concurrent scopes write only to their own writer`() async throws {
        let firstWriter = RecordingOutputWriter()
        let secondWriter = RecordingOutputWriter()

        async let first: Void = registerThenWrite(writer: firstWriter, text: "first")
        async let second: Void = registerThenWrite(writer: secondWriter, text: "second")
        _ = try await (first, second)

        #expect(firstWriter.lines == ["first"])
        #expect(secondWriter.lines == ["second"])
    }
}


// MARK: - Unscoped Access
extension NnOutputWriterTests {
    #if compiler(>=6.2)
    @Test
    func `Registering a writer outside any scope traps`() async {
        await #expect(processExitsWith: .failure) {
            NnOutput.register(writer: RecordingOutputWriter())
        }
    }
    #endif
}


// MARK: - SUT
private extension NnOutputWriterTests {
    func registerThenWrite(writer: RecordingOutputWriter, text: String) async throws {
        try await withIsolatedState {
            NnOutput.register(writer: writer)
            try await Task.sleep(for: .milliseconds(5))
            NnOutput.write(text)
        }
    }
}


// MARK: - Test Doubles
private final class RecordingOutputWriter: NnOutputWriter, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    var lines: [String] {
        return lock.withLock { recorded }
    }

    func write(_ text: String) {
        lock.withLock { recorded.append(text) }
    }
}

private struct WriterRegisteringRoot: NnRootCommand {
    static var defaultFactory: RecordingOutputWriter { RecordingOutputWriter() }

    func run() throws {
        NnOutput.register(writer: Self.contextFactory)
        NnOutput.write("captured")
    }
}
