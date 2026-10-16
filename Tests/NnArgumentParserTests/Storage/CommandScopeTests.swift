//
//  CommandScopeTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Testing
import NnArgumentParser
import NnArgumentParserTesting

struct CommandScopeTests {
    @Test
    func `A registered mode survives suspension points within its scope`() async throws {
        let mode = InteractionMode.nonInteractive(assumeYes: true)

        try await withIsolatedState {
            InteractionMode.register(mode)

            for _ in 0..<20 {
                try await Task.sleep(for: .milliseconds(1))
                #expect(InteractionMode.current == mode)
            }
        }
    }
}


// MARK: - Isolation
extension CommandScopeTests {
    @Test
    func `Concurrent scopes never see each other's mode`() async throws {
        async let first = registerThenRead(mode: .interactive(assumeYes: true))
        async let second = registerThenRead(mode: .nonInteractive(assumeYes: false))

        #expect(try await first == .interactive(assumeYes: true))
        #expect(try await second == .nonInteractive(assumeYes: false))
    }

    @Test
    func `Concurrent scopes never see each other's factory`() async throws {
        async let first = injectThenRead(factory: "first")
        async let second = injectThenRead(factory: "second")

        #expect(try await first == "first")
        #expect(try await second == "second")
    }

    @Test
    func `Task group children see the factory injected into their parent scope`() async {
        let factories = await ScopeRoot.withIsolatedState(contextFactory: "injected") {
            await withTaskGroup(of: String.self) { group in
                for _ in 0..<8 {
                    group.addTask { ScopeRoot.contextFactory }
                }

                return await group.reduce(into: Set<String>()) { $0.insert($1) }
            }
        }

        #expect(factories == ["injected"])
    }
}


// MARK: - Unscoped Access
extension CommandScopeTests {
    @Test
    func `Reading the mode outside any scope falls back to environment and terminal resolution`() {
        #expect(InteractionMode.current == InteractionMode.resolve())
    }

    #if compiler(>=6.2)
    @Test
    func `Reading the factory outside any scope traps`() async {
        await #expect(processExitsWith: .failure) {
            _ = ScopeRoot.contextFactory
        }
    }

    @Test
    func `Registering a mode outside any scope traps`() async {
        await #expect(processExitsWith: .failure) {
            InteractionMode.register(.interactive(assumeYes: false))
        }
    }
    #endif
}


// MARK: - SUT
private extension CommandScopeTests {
    func registerThenRead(mode: InteractionMode) async throws -> InteractionMode {
        return try await withIsolatedState {
            InteractionMode.register(mode)
            try await Task.sleep(for: .milliseconds(5))

            return InteractionMode.current
        }
    }

    func injectThenRead(factory: String) async throws -> String {
        return try await ScopeRoot.withIsolatedState(contextFactory: factory) {
            try await Task.sleep(for: .milliseconds(5))

            return ScopeRoot.contextFactory
        }
    }
}


// MARK: - Test Doubles
private struct ScopeRoot: NnRootCommand {
    static var defaultFactory: String { "default" }
}
