import Testing
import NnArgumentParserTesting

struct NnCheckedWorkflowTests {
    @Test
    func `Each check runs to completion in order before the base starts`() async throws {
        let log = Log()
        let sut = NnCheckedWorkflow(checks: NnCheckGroup(makeCheck("x", log, .confirms), makeCheck("y", log, .confirms)), base: makeBase(log, false))

        let results = try await sut.run()

        #expect(results == "base results")
        #expect(log.entries == checkEntries("x") + checkEntries("y") + baseEntries)
    }

    @Test
    func `A declined check stops later checks and the base before they ask anything`() async throws {
        let log = Log()
        let sut = NnCheckedWorkflow(
            checks: NnCheckGroup(makeCheck("x", log, .declines), makeCheck("y", log, .confirms)),
            base: makeBase(log, false)
        )

        await #expect(throws: CheckDeclined.self) { try await sut.run() }
        #expect(log.entries == checkEntries("x"))
    }

    @Test
    func `A blocked check stops the run before the base inspector`() async throws {
        let log = Log()
        let sut = NnCheckedWorkflow(checks: makeCheck("x", log, .blocked), base: makeBase(log, false))

        await #expect(throws: CheckBlocked.self) { try await sut.run() }
        #expect(log.entries == ["inspect x", "interpret x"])
    }

    @Test
    func `A check with a known requirement is not asked`() async throws {
        let log = Log()
        let sut = NnCheckedWorkflow(checks: makeCheck("x", log, .known), base: makeBase(log, false))

        _ = try await sut.run()

        #expect(log.entries.contains("collect x"))
        #expect(!log.entries.contains("ask x"))
    }

    @Test
    func `A single check works without a group`() async throws {
        let log = Log()
        let sut = NnCheckedWorkflow(checks: makeCheck("x", log, .confirms), base: makeBase(log, false))

        _ = try await sut.run()

        #expect(log.entries == checkEntries("x") + baseEntries)
    }

    @Test
    func `An empty group runs only the base`() async throws {
        let log = Log()
        let sut = NnCheckedWorkflow(checks: NnCheckGroup(), base: makeBase(log, false))

        _ = try await sut.run()

        #expect(log.entries == baseEntries)
    }

    @Test
    func `A one-check group runs that check`() async throws {
        let log = Log()
        let sut = NnCheckedWorkflow(checks: NnCheckGroup(makeCheck("x", log, .confirms)), base: makeBase(log, false))

        _ = try await sut.run()

        #expect(log.entries == checkEntries("x") + baseEntries)
    }

    @Test
    func `A group nests inside another group in declaration order`() async throws {
        let log = Log()
        let shared = NnCheckGroup(makeCheck("x", log, .confirms), makeCheck("y", log, .confirms))
        let sut = NnCheckedWorkflow(checks: NnCheckGroup(shared, makeCheck("z", log, .confirms)), base: makeBase(log, false))

        _ = try await sut.run()

        #expect(log.entries == checkEntries("x") + checkEntries("y") + checkEntries("z") + baseEntries)
    }

    @Test
    func `A checked workflow nests as the base of another`() async throws {
        let log = Log()
        let inner = NnCheckedWorkflow(checks: makeCheck("y", log, .confirms), base: makeBase(log, false))
        let sut = NnCheckedWorkflow(checks: makeCheck("x", log, .confirms), base: inner)

        _ = try await sut.run()

        #expect(log.entries == checkEntries("x") + checkEntries("y") + baseEntries)
    }

    @Test
    func `A check's own inspector can be tracked`() async throws {
        let log = Log()
        let check = makeCheck("x", log, .confirms)
        let tracked = TrackedCheck(
            inspector: .init(base: check.inspector, track: { work in
                log.record("track x start")
                let facts = try await work()
                log.record("track x end")
                return facts
            }),
            inspectionInterpreter: check.inspectionInterpreter,
            collector: check.collector,
            collectionInterpreter: check.collectionInterpreter
        )
        let sut = NnCheckedWorkflow(checks: tracked, base: makeBase(log, false))

        _ = try await sut.run()

        #expect(log.entries.prefix(4) == ["track x start", "inspect x", "track x end", "interpret x"])
    }

