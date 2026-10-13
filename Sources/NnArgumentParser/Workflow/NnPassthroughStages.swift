//
//  NnPassthroughStages.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

// For commands with nothing to ask: requirements and answers are both Void.

// MARK: - Collector
public struct NnPassthroughCollector: NnCommandCollector {
    public typealias Requirements = Void
    public typealias Answers = Void

    public init() { }

    public func collect(requirements: Void) throws { }
}

// MARK: - Collection Interpreter
public struct NnPassthroughCollectionInterpreter<Findings: Sendable>: NnCollectionInterpreter {
    public typealias Requirements = Void
    public typealias Answers = Void
    public typealias Context = Findings

    public init() { }

    public func interpret(findings: Findings, requirements: Void, answers: Void) throws -> Findings {
        return findings
    }
}
