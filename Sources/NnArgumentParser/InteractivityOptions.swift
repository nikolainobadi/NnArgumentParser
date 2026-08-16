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
/// ## Declaring it once on the root
///
/// ArgumentParser validates *every* command in the parsed chain, not only the one that runs, so a
/// single declaration on the root registers the mode for every subcommand — none of them need to
/// declare anything:
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
/// The flags are accepted in either position — `tool --non-interactive add-user` and
/// `tool add-user --non-interactive` both register the same mode.
///
/// The trade is discoverability: only `tool --help` lists the flags, and every subcommand accepts
/// them whether or not it prompts. Declare it per-command instead when each subcommand's own
/// `--help` should advertise them.
///
/// - Note: Attaching this to a command is what makes the flags discoverable in that command's
///   `--help`, which matters most for automated callers. Prompt suppression via `NO_PROMPT` or a
///   non-terminal stdin applies whether or not a command adopts this type.
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
