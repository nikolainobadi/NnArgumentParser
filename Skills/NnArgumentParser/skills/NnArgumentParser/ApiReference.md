# NnArgumentParser API Reference

API for building testable command-line tools on top of Apple's ArgumentParser.

**Import:** `import NnArgumentParser`

---

<!-- type:NnRootCommand -->
## Protocol: NnRootCommand

The entry-point protocol for a CLI's root command. Refines `ParsableCommand` and adds a dependency-injection seam.

```swift
public protocol NnRootCommand: ParsableCommand {
    associatedtype Factory
    static var defaultFactory: Factory { get }
}
```

### Requirements

| Member | Type | Description |
|--------|------|-------------|
| `Factory` | `associatedtype` | The type that creates dependencies for this command and its subcommands. You define it (commonly a `ContextFactory` protocol). |
| `defaultFactory` | `static var Factory { get }` | The factory used in production when no test factory is injected. |

### Provided by Extension

| Member | Type | Description |
|--------|------|-------------|
| `contextFactory` | `static var Factory { get set }` | The active factory. Getter returns the thread-local value if set, else `defaultFactory`. Setter stores it in `Thread.current.threadDictionary`, keyed per command type. |

### Behavioral Notes

- **Thread-local injection** — `contextFactory` is backed by `Thread.current.threadDictionary` under key `"\(Self.self).contextFactory"`. Production reads `defaultFactory`; tests set a mock for the current thread only. No global mutable state → parallel tests are safe.
- **You own `Factory`** — NnArgumentParser places no constraint on it. A common convention is a `ContextFactory` protocol with `make…()` accessors for infrastructure, plus static helpers on the root command that delegate to `contextFactory`.
- **Subcommands reach the factory through the root type** — e.g. `MyTool.makeGreeter()` resolves `MyTool.contextFactory.makeGreeter()`. ArgumentParser constructs subcommand values itself, so this static seam is how injected dependencies reach them.

### Usage Example

```swift
import NnArgumentParser

@main
struct MyTool: NnRootCommand {
    static let configuration = CommandConfiguration(
        abstract: "An example command-line tool.",
        subcommands: [Greet.self]
    )

    static var defaultFactory: any Dependencies {
        return LiveDependencies()
    }
}

// Static accessor subcommands use to reach a dependency.
extension MyTool {
    static func makeGreeter() -> any Greeter {
        return contextFactory.makeGreeter()
    }
}

// You define the factory type — NnArgumentParser puts no constraints on it.
protocol Dependencies {
    func makeGreeter() -> any Greeter
}

struct Greet: ParsableCommand {
    @Option var name: String

    func run() throws {
        print(MyTool.makeGreeter().greeting(for: name))
    }
}
```
<!-- /type:NnRootCommand -->

---

<!-- type:InteractionMode -->
## Enum: InteractionMode

Whether a command may prompt the user for input. Decided once at the composition root instead of at every prompt.

```swift
public enum InteractionMode: Sendable, Equatable {
    case interactive(assumeYes: Bool)
    case nonInteractive(assumeYes: Bool)
}
```

Both cases carry `assumeYes` because suppressing prompts and pre-approving confirmations are **independent** choices. `tool delete --yes` at a terminal skips the confirmation while other prompts still work; a command that can't prompt at all still needs to know whether an unanswered confirmation means yes or no.

### Helpers

| Member | Type | Description |
|--------|------|-------------|
| `isInteractive` | `var Bool` | Whether prompting is allowed. `true` only for `.interactive`. |
| `assumeYes` | `var Bool` | The associated value from either case. Independent of `isInteractive`. |

### Storage (thread-local)

| Member | Type | Description |
|--------|------|-------------|
| `current` | `static var InteractionMode` | The mode for the current thread. Falls back to `resolve()` when nothing was registered, so environment and terminal checks still apply. |
| `register(_:)` | `static func (InteractionMode)` | Records the mode for the current thread. |
| `register(nonInteractive:assumeYes:)` | `static func (Bool, Bool)` | Resolves from flag values, then registers. The bridge from argument parsing to `current`. |
| `reset()` | `static func ()` | Clears the thread's mode. Thread dictionaries outlive a run, so tests that register should clear. |

Backed by `Thread.current.threadDictionary`, matching `NnRootCommand.contextFactory` — parallel tests don't interfere.

### Resolution

| Member | Type | Description |
|--------|------|-------------|
| `noPromptEnvironmentKey` | `static var String` | `"NO_PROMPT"`. Follows the `NO_COLOR` convention: **presence** matters, not value — `NO_PROMPT=0` suppresses just as `NO_PROMPT=1` does. Unset it to re-enable. |
| `resolve(nonInteractive:assumeYes:environment:isTerminal:)` | `static func -> InteractionMode` | Determines the mode. All params default; `environment` defaults to the process environment and `isTerminal` to a live `isatty(STDIN_FILENO)` check. |

Prompting is suppressed when **any** of these holds:

1. `nonInteractive` is `true` (caller passed `--non-interactive`)
2. `NO_PROMPT` is set to a non-empty value
3. stdin is not a terminal — a pipe, a redirect, or a scheduled job

