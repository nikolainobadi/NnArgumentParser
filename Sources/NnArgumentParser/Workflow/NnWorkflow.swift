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
    where CollectorType.Questions == InspectionInterpreter.Questions

    associatedtype CollectionInterpreter: NnCollectionInterpreter
    where CollectionInterpreter.Facts == InspectorType.Facts,
          CollectionInterpreter.Questions == CollectorType.Questions,
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
        let questions = try inspectionInterpreter.interpret(facts: facts)
        let answers = try collector.collect(questions: questions)
        let context = try collectionInterpreter.interpret(facts: facts, questions: questions, answers: answers)

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
    associatedtype Questions: Sendable

    func interpret(facts: Facts) throws -> Questions
}

public protocol NnCommandCollector {
    associatedtype Questions: Sendable
    associatedtype Answers: Sendable

    func collect(questions: Questions) throws -> Answers
}

public protocol NnCollectionInterpreter {
    associatedtype Facts: Sendable
    associatedtype Questions: Sendable
    associatedtype Answers: Sendable
    associatedtype Context

    func interpret(facts: Facts, questions: Questions, answers: Answers) throws -> Context
}

public protocol NnCommandResolver {
    associatedtype Context
    associatedtype Results

    func resolve(context: Context) throws -> Results
}
