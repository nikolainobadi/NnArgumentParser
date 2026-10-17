//
//  CaseInsensitiveArgumentTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 9/6/26.
//

import Testing
@testable import NnArgumentParser

struct CaseInsensitiveArgumentTests {
    @Test
    func `A value written exactly as its case is spelled parses`() {
        #expect(Scope(argument: "staged") == .staged)
    }
}

// MARK: - Casing
extension CaseInsensitiveArgumentTests {
    @Test
    func `A value written in uppercase parses to the same case`() {
        #expect(Scope(argument: "STAGED") == .staged)
    }

    @Test
    func `A value written in mixed case parses to the same case`() {
        #expect(Scope(argument: "UnStaGeD") == .unstaged)
    }

    @Test
    func `A camelCase raw value parses from an all-lowercase spelling`() {
        #expect(Project(argument: "swiftpackage") == .swiftPackage)
    }

    @Test
    func `A camelCase raw value parses from its exact spelling`() {
        #expect(Project(argument: "SwiftPackage") == .swiftPackage)
    }
}

// MARK: - Rejection
extension CaseInsensitiveArgumentTests {
    @Test
    func `A value matching no case does not parse`() {
        #expect(Scope(argument: "tracked") == nil)
    }

    @Test
    func `An empty value does not parse`() {
        #expect(Scope(argument: "") == nil)
    }
}

// MARK: - Collisions
extension CaseInsensitiveArgumentTests {
    @Test
    func `Raw values differing only by case each stay reachable by their exact spelling`() {
        #expect(Collides(argument: "run") == .lower)
        #expect(Collides(argument: "RUN") == .upper)
    }

    @Test
    func `A spelling matching no case exactly falls back to the case-insensitive match`() {
        #expect(Collides(argument: "Run") != nil)
    }
}

// MARK: - Advertised Values
extension CaseInsensitiveArgumentTests {
    @Test
    func `Advertised values keep their exact raw-value casing`() {
        #expect(Project.allValueStrings == ["SwiftPackage", "iOSApp"])
    }
}

// MARK: - End To End
extension CaseInsensitiveArgumentTests {
    @Test
    func `A command option parses a value the caller typed in uppercase`() throws {
        let command = try DiscardCommand.parse(["--scope", "BOTH"])

        #expect(command.scope == .both)
    }

    @Test
    func `A command option rejects a value matching no case`() {
        #expect(throws: (any Error).self) {
            try DiscardCommand.parse(["--scope", "tracked"])
        }
    }
}

// MARK: - SUT
private extension CaseInsensitiveArgumentTests {
    enum Scope: String, CaseIterable, CaseInsensitiveArgument {
        case staged, unstaged, both
    }

    /// Raw values that differ from their case names, so a lowercasing shortcut would show up.
    enum Project: String, CaseIterable, CaseInsensitiveArgument {
        case swiftPackage = "SwiftPackage"
        case iosApp = "iOSApp"
    }

    /// Raw values that differ only by letter case.
    enum Collides: String, CaseIterable, CaseInsensitiveArgument {
        case lower = "run"
        case upper = "RUN"
    }

    struct DiscardCommand: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "discard")

        @Option(name: .customLong("scope"))
        var scope: Scope
    }
}
