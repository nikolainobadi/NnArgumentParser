//
//  NnRequirement.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

import Foundation

// Known: settled from input or facts. Unknown: missing, with the data the collector needs to ask for it.
public enum NnRequirement<Value: Sendable, Info: Sendable>: Sendable {
    case known(Value)
    case unknown(Info)
}

// MARK: - Ask
public extension NnRequirement {
    // Asks only when unknown; nil means the value was already known.
    func ask(_ asker: (Info) throws -> Value) rethrows -> Value? {
        guard case .unknown(let info) = self else {
            return nil
        }

        return try asker(info)
    }
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

// MARK: - Report
public extension NnRequirement {
    // Nil when known, so a requirements type can build its unsatisfied list as a compactMap over its fields.
    func report(name: String, flagHint: String?, remedy: (Info) -> String) -> NnUnsatisfiedRequirement? {
        guard case .unknown(let info) = self else {
            return nil
        }

        return .init(name: name, flagHint: flagHint, remedy: remedy(info))
    }
}

// MARK: - Error
public enum NnWorkflowError: Error, Equatable {
    case missingAnswer
    case unsatisfiedRequirements([NnUnsatisfiedRequirement])
}

// MARK: - LocalizedError
extension NnWorkflowError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingAnswer:
            return "A required value was neither known nor answered."
        case .unsatisfiedRequirements(let requirements):
            let lines = requirements.map(Self.describe)

            return (["This run can't prompt, and these values are missing:"] + lines).joined(separator: "\n")
        }
    }
}

// MARK: - Private Methods
private extension NnWorkflowError {
    static func describe(_ requirement: NnUnsatisfiedRequirement) -> String {
        let line = "  \(requirement.name): \(requirement.remedy)"

        guard let flagHint = requirement.flagHint, !flagHint.isEmpty else {
            return line
        }

        return "\(line) Pass \(flagHint)."
    }
}
