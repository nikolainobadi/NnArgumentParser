# NnArgumentParser

![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blueviolet.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey.svg)

A thin layer over Apple's [swift-argument-parser](https://github.com/apple/swift-argument-parser)
that makes command-line tools testable.

## Why

ArgumentParser constructs your command values for you. That's convenient until a command needs a
dependency — a network client, a file system, a prompt — because there's no initializer to inject
it through. The usual workaround is a global `var` that tests reassign, which breaks the moment
tests run in parallel.

NnArgumentParser adds one seam: a **factory**, resolved through thread-local storage. Production
reads the default; a test sets its own for the current thread only. Nothing is shared between
threads, so parallel tests don't interfere.

It also handles the other thing CLIs get wrong — prompting for input when nobody is there to
answer. See [Non-Interactive Callers](#supporting-non-interactive-callers).

## Features

- **Dependency injection** — `NnRootCommand` gives commands an injectable factory with no global state
- **Parallel-safe** — thread-local storage, so concurrent tests can't clobber each other
- **End-to-end testing** — `testRun` parses arguments, runs the command, and returns its stdout
- **Non-interactive mode** — `InteractivityOptions` flags plus automatic detection of pipes, redirects, and CI
- **ArgumentParser re-export** — one import gets you both

## Requirements

- macOS 15+
- Swift 6.0+

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/nikolainobadi/NnArgumentParser.git", from: "0.1.0")
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
        print(MyTool.makeGreeter().greeting(for: name))
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
| `contextFactory` | Provided for you. Returns the thread-local factory if one was set, otherwise `defaultFactory`. | Everything reads this |

Always read `contextFactory`. Never set it in production code — `testRun` sets it, and that's the
only thing that should.

### Conform only the root command

Subcommands stay plain `ParsableCommand`s. One conformance, at the `@main` type, is all you need.

### Keep the factory an infrastructure seam

Vend primitives — a shell, a file system, a picker — and let each command assemble its own feature
from them. A factory with a method per feature becomes a service locator, and every command ends up
depending on all of it.

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

`testRun` parses arguments against the root command, runs the resolved command, and returns its
trimmed stdout:

```swift
import Testing
import NnArgumentParserTesting

@Test func greetsTheProvidedName() throws {
    let output = try MyTool.testRun(
        contextFactory: MockDependencies(),
        args: ["greet", "Ada"]
    )

    #expect(output == "Hello, Ada!")
}

struct MockDependencies: Dependencies {
    func makeGreeter() -> any Greeter { StubGreeter() }
}
```

Errors thrown by `run()` are rethrown, so `#expect(throws:)` works as usual.

### Tests are non-interactive by default

`testRun` applies `.nonInteractive(assumeYes: false)` unless told otherwise, so a test that reaches
a prompt fails instead of blocking the suite on input that never arrives. This works only to the
extent that your factory consults `InteractionMode.current`.

The mode is applied **after** parsing, so it overrides interactivity flags in `args`. To test the
flags themselves, pass `nil`:

```swift
// Let the parsed --non-interactive flag decide
try MyTool.testRun(args: ["add-user", "--non-interactive"], interactionMode: nil)

// Exercise the interactive path explicitly
try MyTool.testRun(args: ["add-user"], interactionMode: .interactive(assumeYes: false))
```

`testRun` resets the mode when it finishes, so nothing leaks into the next test on that thread.

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

- [swift-argument-parser](https://github.com/apple/swift-argument-parser) (1.7.0+)

## License

MIT — see [LICENSE](LICENSE).
