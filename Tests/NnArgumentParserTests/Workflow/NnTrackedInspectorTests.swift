//
//  NnTrackedInspectorTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 11/3/26.
//

import Testing
import NnArgumentParserTesting

struct NnTrackedInspectorTests {
    @Test
    func `Inspect returns the base inspector's facts`() async throws {
        let base = MockInspector(facts: "facts", throwError: false)
        let sut = NnTrackedInspector(base: base, track: passthrough)

        let facts = try await sut.inspect()

        #expect(facts == "facts")
        #expect(base.inspectCallCount == 1)
    }

    @Test
    func `The track closure surrounds the base inspection`() async throws {
        let base = MockInspector(facts: "facts", throwError: false)
        var callCountBeforeWork: Int?
        var callCountAfterWork: Int?
        let sut = NnTrackedInspector(base: base, track: { work in
            callCountBeforeWork = base.inspectCallCount
            let facts = try await work()
            callCountAfterWork = base.inspectCallCount

            return facts
        })

        _ = try await sut.inspect()

        #expect(callCountBeforeWork == 0)
        #expect(callCountAfterWork == 1)
    }

    @Test
    func `A base inspector's error reaches the caller`() async {
        let base = MockInspector(facts: "facts", throwError: true)
        var capturedError: Error?
        let sut = NnTrackedInspector(base: base, track: { work in
            do {
                return try await work()
            } catch {
                capturedError = error
                throw error
            }
        })

        await #expect(throws: MockWorkflowError.stageFailed) {
            try await sut.inspect()
        }
        #expect(capturedError as? MockWorkflowError == .stageFailed)
    }

    @Test
    func `A track closure that throws before starting work skips the base`() async {
        let base = MockInspector(facts: "facts", throwError: false)
        let sut = NnTrackedInspector<MockInspector<String>>(base: base, track: { _ in
            throw TrackError.notStarted
        })

        await #expect(throws: TrackError.notStarted) {
            try await sut.inspect()
        }
        #expect(base.inspectCallCount == 0)
    }

    @Test
    func `A workflow runs with a tracked inspector`() async throws {
        let base = MockInspector(facts: "facts", throwError: false)
        let performer = MockPerformer<String, String>(results: "results", throwError: false)
        let sut = TrackedWorkflow(
            inspector: .init(base: base, track: passthrough),
            inspectionInterpreter: .init(),
            collector: .init(),
            collectionInterpreter: .init(),
            performer: performer
        )

        let results = try await sut.run()

        #expect(results == "results")
        #expect(performer.capturedBriefs == ["facts"])
    }
}


// MARK: - Test Doubles
private func passthrough<Facts>(_ work: () async throws -> Facts) async throws -> Facts {
    return try await work()
}

private enum TrackError: Error, Equatable {
    case notStarted
}

private struct FactsAsFindingsInterpreter: NnInspectionInterpreter {
    func interpret(facts: String) throws -> NnInspection<String, Void> {
        return .init(findings: facts, requirements: ())
    }
}

private struct TrackedWorkflow: NnWorkflow {
    let inspector: NnTrackedInspector<MockInspector<String>>
    let inspectionInterpreter: FactsAsFindingsInterpreter
    let collector: NnPassthroughCollector
    let collectionInterpreter: NnPassthroughCollectionInterpreter<String>
    let performer: MockPerformer<String, String>
}
