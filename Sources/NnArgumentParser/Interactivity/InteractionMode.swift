//
//  InteractionMode.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 8/9/26.
//

/// Describes whether a command may prompt the user for input.
///
/// Commands frequently ask for values the caller didn't supply as arguments. That works
/// when a person is at the terminal, but fails when the command is driven by a script or
/// an automated tool, where no input is possible. This type captures that distinction so
/// the decision can be made once, at the composition root, instead of at every prompt.
///
/// ## Example
///
/// ```swift
/// switch InteractionMode.current {
/// case .interactive:
///     picker = SwiftPicker()
/// case .nonInteractive(let assumeYes):
///     picker = NonInteractivePicker(assumeYes: assumeYes)
/// }
/// ```
///
/// - Note: Both cases carry `assumeYes` because suppressing prompts and pre-approving
///   confirmations are independent choices. Someone at a terminal running `tool delete --yes`
///   expects the confirmation skipped while other prompts still work, and a command that can't
///   prompt at all still needs to know whether an unanswered confirmation means "yes" or "no".
public enum InteractionMode: Sendable, Equatable {
    /// Prompting is allowed; a person is expected to answer.
    ///
    /// - Parameter assumeYes: Whether confirmation prompts should be treated as approved.
    ///   When `true`, confirmations are skipped even though other prompts are still shown.
    case interactive(assumeYes: Bool)

    /// Prompting is not allowed.
    ///
    /// - Parameter assumeYes: Whether confirmation prompts should be treated as approved.
    ///   When `false`, a required confirmation fails rather than proceeding.
    case nonInteractive(assumeYes: Bool)
}

// MARK: - Helpers
public extension InteractionMode {
    /// Whether the command may prompt the user for input.
    var isInteractive: Bool {
        switch self {
        case .interactive:
            return true
        case .nonInteractive:
            return false
        }
    }

    /// Whether confirmation prompts should be treated as approved.
    ///
    /// Independent of ``isInteractive``: a caller can skip confirmations while still being able
    /// to answer other prompts.
    var assumeYes: Bool {
        switch self {
        case .interactive(let assumeYes), .nonInteractive(let assumeYes):
            return assumeYes
        }
    }
}
