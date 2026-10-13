//
//  MockCommandCollector.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

import NnArgumentParser

public final class MockCommandCollector<Requirements: Sendable, Answers: Sendable> {
    private let answers: Answers
    private let throwError: Bool

    public private(set) var capturedRequirements: [Requirements] = []

    public init(answers: Answers, throwError: Bool) {
        self.answers = answers
        self.throwError = throwError
    }
}

// MARK: - NnCommandCollector
extension MockCommandCollector: NnCommandCollector {
    public func collect(requirements: Requirements) throws -> Answers {
        capturedRequirements.append(requirements)

        if throwError {
            throw MockWorkflowError.stageFailed
        }

        return answers
    }
}
