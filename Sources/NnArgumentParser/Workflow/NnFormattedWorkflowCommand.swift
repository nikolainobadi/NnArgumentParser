// MARK: - Results Formatter
public protocol NnResultsFormatter {
    associatedtype Results

    func message(for results: Results) -> String?
}

// MARK: - Stateless Results Formatter
// A formatter that needs nothing passed in, so a command can name it instead of building it.
public protocol NnStatelessResultsFormatter: NnResultsFormatter {
    init()
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

// MARK: - Stateless Formatter
public extension NnFormattedWorkflowCommand where ResultsFormatter: NnStatelessResultsFormatter {
    var resultsFormatter: ResultsFormatter {
        return .init()
    }
}
