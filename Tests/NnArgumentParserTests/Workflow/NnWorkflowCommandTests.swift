import Testing
import NnArgumentParserTesting

struct NnWorkflowCommandTests {
    @Test
    func `A workflow command writes its formatter's message`() async throws {
        let output = try await FormattedCommand.testRun(contextFactory: "released", args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(output == "Message: released")
    }

    @Test
    func `A workflow command writes nothing when its formatter returns nil`() async throws {
        let output = try await FormattedCommand.testRun(contextFactory: "", args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(output.isEmpty)
    }

    @Test
    func `A parsed option reaches the formatter the command vends`() async throws {
        let output = try await FormattedCommand.testRun(contextFactory: "released", args: ["--uppercase"], interactionMode: .nonInteractive(assumeYes: false))

        #expect(output == "MESSAGE: RELEASED")
    }

    @Test
    func `A command that only names a stateless formatter writes its message`() async throws {
        let output = try await StatelessFormattedCommand.testRun(contextFactory: "released", args: [], interactionMode: .nonInteractive(assumeYes: false))

        #expect(output == "Plain: released")
    }
}


// MARK: - Test Doubles
private struct FormattedCommand: NnRootCommand, NnWorkflowCommand {
    static var defaultFactory: String { "" }

    @Flag var uppercase = false

    var resultsFormatter: MessageFormatter {
        return .init(uppercase: uppercase)
    }

    func makeWorkflow() throws -> MessageWorkflow {
        return .init(
            inspector: .init(value: Self.contextFactory),
            inspectionInterpreter: .init(),
            collector: .init(),
            collectionInterpreter: .init(),
            performer: .init()
        )
    }
}

private struct MessageFormatter: NnResultsFormatter {
    let uppercase: Bool

    func message(for results: String) -> String? {
        guard !results.isEmpty else {
            return nil
        }

        let message = "Message: \(results)"

        return uppercase ? message.uppercased() : message
    }
}

private struct StatelessFormattedCommand: NnRootCommand, NnWorkflowCommand {
    typealias ResultsFormatter = PlainFormatter

    static var defaultFactory: String { "" }

    func makeWorkflow() throws -> MessageWorkflow {
        return .init(
            inspector: .init(value: Self.contextFactory),
            inspectionInterpreter: .init(),
            collector: .init(),
            collectionInterpreter: .init(),
            performer: .init()
        )
    }
}

private struct PlainFormatter: NnStatelessResultsFormatter {
    func message(for results: String) -> String? {
        return "Plain: \(results)"
    }
}

private struct MessageWorkflow: NnWorkflow {
    let inspector: ValueInspector
    let inspectionInterpreter: ValueInterpreter
    let collector: NnPassthroughCollector
    let collectionInterpreter: NnPassthroughCollectionInterpreter<String>
    let performer: EchoPerformer
}

private struct ValueInspector: NnInspector {
    let value: String

    func inspect() -> String {
        return value
    }
}

private struct ValueInterpreter: NnInspectionInterpreter {
    func interpret(facts: String) throws -> NnInspection<String, Void> {
        return .init(findings: facts, requirements: ())
    }
}

private struct EchoPerformer: NnPerformer {
    func perform(brief: String) -> String {
        return brief
    }
}