Condition 3 is what makes this safe by default: with no terminal there's no one to answer, so a prompting command would hang or eat its own input. Detecting that can't break a working invocation, because there wasn't one.

### Usage Example

```swift
// In your factory — read the mode where prompt-driven dependencies are built.
func makePicker() -> any Picker {
    switch InteractionMode.current {
    case .interactive:
        return SwiftPicker()
    case .nonInteractive(let assumeYes):
        return NonInteractivePicker(assumeYes: assumeYes)
    }
}
```
<!-- /type:InteractionMode -->

---

<!-- type:InteractivityOptions -->
## Struct: InteractivityOptions

An `@OptionGroup` that exposes the interactivity flags on a command and registers the resolved mode.

```swift
public struct InteractivityOptions: ParsableArguments {
    @Flag(name: .customLong("non-interactive")) public var nonInteractive = false
    @Flag(name: .customLong("yes"))             public var yes = false
    public init()
    public mutating func validate() throws
}
```

| Flag | Help |
|------|------|
| `--non-interactive` | Never prompt for input. Required values that weren't supplied cause an error instead. |
| `--yes` | Treat every confirmation prompt as approved. **Does not disable prompting on its own.** |

### Behavioral Notes

- **`validate()` is the hook** — ArgumentParser calls it automatically while decoding the enclosing command's `@OptionGroup`, and it does so for *every command in the parsed chain* as it descends (`CommandParser.descendingParse`), not only the one that ends up running. Validation is the hook rather than `run()` because running `tool sub` never executes the root command's `run()`, so resolving the mode there would silently do nothing.
- **Adopting the type is about discoverability** — it puts the flags in *that command's* `--help`, which matters most for automated callers. Suppression via `NO_PROMPT` or a non-terminal stdin applies whether or not a command adopts it.
- **There is no protocol that supplies the flags for you** — ArgumentParser finds arguments by reflecting over the concrete type's *stored properties*, and Swift protocol extensions can't add stored properties. Conforming to some `InteractivityAware` protocol could never make the `@OptionGroup` exist. Declare it on the root instead (below); that's the way to avoid repeating it.

### Where to declare it

| Style | Declaration | Registers mode for | Flags listed in |
|-------|-------------|--------------------|-----------------|
| **Root-only** (fewest declarations) | Once, on the root command | Every subcommand | `tool --help` only |
| **Per-command** | On each command that prompts | That command | Each adopting command's `--help` |

Root-only works because the chain is validated top-down, and the flags are accepted in **either position** — `tool --non-interactive add-user` and `tool add-user --non-interactive` both register the same mode. The trade is that only root help advertises them, and every subcommand accepts them whether or not it prompts.

### Usage Example

Root-only — no subcommand declares anything:

```swift
@main
struct MyTool: NnRootCommand {
    static let configuration = CommandConfiguration(subcommands: [AddUser.self])

    @OptionGroup var interactivity: InteractivityOptions

    static var defaultFactory: any Dependencies { LiveDependencies() }
}

struct AddUser: ParsableCommand {
    func run() throws {
        // InteractionMode.current is already resolved by the time this runs.
        let picker = MyTool.makePicker()
    }
}
```

Per-command — when `add-user --help` should list the flags itself:

```swift
struct AddUser: ParsableCommand {
    @OptionGroup var interactivity: InteractivityOptions

    func run() throws {
        let picker = MyTool.makePicker()
    }
}
```
<!-- /type:InteractivityOptions -->

---

## Re-exported ArgumentParser

`NnArgumentParser` declares `@_exported import ArgumentParser`, so a single `import NnArgumentParser` brings in the full ArgumentParser surface — `ParsableCommand`, `CommandConfiguration`, `@Option`, `@Flag`, `@Argument`, `ExpressibleByArgument`, etc. Do **not** add a separate `import ArgumentParser`.

## Best Practices

- **Conform only the root command to `NnRootCommand`.** Subcommands stay plain `ParsableCommand`s and reach dependencies via the root type's static accessors.
- **Keep `Factory` an infrastructure seam, not a service locator.** Vend primitives (shell, file system, picker); let each command assemble its feature locally.
- **Never import ArgumentParser directly** — it arrives via `NnArgumentParser`.
- **Don't set `contextFactory` in production** — production relies on `defaultFactory`; the setter exists for tests.
- **Read `InteractionMode.current` in the factory, not in `run()`.** The point of the thread-local is that the flag value doesn't have to be threaded through initializers.
- **Declare `@OptionGroup var interactivity: InteractivityOptions` once on the root command.** The whole chain is validated, so every subcommand gets the mode registered without repeating the property. Add it per-command only when each subcommand's own `--help` must list the flags.
- **Don't try to factor it into a protocol.** ArgumentParser reflects over stored properties; a protocol can't add one. Root-only declaration is the way to stop repeating it.
- **Don't treat `--yes` as implying `--non-interactive`.** They're orthogonal; `assumeYes` is carried by both cases for exactly that reason.
