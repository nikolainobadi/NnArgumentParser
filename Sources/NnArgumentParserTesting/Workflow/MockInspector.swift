//
//  MockInspector.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

import NnArgumentParser

public final class MockInspector<Facts: Sendable> {
    private let facts: Facts
    private let throwError: Bool

    public private(set) var inspectCallCount = 0

    public init(facts: Facts, throwError: Bool) {
        self.facts = facts
        self.throwError = throwError
    }
}

// MARK: - NnInspector
extension MockInspector: NnInspector {
    public func inspect() throws -> Facts {
        inspectCallCount += 1

        if throwError {
            throw MockWorkflowError.stageFailed
        }

        return facts
    }
}
