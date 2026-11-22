// MARK: - Results Formatter
public protocol NnResultsFormatter {
    associatedtype Results

    func message(for results: Results) -> String?
}

// MARK: - Formatted Workflow Command
public protocol NnFormattedWorkflowCommand: NnWorkflowCommand {
    associatedtype ResultsFormatter: NnResultsFormatter
    where ResultsFormatter.Results == Workflow.PerformerType.Results

    var resultsFormatter: ResultsFormatter { get }
}

// MARK: - Handle Results
public extension NnFormattedWorkflowCommand {
    func handleResults(_ results: Workflow.PerformerType.Results) throws {
        if let message = resultsFormatter.message(for: results) {
            NnOutput.write(message)
        }
    }
}
