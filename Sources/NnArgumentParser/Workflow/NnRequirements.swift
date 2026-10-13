//
//  NnRequirements.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

public struct NnUnsatisfiedRequirement: Sendable, Equatable {
    public let name: String
    public let flagHint: String?
    public let remedy: String

    public init(name: String, flagHint: String?, remedy: String) {
        self.name = name
        self.flagHint = flagHint
        self.remedy = remedy
    }
}

// Reports which values a non-interactive run is missing, so the workflow can stop before any prompt.
public protocol NnRequirements: Sendable {
    var unsatisfied: [NnUnsatisfiedRequirement] { get }
}

public struct NnNoRequirements: NnRequirements {
    public init() { }

    public var unsatisfied: [NnUnsatisfiedRequirement] {
        return []
    }
}
