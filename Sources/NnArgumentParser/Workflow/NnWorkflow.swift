//
//  NnWorkflow.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/3/26.
//

// MARK: - Workflow
public protocol NnWorkflow {
    associatedtype InspectorType: NnInspector

    associatedtype InspectionInterpreter: NnInspectionInterpreter
    where InspectionInterpreter.Facts == InspectorType.Facts

    associatedtype CollectorType: NnCollector
    where CollectorType.Requirements == InspectionInterpreter.Requirements

    associatedtype CollectionInterpreter: NnCollectionInterpreter
    where CollectionInterpreter.Findings == InspectionInterpreter.Findings,
          CollectionInterpreter.Requirements == CollectorType.Requirements,
          CollectionInterpreter.Answers == CollectorType.Answers

    associatedtype PerformerType: NnPerformer
    where PerformerType.Brief == CollectionInterpreter.Brief

    var inspector: InspectorType { get }
    var inspectionInterpreter: InspectionInterpreter { get }
    var collector: CollectorType { get }
    var collectionInterpreter: CollectionInterpreter { get }
    var performer: PerformerType { get }
}

// MARK: - Run
public extension NnWorkflow {
    func run() async throws -> PerformerType.Results {
        let facts = try await inspector.inspect()
        let inspection = try inspectionInterpreter.interpret(facts: facts)
        let answers = try collector.collect(requirements: inspection.requirements)
        let brief = try collectionInterpreter.interpret(findings: inspection.findings, requirements: inspection.requirements, answers: answers)

        return try await performer.perform(brief: brief)
    }
}

// MARK: - Stages
public protocol NnInspector {
    associatedtype Facts: Sendable

    func inspect() async throws -> Facts
}

public protocol NnInspectionInterpreter {
    associatedtype Facts: Sendable
    associatedtype Findings: Sendable
    associatedtype Requirements: Sendable

    func interpret(facts: Facts) throws -> NnInspection<Findings, Requirements>
}

public protocol NnCollector {
    associatedtype Requirements: Sendable
    associatedtype Answers: Sendable

    func collect(requirements: Requirements) throws -> Answers
}

public protocol NnCollectionInterpreter {
    associatedtype Findings: Sendable
    associatedtype Requirements: Sendable
    associatedtype Answers: Sendable
    associatedtype Brief: Sendable

    func interpret(findings: Findings, requirements: Requirements, answers: Answers) throws -> Brief
}

public protocol NnPerformer {
    associatedtype Brief: Sendable
    associatedtype Results: Sendable

    func perform(brief: Brief) async throws -> Results
}
