// Thrown by the workflow mocks when created with throwError true, for exercising error paths.
public enum MockWorkflowError: Error, Equatable {
    case stageFailed
}
