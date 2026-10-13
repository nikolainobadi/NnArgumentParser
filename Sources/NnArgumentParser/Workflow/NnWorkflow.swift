//
//  NnWorkflow.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/3/26.
//

// MARK: - Workflow
public protocol NnWorkflow {
    associatedtype InspectorType: NnCommandInspector

    associatedtype InspectionInterpreter: NnInspectionInterpreter
    where InspectionInterpreter.Facts == InspectorType.Facts

    associatedtype CollectorType: NnCommandCollector
    where CollectorType.Requirements == InspectionInterpreter.Requirements

    associatedtype CollectionInterpreter: NnCollectionInterpreter
    where CollectionInterpreter.Findings == InspectionInterpreter.Findings,
          CollectionInterpreter.Requirements == CollectorType.Requirements,
          CollectionInterpreter.Answers == CollectorType.Answers

    associatedtype ResolverType: NnCommandResolver
    where ResolverType.Context == CollectionInterpreter.Context

    var inspector: InspectorType { get }
    var inspectionInterpreter: InspectionInterpreter { get }
    var collector: CollectorType { get }
    var collectionInterpreter: CollectionInterpreter { get }
    var resolver: ResolverType { get }
}

// MARK: - Run
public extension NnWorkflow {
    func run() throws -> ResolverType.Results {
        let facts = try inspector.inspect()
        let inspection = try inspectionInterpreter.interpret(facts: facts)
        let answers = try collector.collect(requirements: inspection.requirements)
        let context = try collectionInterpreter.interpret(findings: inspection.findings, requirements: inspection.requirements, answers: answers)

        return try resolver.resolve(context: context)
    }
}

// MARK: - Stages
public protocol NnCommandInspector {
    associatedtype Facts: Sendable

    func inspect() throws -> Facts
}

public protocol NnInspectionInterpreter {
    associatedtype Facts: Sendable
    associatedtype Findings: Sendable
    associatedtype Requirements: Sendable

    func interpret(facts: Facts) throws -> NnInspection<Findings, Requirements>
}

public protocol NnCommandCollector {
    associatedtype Requirements: Sendable
    associatedtype Answers: Sendable

    func collect(requirements: Requirements) throws -> Answers
}

public protocol NnCollectionInterpreter {
    associatedtype Findings: Sendable
    associatedtype Requirements: Sendable
    associatedtype Answers: Sendable
    associatedtype Context: Sendable

    func interpret(findings: Findings, requirements: Requirements, answers: Answers) throws -> Context
}

public protocol NnCommandResolver {
    associatedtype Context: Sendable
    associatedtype Results: Sendable

    func resolve(context: Context) throws -> Results
}