    @Test
    func `The base inspector can be tracked under a checked workflow`() async throws {
        let log = Log()
        let base = makeBase(log, false)
        let trackedBase = TrackedBase(
            inspector: .init(base: base.inspector, track: { work in
                log.record("track base start")
                let facts = try await work()
                log.record("track base end")
                return facts
            }),
            inspectionInterpreter: base.inspectionInterpreter,
            collector: base.collector,
            collectionInterpreter: base.collectionInterpreter,
            performer: base.performer
        )
        let sut = NnCheckedWorkflow(checks: makeCheck("x", log, .confirms), base: trackedBase)

        _ = try await sut.run()

        #expect(log.entries == checkEntries("x") + ["track base start", "inspect base", "track base end"] + baseEntries.dropFirst())
    }

    @Test
    func `A check asks before the base's own inspection blocks`() async throws {
        let log = Log()
        let sut = NnCheckedWorkflow(checks: makeCheck("x", log, .confirms), base: makeBase(log, true))

        await #expect(throws: BaseBlocked.self) { try await sut.run() }
        #expect(log.entries == checkEntries("x") + ["inspect base", "interpret base"])
    }

    @Test
    func `Driving the stages by hand bypasses the checks`() async throws {
        let log = Log()
        let sut = NnCheckedWorkflow(checks: makeCheck("x", log, .declines), base: makeBase(log, false))

        let facts = sut.inspector.inspect()
        let inspection = try sut.inspectionInterpreter.interpret(facts: facts)
        let answers = try sut.collector.collect(requirements: inspection.requirements)
        let brief = try sut.collectionInterpreter.interpret(findings: inspection.findings, requirements: inspection.requirements, answers: answers)
        _ = try await sut.performer.perform(brief: brief)

        #expect(log.entries == baseEntries)
    }

    @Test
    func `A check reached through two groups runs twice`() async throws {
        let log = Log()
        let x = makeCheck("x", log, .confirms)
        let sut = NnCheckedWorkflow(checks: NnCheckGroup(NnCheckGroup(x), NnCheckGroup(x)), base: makeBase(log, false))

        _ = try await sut.run()

        #expect(log.entries == checkEntries("x") + checkEntries("x") + baseEntries)
    }

    @Test
    func `A command runs its checks and keeps the base results type`() async throws {
        let factory = CheckedCommandFactory(log: .init(), outcome: .confirms)

        let output = try await CheckedCommand.testRun(contextFactory: factory, args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(output == "base results")
        #expect(factory.log.entries == checkEntries("x") + checkEntries("y") + baseEntries)
    }

    @Test
    func `A command stops at a declined check before its own workflow starts`() async throws {
        let factory = CheckedCommandFactory(log: .init(), outcome: .declines)

        await #expect(throws: CheckDeclined.self) {
            try await CheckedCommand.testRun(contextFactory: factory, args: [], interactionMode: .nonInteractive(assumeYes: false))
        }
        #expect(factory.log.entries == checkEntries("x"))
    }
}


// MARK: - Helpers
private let baseEntries = ["inspect base", "interpret base", "collect base", "ask base", "decide base", "perform base"]

private func checkEntries(_ name: String) -> [String] {
    return ["inspect \(name)", "interpret \(name)", "collect \(name)", "ask \(name)", "decide \(name)"]
}

private func makeCheck(_ name: String, _ log: Log, _ outcome: CheckOutcome) -> RecordingCheck {
    return .init(name: name, log: log, outcome: outcome)
}

private func makeBase(_ log: Log, _ blocked: Bool) -> RecordingBase {
    return .init(
        inspector: .init(log: log),
        inspectionInterpreter: .init(log: log, blocked: blocked),
        collector: .init(log: log),
        collectionInterpreter: .init(log: log),
        performer: .init(log: log)
    )
}


// MARK: - Test Doubles
private final class Log: @unchecked Sendable {
    private(set) var entries: [String] = []

    func record(_ entry: String) {
        entries.append(entry)
    }
}

private enum CheckOutcome {
    case confirms, declines, known, blocked
}

private struct CheckDeclined: Error { }
private struct CheckBlocked: Error { }
private struct BaseBlocked: Error { }

private struct RecordingCheck: NnCheck {
    let inspector: Inspector
    let inspectionInterpreter: InspectionInterpreter
    let collector: Collector
    let collectionInterpreter: CollectionInterpreter

    init(name: String, log: Log, outcome: CheckOutcome) {
        inspector = .init(name: name, log: log)
        inspectionInterpreter = .init(name: name, log: log, outcome: outcome)
        collector = .init(name: name, log: log, outcome: outcome)
        collectionInterpreter = .init(name: name, log: log)
    }

