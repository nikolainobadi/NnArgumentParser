//
//  NnWorkflowCommandTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Testing
import Foundation
import NnArgumentParser
import NnArgumentParserTesting

struct NnWorkflowCommandTests {
    @Test
    func `A workflow command hands the resolver's results to the command`() async throws {
        let output = try await BarrierCommand.testRun(contextFactory: 1, args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(output == "all 1 children ran concurrently")
    }

    @Test
    func `Blocking task group children all run at once rather than in core-count batches`() async throws {
        let childCount = ProcessInfo.processInfo.activeProcessorCount * 2

        let output = try await BarrierCommand.testRun(contextFactory: childCount, args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(output == "all \(childCount) children ran concurrently")
    }
}


// MARK: - Test Doubles
private struct BarrierCommand: NnRootCommand, NnWorkflowCommand {
    static var defaultFactory: Int { 1 }

    func makeWorkflow() throws -> BarrierWorkflow {
        return .init(
            inspector: .init(childCount: Self.contextFactory),
            inspectionInterpreter: .init(),
            collector: .init(),
            collectionInterpreter: .init(),
            resolver: .init()
        )
    }

    func handleResults(_ results: String) throws {
        NnOutput.write(results)
    }
}

private struct BarrierWorkflow: NnWorkflow {
    let inspector: ChildCountInspector
    let inspectionInterpreter: ChildCountInterpreter
    let collector: NnPassthroughCollector
    let collectionInterpreter: NnPassthroughCollectionInterpreter<Int>
    let resolver: BarrierResolver
}

private struct ChildCountInspector: NnCommandInspector {
    let childCount: Int

    func inspect() -> Int {
        return childCount
    }
}

private struct ChildCountInterpreter: NnInspectionInterpreter {
    func interpret(facts: Int) throws -> NnInspection<Int, Void> {
        return .init(findings: facts, requirements: ())
    }
}

private struct BarrierResolver: NnCommandResolver {
    func resolve(context childCount: Int) async throws -> String {
        let barrier = Barrier(count: childCount)
        let arrivals = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<childCount {
                group.addTask { barrier.arriveAndWait(timeout: 5) }
            }

            return await group.reduce(into: [Bool]()) { $0.append($1) }
        }

        return arrivals.allSatisfy { $0 } ? "all \(childCount) children ran concurrently" : "children were serialized"
    }
}

private final class Barrier: @unchecked Sendable {
    private let condition = NSCondition()
    private let count: Int
    private var arrived = 0

    init(count: Int) {
        self.count = count
    }

    func arriveAndWait(timeout: TimeInterval) -> Bool {
        condition.lock()
        defer { condition.unlock() }

        arrived += 1
        condition.broadcast()

        let deadline = Date(timeIntervalSinceNow: timeout)

        while arrived < count {
            if !condition.wait(until: deadline) {
                return false
            }
        }

        return true
    }
}
