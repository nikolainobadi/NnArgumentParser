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
    func `Stages run in order and each receives the previous stage's output`() async throws {
        let (sut, mocks) = makeSUT(findings: "derived from facts", requirements: "needed", answers: "typed")

        let results = try await sut.run()

        #expect(results == "results")
        #expect(mocks.inspector.inspectCallCount == 1)
        #expect(mocks.collector.capturedRequirements == ["needed"])
        #expect(mocks.performer.capturedBriefs == [.init(findings: "derived from facts", answers: "typed")])
    }
}


// MARK: - Passthrough
extension NnWorkflowTests {
    @Test
    func `The passthrough collector and interpreter forward findings as the brief`() async throws {
        let inspector = MockInspector(facts: "facts", throwError: false)
        let performer = MockPerformer<String, String>(results: "results", throwError: false)
        let sut = PassthroughWorkflow(
            inspector: inspector,
            inspectionInterpreter: .init(findings: "findings", requirements: ()),
            collector: .init(),
            collectionInterpreter: .init(),
            performer: performer
        )

        let results = try await sut.run()

        #expect(results == "results")
        #expect(performer.capturedBriefs == ["findings"])
    }
}


// MARK: - Failure Propagation
extension NnWorkflowTests {
    @Test
    func `A failing inspector stops the run before the collector`() async {
        let (sut, mocks) = makeSUT(inspectorThrows: true)

        await #expect(throws: MockWorkflowError.stageFailed) {
            try await sut.run()
        }
        #expect(mocks.collector.capturedRequirements.isEmpty)
    }

    @Test
    func `A failing collector stops the run before the performer`() async {
        let (sut, mocks) = makeSUT(collectorThrows: true)

        await #expect(throws: MockWorkflowError.stageFailed) {
            try await sut.run()
        }
        #expect(mocks.performer.capturedBriefs.isEmpty)
    }

    @Test
    func `A failing performer surfaces its error`() async {
        let (sut, _) = makeSUT(performerThrows: true)

        await #expect(throws: MockWorkflowError.stageFailed) {
            try await sut.run()
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
        performerThrows: Bool = false
    ) -> (sut: StubWorkflow, mocks: Mocks) {
        let inspector = MockInspector(facts: "facts", throwError: inspectorThrows)
        let collector = MockCollector<String, String>(answers: answers, throwError: collectorThrows)
        let performer = MockPerformer<StubBrief, String>(results: results, throwError: performerThrows)
        let sut = StubWorkflow(
            inspector: inspector,
            inspectionInterpreter: .init(findings: findings, requirements: requirements),
            collector: collector,
            collectionInterpreter: .init(),
            performer: performer
        )

        return (sut, .init(inspector: inspector, collector: collector, performer: performer))
    }
}


// MARK: - Test Doubles
private struct Mocks {
    let inspector: MockInspector<String>
    let collector: MockCollector<String, String>
    let performer: MockPerformer<StubBrief, String>
}

private struct StubBrief: Sendable, Equatable {
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
    func interpret(findings: String, requirements: String, answers: String) throws -> StubBrief {
        return .init(findings: findings, answers: answers)
    }
}

private struct StubWorkflow: NnWorkflow {
    let inspector: MockInspector<String>
    let inspectionInterpreter: StubInspectionInterpreter<String>
    let collector: MockCollector<String, String>
    let collectionInterpreter: StubCollectionInterpreter
    let performer: MockPerformer<StubBrief, String>
}

private struct PassthroughWorkflow: NnWorkflow {
    let inspector: MockInspector<String>
    let inspectionInterpreter: StubInspectionInterpreter<Void>
    let collector: NnPassthroughCollector
    let collectionInterpreter: NnPassthroughCollectionInterpreter<String>
    let performer: MockPerformer<String, String>
}
