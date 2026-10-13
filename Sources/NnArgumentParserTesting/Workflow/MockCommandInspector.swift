//
//  MockCommandInspector.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

import NnArgumentParser

public final class MockCommandInspector<Facts: Sendable> {
    private let facts: Facts
    private let throwError: Bool

    public private(set) var inspectCallCount = 0

    public init(facts: Facts, throwError: Bool) {
        self.facts = facts
        self.throwError = throwError
    }
}

// MARK: - NnCommandInspector
extension MockCommandInspector: NnCommandInspector {
    public func inspect() throws -> Facts {
        inspectCallCount += 1

        if throwError {
            throw MockWorkflowError.stageFailed
        }

        return facts
    }
}
