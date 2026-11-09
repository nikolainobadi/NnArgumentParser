//
//  MockPerformer.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

import NnArgumentParser

public final class MockPerformer<Brief: Sendable, Results: Sendable> {
    private let results: Results
    private let throwError: Bool

    public private(set) var capturedBriefs: [Brief] = []

    public init(results: Results, throwError: Bool) {
        self.results = results
        self.throwError = throwError
    }
}

// MARK: - NnPerformer
extension MockPerformer: NnPerformer {
    public func perform(brief: Brief) throws -> Results {
        capturedBriefs.append(brief)

        if throwError {
            throw MockWorkflowError.stageFailed
        }

        return results
    }
}
