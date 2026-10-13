//
//  NnPassthroughStages.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

// Fixed to NnNoRequirements so a command with real requirements can't compile with a collector that never asks.

// MARK: - Collector
public struct NnPassthroughCollector: NnCommandCollector {
    public typealias Requirements = NnNoRequirements
    public typealias Answers = Void

    public init() { }

    public func collect(requirements: NnNoRequirements) throws { }
}

// MARK: - Collection Interpreter
public struct NnPassthroughCollectionInterpreter<Findings: Sendable>: NnCollectionInterpreter {
    public typealias Requirements = NnNoRequirements
    public typealias Answers = Void
    public typealias Context = Findings

    public init() { }

    public func interpret(findings: Findings, requirements: NnNoRequirements, answers: Void) throws -> Findings {
        return findings
    }
}
