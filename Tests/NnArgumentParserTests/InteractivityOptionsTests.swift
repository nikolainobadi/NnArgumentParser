//
//  InteractivityOptionsTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 8/9/26.
//

import Testing
@testable import NnArgumentParser

struct InteractivityOptionsTests {
    @Test
    func `Disabling prompts on a subcommand takes effect without the root command running`() throws {
        defer { InteractionMode.reset() }

        #expect(try makeSUT(args: ["prompting", "--non-interactive"]) == .nonInteractive(assumeYes: false))
    }
}


// MARK: - Flag Mapping
extension InteractivityOptionsTests {
    @Test
    func `Requesting assumed confirmations alongside disabled prompts is registered`() throws {
        defer { InteractionMode.reset() }

        #expect(try makeSUT(args: ["prompting", "--non-interactive", "--yes"]) == .nonInteractive(assumeYes: true))
    }

    @Test
    func `Omitting both flags leaves the decision to the environment and terminal`() throws {
        defer { InteractionMode.reset() }

        #expect(try makeSUT(args: ["prompting"]) == InteractionMode.resolve())
    }
}


// MARK: - Adoption
extension InteractivityOptionsTests {
    @Test
    func `A command that never adopts the flags still resolves from the environment and terminal`() throws {
        defer { InteractionMode.reset() }

        #expect(try makeSUT(args: ["plain"]) == InteractionMode.resolve())
    }

    @Test
    func `The flags are rejected by a command that never adopts them`() {
        #expect(throws: (any Error).self) {
            try makeSUT(args: ["plain", "--non-interactive"])
        }
    }
}


// MARK: - SUT
private extension InteractivityOptionsTests {
    func makeSUT(args: [String]) throws -> InteractionMode {
        InteractionMode.reset()
        _ = try TestRoot.parseAsRoot(args)

        return InteractionMode.current
    }

    struct TestRoot: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "test",
            subcommands: [PromptingSubcommand.self, PlainSubcommand.self]
        )
    }

    struct PromptingSubcommand: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "prompting")

        @OptionGroup var interactivity: InteractivityOptions
    }

    struct PlainSubcommand: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "plain")
    }
}
