//
//  NnWorkflowCommand.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/3/26.
//

import ArgumentParser

public protocol NnWorkflowCommand: AsyncParsableCommand {
    associatedtype Workflow: NnWorkflow

    func makeWorkflow() throws -> Workflow
    func handleResults(_ results: Workflow.ResolverType.Results) throws
}

public extension NnWorkflowCommand {
    mutating func run() async throws {
        let workflow = try makeWorkflow()
        let results = try await withTaskExecutorPreference(NnBlockingTolerantExecutor.shared) {
            try await workflow.run()
        }

        try handleResults(results)
    }
}
