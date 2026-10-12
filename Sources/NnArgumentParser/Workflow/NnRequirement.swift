//
//  NnRequirement.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

// Known: settled from input or facts. Unknown: missing, with the data the collector needs to ask for it.
public enum NnRequirement<Value: Sendable, Info: Sendable>: Sendable {
    case known(Value)
    case unknown(Info)
}

// MARK: - Resolve
public extension NnRequirement {
    func resolve(answer: Value?) throws -> Value {
        switch self {
        case .known(let value):
            return value
        case .unknown:
            guard let answer else {
                throw NnWorkflowError.missingAnswer
            }

            return answer
        }
    }
}

// MARK: - Error
public enum NnWorkflowError: Error {
    case missingAnswer
}
