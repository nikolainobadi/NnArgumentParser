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
    where InspectorType.Results == InspectionInterpreter.Input

    associatedtype CollectorType: NnCommandCollector
    where InspectionInterpreter.Output == CollectorType.Context

    associatedtype CollectionInterpreter: NnCommandInterpreter
    where CollectorType.Results == CollectionInterpreter.Input

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
        let collectionContext = try inspectionInterpreter.interpret(inspection)
        let collection = try collector.collect(context: collectionContext)
        let resolutionContext = try collectionInterpreter.interpret(collection)

        return try resolver.resolve(context: resolutionContext)
    }
}

// MARK: - Stages
public protocol NnCommandInspector {
    associatedtype Results

    func inspect() throws -> Results
}

public protocol NnCommandCollector {
    associatedtype Context
    associatedtype Results

    func collect(context: Context) throws -> Results
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