    struct Inspector: NnInspector {
        let name: String
        let log: Log

        func inspect() -> String {
            log.record("inspect \(name)")
            return "\(name) status"
        }
    }

    struct InspectionInterpreter: NnInspectionInterpreter {
        let name: String
        let log: Log
        let outcome: CheckOutcome

        func interpret(facts: String) throws -> NnInspection<String, NnRequirement<Bool, String>> {
            log.record("interpret \(name)")

            switch outcome {
            case .blocked:
                throw CheckBlocked()
            case .known:
                return .init(findings: facts, requirements: .known(true))
            case .confirms, .declines:
                return .init(findings: facts, requirements: .unknown("continue past \(name)?"))
            }
        }
    }

    struct Collector: NnCollector {
        let name: String
        let log: Log
        let outcome: CheckOutcome

        func collect(requirements: NnRequirement<Bool, String>) throws -> Bool? {
            log.record("collect \(name)")

            return requirements.ask { _ in
                log.record("ask \(name)")
                return outcome == .confirms
            }
        }
    }

    struct CollectionInterpreter: NnCollectionInterpreter {
        let name: String
        let log: Log

        func interpret(findings: String, requirements: NnRequirement<Bool, String>, answers: Bool?) throws -> String {
            log.record("decide \(name)")

            guard try requirements.resolve(answer: answers) else {
                throw CheckDeclined()
            }

            return findings
        }
    }
}

private struct TrackedCheck: NnCheck {
    let inspector: NnTrackedInspector<RecordingCheck.Inspector>
    let inspectionInterpreter: RecordingCheck.InspectionInterpreter
    let collector: RecordingCheck.Collector
    let collectionInterpreter: RecordingCheck.CollectionInterpreter
}

private struct RecordingBase: NnWorkflow {
    let inspector: Inspector
    let inspectionInterpreter: InspectionInterpreter
    let collector: Collector
    let collectionInterpreter: CollectionInterpreter
    let performer: Performer

    struct Inspector: NnInspector {
        let log: Log

        func inspect() -> Int {
            log.record("inspect base")
            return 1
        }
    }

    struct InspectionInterpreter: NnInspectionInterpreter {
        let log: Log
        let blocked: Bool

        func interpret(facts: Int) throws -> NnInspection<Int, NnRequirement<String, String>> {
            log.record("interpret base")

            if blocked {
                throw BaseBlocked()
            }

            return .init(findings: facts, requirements: .unknown("name?"))
        }
    }

    struct Collector: NnCollector {
        let log: Log

        func collect(requirements: NnRequirement<String, String>) throws -> String? {
            log.record("collect base")

            return requirements.ask { _ in
                log.record("ask base")
                return "answer"
            }
        }
    }

    struct CollectionInterpreter: NnCollectionInterpreter {
        let log: Log

        func interpret(findings: Int, requirements: NnRequirement<String, String>, answers: String?) throws -> Int {
            log.record("decide base")
            _ = try requirements.resolve(answer: answers)
            return findings
        }
    }

    struct Performer: NnPerformer {
        let log: Log

        func perform(brief: Int) async throws -> String {
            log.record("perform base")
            return "base results"
        }
    }
}

private struct TrackedBase: NnWorkflow {
    let inspector: NnTrackedInspector<RecordingBase.Inspector>
    let inspectionInterpreter: RecordingBase.InspectionInterpreter
    let collector: RecordingBase.Collector
    let collectionInterpreter: RecordingBase.CollectionInterpreter
    let performer: RecordingBase.Performer
}

private final class CheckedCommandFactory: Sendable {
    let log: Log
    let outcome: CheckOutcome

    init(log: Log, outcome: CheckOutcome) {
        self.log = log
        self.outcome = outcome
    }
}

private struct CheckedCommand: NnRootCommand, NnCustomResultsWorkflowCommand {
    static var defaultFactory: CheckedCommandFactory {
        return .init(log: .init(), outcome: .confirms)
    }

    func makeWorkflow() throws -> NnCheckedWorkflow<NnCheckGroup<RecordingCheck, RecordingCheck>, RecordingBase> {
        let factory = Self.contextFactory

        return .init(
            checks: .init(makeCheck("x", factory.log, factory.outcome), makeCheck("y", factory.log, .confirms)),
            base: makeBase(factory.log, false)
        )
    }

    func handleResults(_ results: String) throws {
        NnOutput.write(results)
    }
}
