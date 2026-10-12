//
//  NnWorkflow.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/3/26.
//

// MARK: - Workflow
public protocol NnWorkflow {
    associatedtype InspectorType: NnCommandInspector

    associatedtype InspectionInterpreter: NnCommandInterpreter
    where InspectorType.Facts == InspectionInterpreter.Input

    associatedtype CollectorType: NnCommandCollector
    where InspectionInterpreter.Output == CollectorType.Questions

    associatedtype CollectionInterpreter: NnCommandInterpreter
    where CollectorType.Answers == CollectionInterpreter.Input

    associatedtype ResolverType: NnCommandResolver
    where CollectionInterpreter.Output == ResolverType.Context

    var inspector: InspectorType { get }
    var inspectionInterpreter: InspectionInterpreter { get }
    var collector: CollectorType { get }
    var collectionInterpreter: CollectionInterpreter { get }
    var resolver: ResolverType { get }
}

// MARK: - Run
public extension NnWorkflow {
    func run() throws -> ResolverType.Results {
        let inspection = try inspector.inspect()
        let questions = try inspectionInterpreter.interpret(inspection)
        let answers = try collector.collect(questions: questions)
        let resolutionContext = try collectionInterpreter.interpret(answers)

        return try resolver.resolve(context: resolutionContext)
    }
}

// MARK: - Stages
public protocol NnCommandInspector {
    associatedtype Facts: Sendable

    func inspect() throws -> Facts
}

public protocol NnCommandCollector {
    associatedtype Questions: Sendable
    associatedtype Answers: Sendable

    func collect(questions: Questions) throws -> Answers
}

public protocol NnCommandResolver {
    associatedtype Context
    associatedtype Results

    func resolve(context: Context) throws -> Results
}

public protocol NnCommandInterpreter {
    associatedtype Input
    associatedtype Output

    func interpret(_ input: Input) throws -> Output
}
