//
//  NnWorkflowCommand.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/3/26.
//

import ArgumentParser

public protocol NnWorkflowCommand: ParsableCommand {
    associatedtype Workflow: NnWorkflow

    func makeWorkflow() throws -> Workflow
    func handleResults(_ results: Workflow.ResolverType.Results) throws
}

public extension NnWorkflowCommand {
    // The mode is read once here, so the workflow itself never touches thread-local state.
    mutating func run() throws {
        let results = try makeWorkflow().run(isInteractive: InteractionMode.current.isInteractive)
        try handleResults(results)
    }
}
