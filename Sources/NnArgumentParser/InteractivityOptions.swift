//
//  InteractivityOptions.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 8/9/26.
//

import ArgumentParser

/// Flags that let a caller disable prompting, for commands that would otherwise ask for
/// values the caller didn't supply.
///
/// Add this to any command that prompts, and the resolved ``InteractionMode`` becomes available
/// to that command's dependencies via ``InteractionMode/current`` — no need to pass a flag value
/// down through initializers.
///
/// ## Example
///
/// ```swift
/// struct AddUser: ParsableCommand {
///     @OptionGroup var interactivity: InteractivityOptions
///
///     func run() throws {
///         // InteractionMode.current is already resolved by the time this runs
///     }
/// }
/// ```
///
/// - Note: Attaching this to a command is what makes the flags discoverable in `--help`, which
///   matters most for automated callers. Prompt suppression via `NO_PROMPT` or a non-terminal
///   stdin applies whether or not a command adopts this type.
public struct InteractivityOptions: ParsableArguments {
    /// Whether the caller explicitly disabled prompting.
    @Flag(
        name: .customLong("non-interactive"),
        help: "Never prompt for input. Required values that weren't supplied cause an error instead."
    )
    public var nonInteractive = false

    /// Whether confirmation prompts should be treated as approved.
    @Flag(
        name: .customLong("yes"),
        help: "Treat every confirmation prompt as approved. Does not disable prompting on its own."
    )
    public var yes = false

    public init() { }

    /// Resolves and registers the interaction mode for the current thread.
    ///
    /// ArgumentParser calls this automatically while decoding the enclosing command's
    /// `@OptionGroup`, which means it runs for whichever command was actually invoked. That
    /// matters for subcommands: running `tool sub` never executes the root command's `run()`,
    /// so resolving the mode there would silently do nothing.
    public mutating func validate() throws {
        InteractionMode.register(nonInteractive: nonInteractive, assumeYes: yes)
    }
}
