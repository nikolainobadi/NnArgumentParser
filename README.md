# NnArgumentParser

![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blueviolet.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey.svg)

A thin layer over Apple's [swift-argument-parser](https://github.com/apple/swift-argument-parser)
that makes command-line tools testable.

## Why

ArgumentParser constructs your command values for you. That's convenient until a command needs a
dependency — a network client, a file system, a prompt — because there's no initializer to inject
it through. The usual workaround is a global `var` that tests reassign, which breaks the moment
tests run in parallel.

NnArgumentParser adds one seam: a **factory**, resolved through a task-local command scope. Production
reads the default; each test run injects its own. The scope follows the command across `await`s
and into child tasks, so parallel test runs keep their state separate.

It also handles the other thing CLIs get wrong — prompting for input when nobody is there to
answer. See [Non-Interactive Callers](#supporting-non-interactive-callers).

## Features

- **Dependency injection** — `NnRootCommand` gives commands an injectable factory with no global state
- **Parallel-safe** — task-local command scopes keep each run's factory, interaction mode, and output separate
- **End-to-end testing** — async `testRun` parses arguments, runs sync or async commands, and captures `NnOutput` writes
- **Custom output** — `NnOutput.register(writer:)` routes output through an app-provided `NnOutputWriter`
- **Interrupt cleanup** — `NnInterrupt.register(cleanup:)` registers teardown for SIGINT and SIGTERM
- **Completion observers** — `NnCompletion.register(observer:)` tells the tool whether its run succeeded or failed, before a failure is reported
- **Non-interactive mode** — `InteractivityOptions` flags plus automatic detection of pipes, redirects, and CI
- **Case-insensitive enums** — `CaseInsensitiveArgument` accepts any letter casing for enum arguments
- **Key-value options** — `KeyValueArgument` parses repeatable `<key>=<value>` options
- **Composable command workflows** — `NnWorkflow` runs typed stages in order, with async inspection and resolution; `NnWorkflowCommand` provides async command execution
- **ArgumentParser re-export** — one import gets you both

## Requirements

- macOS 15+
- Swift 6.2+

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/nikolainobadi/NnArgumentParser.git", from: "1.1.0")
```

Then add the product to your target:

```swift
.product(name: "NnArgumentParser", package: "NnArgumentParser")
```

And to your **test** target:

```swift
.product(name: "NnArgumentParserTesting", package: "NnArgumentParser")
```

> `import NnArgumentParser` re-exports all of ArgumentParser — `ParsableCommand`,
> `CommandConfiguration`, `@Option`, `@Flag`, `@Argument`. Don't import ArgumentParser separately.

## Quick Start

Define the dependencies your tool needs. This type is entirely yours — NnArgumentParser places no
constraints on it:

```swift
protocol Dependencies {
    func makeGreeter() -> any Greeter
}

struct LiveDependencies: Dependencies {
    func makeGreeter() -> any Greeter { DefaultGreeter() }
}
```

Conform your **root** command to `NnRootCommand` and point it at that factory:

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
```

Subcommands reach dependencies through the root type. Add a static accessor for each one:

```swift
extension MyTool {
    static func makeGreeter() -> any Greeter {
        return contextFactory.makeGreeter()
    }
}

struct Greet: ParsableCommand {
    @Argument var name: String

    func run() throws {
        NnOutput.write(MyTool.makeGreeter().greeting(for: name))
    }
}
```

ArgumentParser builds `Greet` itself, so there's no initializer to inject through — the static
accessor on the root type is how the dependency gets there.

## Core Concepts

### `defaultFactory` vs `contextFactory`

| | What it is | Who uses it |
|---|---|---|
| `defaultFactory` | You implement it. The real dependencies. | Production |
| `contextFactory` | Provided for you. Returns the factory injected into the current command scope, otherwise `defaultFactory`. | Everything reads this |

Always read `contextFactory`; its setter is package-only. The root command's `main()` creates the
production scope, and `testRun` creates a fresh scope for each test. Reading `contextFactory` outside
a scope, including from `Task.detached`, traps. Task-group children and `Task { }` inherit the scope.

### Conform only the root command

`NnRootCommand` inherits `AsyncParsableCommand`. Subcommands can use `ParsableCommand` for
synchronous work or `AsyncParsableCommand` for async work. Only the root needs `NnRootCommand`.

### Keep the factory an infrastructure seam

Vend primitives — a shell, a file system, a picker — and let each command assemble its own feature
from them. A factory with a method per feature becomes a service locator, and every command ends up
depending on all of it.

## Parsing Common Argument Shapes

### Case-insensitive enum arguments

Conform a `String`-backed, `CaseIterable` enum to `CaseInsensitiveArgument` to accept values in any
letter casing:

```swift
enum DiscardScope: String, CaseIterable, CaseInsensitiveArgument {
    case staged, unstaged, both
}

struct Discard: ParsableCommand {
    @Option var scope: DiscardScope = .both
}
```

With this conformance, `--scope staged`, `--scope Staged`, and `--scope STAGED` all parse as
`.staged`. Only command-line parsing becomes case-insensitive; help, shell completion,
`init?(rawValue:)`, and synthesized `Codable` conformance continue to use the exact raw values.

### Key-value options

Use `KeyValueArgument` for repeatable `<key>=<value>` options, then call `asDictionary()` to collect
them:

```swift
struct BuildOptions: ParsableArguments {
    @Option(name: .customLong("build-command"), parsing: .singleValue, help: "A target's build command, as <target>=<command>.")
    var build: [KeyValueArgument] = []

    var buildCommands: [String: String] {
        return build.asDictionary()
    }
}
```

Parsing splits on the first `=` only, so a value can contain additional `=` characters. Both the
key and value must be non-empty, surrounding whitespace is preserved, and when a key is repeated,
`asDictionary()` keeps its last value.

## Supporting Non-Interactive Callers

A command that prompts for values the caller didn't supply will hang when driven by a script or a
scheduled job, where nobody is there to answer. Declare `InteractivityOptions` on your root command,
and build the prompting dependency from `InteractionMode.current`:

```swift
@main
struct MyTool: NnRootCommand {
    static let configuration = CommandConfiguration(subcommands: [AddUser.self])

    @OptionGroup var interactivity: InteractivityOptions

    static var defaultFactory: any Dependencies {
        return LiveDependencies()
    }
}

struct AddUser: ParsableCommand {
    func run() throws {
        let prompter = MyTool.makePrompter()
        // InteractionMode.current is already resolved by the time this runs
    }
}

struct LiveDependencies: Dependencies {
    func makePrompter() -> any Prompter {
        switch InteractionMode.current {
        case .interactive:
            return TerminalPrompter()
        case .nonInteractive(let assumeYes):
            return NonInteractivePrompter(assumeYes: assumeYes)
        }
    }
}
```

`AddUser` declares nothing. `InteractivityOptions` resolves the mode in `validate()`, and
ArgumentParser calls that for *every* command in the parsed chain — not only the one that runs — so
one declaration on the root covers every subcommand. The flags work in either position:
`tool --non-interactive add-user` and `tool add-user --non-interactive` are equivalent.

Nothing between the command and the prompter needs to know which mode is active, so subcommands and
services stay unchanged.

Prompting is disabled when **any** of the following is true:

| Trigger | Source |
|---------|--------|
| `--non-interactive` | A command that adopts `InteractivityOptions` |
| `NO_PROMPT` set to any non-empty value | Environment |
| Standard input is not a terminal | Pipes, redirects, scheduled jobs |

The last applies to every command, whether or not it adopts the flags — which is what makes it safe
by default. Following the `NO_COLOR` convention, `NO_PROMPT` is checked for presence rather than
value, so `NO_PROMPT=0` disables prompting just as `NO_PROMPT=1` does.

`--yes` is a separate axis: it marks confirmation prompts as approved without disabling prompting.
The two combine freely — `--yes` alone at a terminal skips confirmations while other prompts still
work, and `--non-interactive --yes` disables prompting entirely with confirmations pre-approved.

> Declaring `InteractivityOptions` per-command is still worth it when that command's own `--help`
> should list the flags — root-only declaration puts them in `tool --help` alone. The trade-off is
> that a root declaration also makes every subcommand accept the flags, whether or not it prompts.

## Testing

`import NnArgumentParserTesting` also re-exports `NnArgumentParser`. For workflow tests,
it adds `knownValue` and `unknownInfo` accessors to `NnRequirement`: each returns the
associated value for its matching case, or `nil` for the other case.

`testRun` asynchronously parses arguments against the root command, runs the resolved command,
and returns trimmed output written through `NnOutput.write(_:)`. Plain `print` calls are not
captured. All three arguments are required; pass `nil` for `contextFactory` to use the default factory:

```swift
import Testing
import NnArgumentParserTesting

@Test func greetsTheProvidedName() async throws {
    let output = try await MyTool.testRun(contextFactory: MockDependencies(), args: ["greet", "Ada"], interactionMode: .nonInteractive(assumeYes: false))

    #expect(output == "Hello, Ada!")
}

struct MockDependencies: Dependencies {
    func makeGreeter() -> any Greeter { StubGreeter() }
}
```

Errors thrown by `run()` are rethrown, so `#expect(throws:)` works as usual.

### Choose the test interaction mode

Pass `.nonInteractive(assumeYes: false)` to keep a test that reaches a prompt from blocking the
suite on input that never arrives. There is no default argument for the mode. This works only to
the extent that your factory consults `InteractionMode.current`.

The mode is applied **after** parsing, so it overrides interactivity flags in `args`. To test the
flags themselves, pass `nil`:

```swift
// Let the parsed --non-interactive flag decide
try await MyTool.testRun(contextFactory: nil, args: ["add-user", "--non-interactive"], interactionMode: nil)

// Exercise the interactive path explicitly
try await MyTool.testRun(contextFactory: nil, args: ["add-user"], interactionMode: .interactive(assumeYes: false))
```

`testRun` discards its command scope when it finishes, so the mode does not leak into another run.
For tests that register a mode or read command state directly, use `withIsolatedState { ... }`, or
`MyTool.withIsolatedState(contextFactory: MockDependencies()) { ... }` to inject a factory. Both
helpers support sync and async bodies.

`testRun` captures `NnOutput` writes even when the command registers a custom writer. It installs
no signal handlers; registered interrupt cleanups are discarded without running. To test a cleanup,
use `testRunCapturingCleanups`, which takes the same arguments and returns an `NnTestRunResult`
holding the output and the registered cleanups, last registered first. None has run; call them,
then assert on your fakes:

```swift
let result = try await MyTool.testRunCapturingCleanups(contextFactory: factory, args: ["watch"], interactionMode: .nonInteractive(assumeYes: false))
result.interruptCleanups.forEach { $0() }
#expect(factory.terminal.wasRestored)
```

### Mocking infrastructure

NnArgumentParser only requires that your factory can be swapped for a test double; it's agnostic
about what the factory vends. Test doubles for common infrastructure ship with their own packages —
[NnFileKit](https://github.com/nikolainobadi/NnFileKit) for file systems,
[NnShellKit](https://github.com/nikolainobadi/NnShellKit) for shell execution, and
[SwiftPickerKit](https://github.com/nikolainobadi/SwiftPickerKit) for interactive pickers. Have your
factory's test double vend those, then inject it through `testRun`.

## API Reference for Claude Code

`Skills/NnArgumentParser` is a [Claude Code](https://claude.com/claude-code) skill documenting this
package's full API. It lives in this repo so the docs change in the same PR as the API they
describe. To use it:

```
/plugin marketplace add nikolainobadi/nn-swift-skills
/plugin install NnArgumentParser@nn-swift-skills
```

Claude then loads the reference automatically when you're working with this package.

## Dependencies

- [swift-argument-parser](https://github.com/apple/swift-argument-parser) (1.8.2+)

## License

MIT — see [LICENSE](LICENSE).
