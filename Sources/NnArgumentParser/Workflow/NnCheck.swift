// MARK: - Runnable Check
// Anything that can run before a command's workflow and stop it by throwing.
public protocol NnRunnableCheck {
    func run() async throws
}

// MARK: - Check
// A workflow without a performer. Its brief is discarded; it stops the run by throwing.
public protocol NnCheck: NnRunnableCheck {
    associatedtype InspectorType: NnInspector

    associatedtype InspectionInterpreter: NnInspectionInterpreter
    where InspectionInterpreter.Facts == InspectorType.Facts

    associatedtype CollectorType: NnCollector
    where CollectorType.Requirements == InspectionInterpreter.Requirements

    associatedtype CollectionInterpreter: NnCollectionInterpreter
    where CollectionInterpreter.Findings == InspectionInterpreter.Findings,
          CollectionInterpreter.Requirements == CollectorType.Requirements,
          CollectionInterpreter.Answers == CollectorType.Answers

    var inspector: InspectorType { get }
    var inspectionInterpreter: InspectionInterpreter { get }
    var collector: CollectorType { get }
    var collectionInterpreter: CollectionInterpreter { get }
}

// MARK: - Run
public extension NnCheck {
    func run() async throws {
        let facts = try await inspector.inspect()
        let inspection = try inspectionInterpreter.interpret(facts: facts)
        let answers = try collector.collect(requirements: inspection.requirements)

        _ = try collectionInterpreter.interpret(findings: inspection.findings, requirements: inspection.requirements, answers: answers)
    }
}
