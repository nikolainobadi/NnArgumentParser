//
//  MockCommandResolver.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

import NnArgumentParser

public final class MockCommandResolver<Context: Sendable, Results: Sendable> {
    private let results: Results
    private let throwError: Bool

    public private(set) var capturedContexts: [Context] = []

    public init(results: Results, throwError: Bool) {
        self.results = results
        self.throwError = throwError
    }
}

// MARK: - NnCommandResolver
extension MockCommandResolver: NnCommandResolver {
    public func resolve(context: Context) throws -> Results {
        capturedContexts.append(context)

        if throwError {
            throw MockWorkflowError.stageFailed
        }

        return results
    }
}
