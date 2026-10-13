//
//  NnWorkflowTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

import Testing
import NnArgumentParser
import NnArgumentParserTesting

struct NnWorkflowTests {
    @Test
    func `Stages run in order and each receives the previous stage's output`() throws {
        let (sut, mocks) = makeSUT(findings: "derived from facts", requirements: "needed", answers: "typed")

        let results = try sut.run()

        #expect(results == "results")
        #expect(mocks.inspector.inspectCallCount == 1)
        #expect(mocks.collector.capturedRequirements == ["needed"])
        #expect(mocks.resolver.capturedContexts == [.init(findings: "derived from facts", answers: "typed")])
    }
}


// MARK: - Passthrough
extension NnWorkflowTests {
    @Test
    func `The passthrough collector and interpreter forward findings as the context`() throws {
        let inspector = MockCommandInspector(facts: "facts", throwError: false)
        let resolver = MockCommandResolver<String, String>(results: "results", throwError: false)
        let sut = PassthroughWorkflow(
            inspector: inspector,
            inspectionInterpreter: .init(findings: "findings", requirements: ()),
            collector: .init(),
            collectionInterpreter: .init(),
            resolver: resolver
        )

        let results = try sut.run()

        #expect(results == "results")
        #expect(resolver.capturedContexts == ["findings"])
    }
}


// MARK: - Failure Propagation
extension NnWorkflowTests {
    @Test
    func `A failing inspector stops the run before the collector`() {
        let (sut, mocks) = makeSUT(inspectorThrows: true)

        #expect(throws: MockWorkflowError.stageFailed) {
            try sut.run()
        }
        #expect(mocks.collector.capturedRequirements.isEmpty)
    }

    @Test
    func `A failing collector stops the run before the resolver`() {
        let (sut, mocks) = makeSUT(collectorThrows: true)

        #expect(throws: MockWorkflowError.stageFailed) {
            try sut.run()
        }
        #expect(mocks.resolver.capturedContexts.isEmpty)
    }

    @Test
    func `A failing resolver surfaces its error`() {
        let (sut, _) = makeSUT(resolverThrows: true)

        #expect(throws: MockWorkflowError.stageFailed) {
            try sut.run()
        }
    }
}


// MARK: - SUT
private extension NnWorkflowTests {
    func makeSUT(
        findings: String = "findings",
        requirements: String = "requirements",
        answers: String = "answers",
        results: String = "results",
        inspectorThrows: Bool = false,
        collectorThrows: Bool = false,
        resolverThrows: Bool = false
    ) -> (sut: StubWorkflow, mocks: Mocks) {
        let inspector = MockCommandInspector(facts: "facts", throwError: inspectorThrows)
        let collector = MockCommandCollector<String, String>(answers: answers, throwError: collectorThrows)
        let resolver = MockCommandResolver<StubContext, String>(results: results, throwError: resolverThrows)
        let sut = StubWorkflow(
            inspector: inspector,
            inspectionInterpreter: .init(findings: findings, requirements: requirements),
            collector: collector,
            collectionInterpreter: .init(),
            resolver: resolver
        )

        return (sut, .init(inspector: inspector, collector: collector, resolver: resolver))
    }
}


// MARK: - Test Doubles
private struct Mocks {
    let inspector: MockCommandInspector<String>
    let collector: MockCommandCollector<String, String>
    let resolver: MockCommandResolver<StubContext, String>
}

private struct StubContext: Sendable, Equatable {
    let findings: String
    let answers: String
}

private struct StubInspectionInterpreter<Requirements: Sendable>: NnInspectionInterpreter {
    let findings: String
    let requirements: Requirements

    func interpret(facts: String) throws -> NnInspection<String, Requirements> {
        return .init(findings: findings, requirements: requirements)
    }
}

private struct StubCollectionInterpreter: NnCollectionInterpreter {
    func interpret(findings: String, requirements: String, answers: String) throws -> StubContext {
        return .init(findings: findings, answers: answers)
    }
}

private struct StubWorkflow: NnWorkflow {
    let inspector: MockCommandInspector<String>
    let inspectionInterpreter: StubInspectionInterpreter<String>
    let collector: MockCommandCollector<String, String>
    let collectionInterpreter: StubCollectionInterpreter
    let resolver: MockCommandResolver<StubContext, String>
}

private struct PassthroughWorkflow: NnWorkflow {
    let inspector: MockCommandInspector<String>
    let inspectionInterpreter: StubInspectionInterpreter<Void>
    let collector: NnPassthroughCollector
    let collectionInterpreter: NnPassthroughCollectionInterpreter<String>
    let resolver: MockCommandResolver<String, String>
}
