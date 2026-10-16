//
//  TestRunInteractionModeTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 8/9/26.
//

import Testing
import NnArgumentParser
import NnArgumentParserTesting

struct TestRunInteractionModeTests {
    @Test
    func `A command under test cannot prompt unless the test says otherwise`() async throws {
        #expect(try await makeSUT() == "nonInteractive(assumeYes: false)")
    }
}


// MARK: - Overrides
extension TestRunInteractionModeTests {
    @Test
    func `A test may opt its command back into prompting`() async throws {
        #expect(try await makeSUT(interactionMode: .interactive(assumeYes: false)) == "interactive(assumeYes: false)")
    }

    @Test
    func `A test may grant assumed confirmations to its command`() async throws {
        #expect(try await makeSUT(interactionMode: .nonInteractive(assumeYes: true)) == "nonInteractive(assumeYes: true)")
    }

    @Test
    func `The mode chosen by a test outranks the flags passed to the command`() async throws {
        #expect(try await makeSUT(args: ["--non-interactive", "--yes"]) == "nonInteractive(assumeYes: false)")
    }
}


// MARK: - Deferring To Arguments
extension TestRunInteractionModeTests {
    @Test
    func `Declining to choose a mode lets the command's own flags decide`() async throws {
        #expect(try await makeSUT(args: ["--non-interactive", "--yes"], interactionMode: nil) == "nonInteractive(assumeYes: true)")
    }
}


// MARK: - Isolation
extension TestRunInteractionModeTests {
    @Test
    func `A finished run leaves no mode behind for whatever runs next`() async throws {
        _ = try await makeSUT(interactionMode: .interactive(assumeYes: false))

        #expect(InteractionMode.current == InteractionMode.resolve())
    }
}


// MARK: - SUT
private extension TestRunInteractionModeTests {
    func makeSUT(
        args: [String] = [],
        interactionMode: InteractionMode? = .nonInteractive(assumeYes: false)
    ) async throws -> String {
        return try await ModeReportingCommand.testRun(contextFactory: nil, args: args, interactionMode: interactionMode)
    }

    struct ModeReportingCommand: NnRootCommand {
        typealias Factory = String

        static var defaultFactory: String { "factory" }

        @OptionGroup var interactivity: InteractivityOptions

        func run() throws {
            print("\(InteractionMode.current)")
        }
    }
}
