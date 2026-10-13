//
//  NnInspection.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

// What the inspection interpreter learned, and what it still needs before the resolver can run.
public struct NnInspection<Findings: Sendable, Requirements: NnRequirements>: Sendable {
    public let findings: Findings
    public let requirements: Requirements

    public init(findings: Findings, requirements: Requirements) {
        self.findings = findings
        self.requirements = requirements
    }
}
