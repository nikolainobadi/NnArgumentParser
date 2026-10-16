//
//  TestRunOutputTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Testing
import NnArgumentParser
import NnArgumentParserTesting

struct TestRunOutputTests {
    @Test
    func `A run captures what its command writes`() async throws {
        let output = try await EchoRoot.testRun(contextFactory: "hello", args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(output == "hello")
    }

    @Test
    func `Parallel runs capture only their own output`() async throws {
        async let first = EchoRoot.testRun(contextFactory: "first", args: [], interactionMode: .nonInteractive(assumeYes: false))
        async let second = EchoRoot.testRun(contextFactory: "second", args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(try await first == "first")
        #expect(try await second == "second")
    }

    @Test
    func `A synchronous subcommand runs under an asynchronous root`() async throws {
        let output = try await EchoRoot.testRun(contextFactory: "from sync", args: ["sync"], interactionMode: .nonInteractive(assumeYes: false))

        #expect(output == "sync: from sync")
    }
}


// MARK: - Test Doubles
private struct EchoRoot: NnRootCommand {
    static let configuration = CommandConfiguration(subcommands: [SyncSubcommand.self])
    static var defaultFactory: String { "default" }

    func run() async throws {
        try await Task.sleep(for: .milliseconds(5))
        NnOutput.write(Self.contextFactory)
    }
}

private struct SyncSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync")

    func run() throws {
        NnOutput.write("sync: \(EchoRoot.contextFactory)")
    }
}
