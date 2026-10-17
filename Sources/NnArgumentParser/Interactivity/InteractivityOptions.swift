//
//  InteractivityOptions.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 8/9/26.
//

import ArgumentParser

/// The `--non-interactive` and `--yes` flags, for commands that would otherwise prompt for values
/// the caller didn't supply.
///
/// Declare this once on your root command. ArgumentParser validates every command in the parsed
/// chain, so that one declaration registers the resolved ``InteractionMode`` for every subcommand,
/// readable via ``InteractionMode/current``. The flags are accepted before or after the subcommand
/// name.
///
/// ```swift
/// @main
/// struct MyTool: NnRootCommand {
///     static let configuration = CommandConfiguration(subcommands: [AddUser.self])
///
///     @OptionGroup var interactivity: InteractivityOptions
/// }
/// ```
///
/// - Note: `NO_PROMPT` and a non-terminal stdin suppress prompting whether or not a command adopts
///   this type. Declaring the group on an individual command instead only changes which `--help`
///   lists the flags.
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

    /// Resolves and registers the interaction mode for the current command scope.
    ///
    /// ArgumentParser calls this automatically while decoding the enclosing command's
    /// `@OptionGroup`, and it does so for *every* command in the parsed chain as it descends —
    /// not only the one that ends up running. That is what makes both adoption styles work: the
    /// invoked subcommand can declare the group, or the root can declare it on everyone's behalf.
    ///
    /// Validation is the hook rather than `run()` because running `tool sub` never executes the
    /// root command's `run()`, so resolving the mode there would silently do nothing.
    public mutating func validate() throws {
        InteractionMode.register(nonInteractive: nonInteractive, assumeYes: yes)
    }
}
