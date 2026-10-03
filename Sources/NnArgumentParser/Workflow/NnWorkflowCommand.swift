//
//  NnWorkflowCommand.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/3/26.
//

import ArgumentParser

public protocol NnWorkflowCommand: ParsableCommand {
    associatedtype Workflow: NnCommandWorkflow

    func makeWorkflow() throws -> Workflow
    func handleResults(_ results: Workflow.ResolverType.Results) throws
}

public extension NnWorkflowCommand {
    mutating func run() throws {
        let results = try makeWorkflow().run()
        try handleResults(results)
    }
}
