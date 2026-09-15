//
//  KeyValueArgumentTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 9/6/26.
//

import Testing
@testable import NnArgumentParser

/// Covers the pair as the parser sees it. The separator rules are the whole contract here — a value
/// is often a shell command that carries its own `=`, so where the split happens decides whether a
/// caller's command survives intact.
struct KeyValueArgumentTests {
    @Test
    func `A key and value separated by equals parses into both halves`() throws {
        let sut = try #require(KeyValueArgument(argument: "Kit=swift build"))

        #expect(sut.key == "Kit")
        #expect(sut.value == "swift build")
    }
}

// MARK: - Separators
extension KeyValueArgumentTests {
    @Test
    func `A value carrying its own equals sign is kept whole`() throws {
        let sut = try #require(KeyValueArgument(argument: "Kit=swift test --filter=TargetOptionsTests"))

        #expect(sut.key == "Kit")
        #expect(sut.value == "swift test --filter=TargetOptionsTests")
    }

    @Test
    func `Surrounding whitespace is left as the caller wrote it`() throws {
        let sut = try #require(KeyValueArgument(argument: "Kit = swift build "))

        #expect(sut.key == "Kit ")
        #expect(sut.value == " swift build ")
    }
}

// MARK: - Rejection
extension KeyValueArgumentTests {
    @Test(arguments: ["Kit", "Kit=", "=executable", "="])
    func `A pair not written as a key and a value is refused`(argument: String) {
        #expect(KeyValueArgument(argument: argument) == nil)
    }
}

// MARK: - Collection
extension KeyValueArgumentTests {
    @Test
    func `Pairs fold into a dictionary keyed by their keys`() {
        let pairs = ["Kit=library", "App=executable"].compactMap(KeyValueArgument.init(argument:))

        #expect(pairs.asDictionary() == ["Kit": "library", "App": "executable"])
    }

    @Test
    func `A key given twice resolves to the last value`() {
        let pairs = ["Kit=library", "Kit=executable"].compactMap(KeyValueArgument.init(argument:))

        #expect(pairs.asDictionary() == ["Kit": "executable"])
    }

    @Test
    func `An empty list folds into an empty dictionary`() {
        let pairs: [KeyValueArgument] = []

        #expect(pairs.asDictionary() == [:])
    }
}

// MARK: - End To End
extension KeyValueArgumentTests {
    @Test
    func `A repeatable option collects every pair the caller passed`() throws {
        let command = try BuildCommand.parse([
            "--build-command", "Kit=swift build",
            "--build-command", "App=xcodebuild"
        ])

        #expect(command.build.asDictionary() == ["Kit": "swift build", "App": "xcodebuild"])
    }

    @Test
    func `A command option rejects a pair with no separator`() {
        #expect(throws: (any Error).self) {
            try BuildCommand.parse(["--build-command", "Kit"])
        }
    }
}

// MARK: - SUT
private extension KeyValueArgumentTests {
    struct BuildCommand: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "build")

        @Option(name: .customLong("build-command"), parsing: .singleValue)
        var build: [KeyValueArgument] = []
    }
}
