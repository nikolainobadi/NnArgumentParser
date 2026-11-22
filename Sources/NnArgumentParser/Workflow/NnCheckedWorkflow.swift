//
//  NnCheckedWorkflow.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 11/22/26.
//

// MARK: - Checked Workflow
public struct NnCheckedWorkflow<Checks: NnRunnableCheck, Base: NnWorkflow> {
    private let checks: Checks
    private let base: Base

    public init(checks: Checks, base: Base) {
        self.checks = checks
        self.base = base
    }
}

// MARK: - NnWorkflow
extension NnCheckedWorkflow: NnWorkflow {
    public var inspector: Base.InspectorType {
        return base.inspector
    }

    public var inspectionInterpreter: Base.InspectionInterpreter {
        return base.inspectionInterpreter
    }

    public var collector: Base.CollectorType {
        return base.collector
    }

    public var collectionInterpreter: Base.CollectionInterpreter {
        return base.collectionInterpreter
    }

    public var performer: Base.PerformerType {
        return base.performer
    }

    public func run() async throws -> Base.PerformerType.Results {
        try await checks.run()

        return try await base.run()
    }
}
