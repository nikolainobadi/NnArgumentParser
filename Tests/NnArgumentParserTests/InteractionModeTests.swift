//
//  InteractionModeTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 8/9/26.
//

import Testing
@testable import NnArgumentParser

struct InteractionModeTests {
    @Test
    func `Prompting is allowed at a terminal when nothing overrides it`() {
        #expect(makeSUT() == .interactive(assumeYes: false))
    }
}


// MARK: - Explicit Flag
extension InteractionModeTests {
    @Test
    func `An explicit request to disable prompting wins over an available terminal`() {
        #expect(makeSUT(nonInteractive: true) == .nonInteractive(assumeYes: false))
    }

    @Test
    func `Assumed confirmations are carried through when prompting is disabled`() {
        #expect(makeSUT(nonInteractive: true, assumeYes: true) == .nonInteractive(assumeYes: true))
    }
}


// MARK: - Environment
extension InteractionModeTests {
    @Test(arguments: ["1", "true", "0", "false", "anything"])
    func `Any non-empty prompt-suppressing variable disables prompting`(value: String) {
        #expect(makeSUT(noPromptValue: value) == .nonInteractive(assumeYes: false))
    }

    @Test
    func `An empty prompt-suppressing variable leaves prompting enabled`() {
        #expect(makeSUT(noPromptValue: "") == .interactive(assumeYes: false))
    }

    @Test
    func `Unrelated environment variables leave prompting enabled`() {
        #expect(makeSUT(otherEnvironment: ["EDITOR": "vim"]) == .interactive(assumeYes: false))
    }
}


// MARK: - Terminal Detection
extension InteractionModeTests {
    @Test
    func `Prompting is disabled when standard input is not a terminal`() {
        #expect(makeSUT(isTerminal: false) == .nonInteractive(assumeYes: false))
    }

    @Test
    func `Assumed confirmations survive detection of a missing terminal`() {
        #expect(makeSUT(assumeYes: true, isTerminal: false) == .nonInteractive(assumeYes: true))
    }
}


// MARK: - Mode Reporting
extension InteractionModeTests {
    @Test
    func `A mode allowing prompts reports itself as interactive`() {
        #expect(makeSUT().isInteractive)
    }

    @Test
    func `A mode disabling prompts reports itself as non-interactive`() {
        #expect(!makeSUT(nonInteractive: true).isInteractive)
    }

    @Test
    func `A mode disabling prompts reports its assumed-confirmation setting`() {
        #expect(makeSUT(nonInteractive: true, assumeYes: true).assumeYes)
    }

    @Test
    func `A mode allowing prompts still reports requested assumed confirmations`() {
        #expect(makeSUT(assumeYes: true).assumeYes)
    }

    @Test
    func `Requesting assumed confirmations at a terminal leaves other prompting enabled`() {
        #expect(makeSUT(assumeYes: true).isInteractive)
    }
}


// MARK: - Storage
extension InteractionModeTests {
    @Test
    func `A registered mode is returned by subsequent reads`() {
        defer { InteractionMode.reset() }
        let mode = makeSUT(nonInteractive: true, assumeYes: true)

        InteractionMode.register(mode)

        #expect(InteractionMode.current == mode)
    }

    @Test
    func `Clearing a registered mode restores the resolved default`() {
        InteractionMode.register(makeSUT(nonInteractive: true))

        InteractionMode.reset()

        #expect(InteractionMode.current == InteractionMode.resolve())
    }

    @Test
    func `An unregistered mode falls back to environment and terminal resolution`() {
        #expect(InteractionMode.current == InteractionMode.resolve())
    }

    @Test
    func `Registering from parsed flag values resolves before storing`() {
        defer { InteractionMode.reset() }

        InteractionMode.register(nonInteractive: true, assumeYes: true)

        #expect(InteractionMode.current == .nonInteractive(assumeYes: true))
    }
}


// MARK: - SUT
private extension InteractionModeTests {
    func makeSUT(
        nonInteractive: Bool = false,
        assumeYes: Bool = false,
        noPromptValue: String? = nil,
        otherEnvironment: [String: String] = [:],
        isTerminal: Bool = true
    ) -> InteractionMode {
        var environment = otherEnvironment

        if let noPromptValue {
            environment[InteractionMode.noPromptEnvironmentKey] = noPromptValue
        }

        return InteractionMode.resolve(
            nonInteractive: nonInteractive,
            assumeYes: assumeYes,
            environment: environment,
            isTerminal: isTerminal
        )
    }
}
