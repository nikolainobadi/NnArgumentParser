# NnArgumentParser

![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blueviolet.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey.svg)

## Overview

A Swift package that extends ArgumentParser with dependency injection support for testable CLI commands. Provides thread-local factory storage for injecting dependencies during testing without global mutable state.

## Features

- **Dependency Injection Protocol** — `NnRootCommand` protocol for commands with injectable factories
- **Non-Interactive Mode** — `InteractivityOptions` flags plus automatic detection, so prompting commands work when driven by scripts
- **Thread-Safe Testing** — Thread-local storage enables parallel test execution
- **stdout Capture** — `testRun` method captures printed output for test assertions
- **ArgumentParser Re-export** — Import `NnArgumentParser` to get full ArgumentParser access

## Requirements

- macOS 15+
- Swift 6.0+

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
    .package(url: "https://github.com/nikolainobadi/NnArgumentParser.git", branch: "main")
```

Then include it in your target:

```swift
.product(name: "NnArgumentParser", package: "NnArgumentParser")
```

For testing support, also add:

```swift
.product(name: "NnArgumentParserTesting", package: "NnArgumentParser")
```

## Usage

### Define a Root Command with Dependency Injection

```swift
import NnArgumentParser

struct MyCommand: NnRootCommand {
    typealias Factory = MyFactory
    static var defaultFactory: Factory { MyFactory() }

    @Argument var name: String

    mutating func run() throws {
        let greeter = Self.contextFactory.makeGreeter()
        print(greeter.greet(name))
    }
}
```

### Support Non-Interactive Callers

A command that prompts for values the caller didn't supply will hang when it's driven by a script
or an automated tool, where nobody is there to answer. Add `InteractivityOptions` to any command
that prompts, and build the prompting dependency from `InteractionMode.current`:

```swift
struct AddUser: ParsableCommand {
    @OptionGroup var interactivity: InteractivityOptions

    func run() throws {
        let prompter = MyCommand.contextFactory.makePrompter()
        // InteractionMode.current is already resolved by the time this runs
    }
}

struct MyFactory {
    func makePrompter() -> Prompter {
        switch InteractionMode.current {
        case .interactive:
            return TerminalPrompter()
        case .nonInteractive(let assumeYes):
            return NonInteractivePrompter(assumeYes: assumeYes)
        }
    }
}
```

Nothing between the command and the prompter needs to know which mode is active, so a command's
subcommands and services stay unchanged.

Prompting is disabled when **any** of the following is true:

| Trigger | Source |
|---------|--------|
| `--non-interactive` | A command that adopts `InteractivityOptions` |
| `NO_PROMPT` set to any non-empty value | Environment |
| Standard input is not a terminal | Pipes, redirects, scheduled jobs |

The last trigger applies to every command, whether or not it adopts the flags. Following the
`NO_COLOR` convention, `NO_PROMPT` is checked for presence rather than value — `NO_PROMPT=0`
disables prompting just as `NO_PROMPT=1` does.

`--yes` is a separate axis: it marks confirmation prompts as approved without disabling prompting.
The two combine freely — `--yes` alone at a terminal skips confirmations while other prompts still
work, and `--non-interactive --yes` disables prompting entirely with confirmations pre-approved.

### Test Commands with Injected Dependencies

```swift
import Testing
import NnArgumentParserTesting

@Test func greeting() throws {
    let output = try MyCommand.testRun(
        contextFactory: MockFactory(),
        args: ["World"]
    )
    #expect(output == "Hello, World!")
}
```

`testRun` applies `.nonInteractive` by default, so a test that reaches a prompt fails instead of
blocking the suite on input that never arrives. The mode is applied after parsing, so it takes
precedence over any interactivity flags in `args`. Pass `interactionMode:` to change it, or `nil`
to let the arguments and environment decide:

```swift
// Exercise the command's own flags
try MyCommand.testRun(args: ["--non-interactive"], interactionMode: nil)

// Exercise the interactive path
try MyCommand.testRun(args: ["World"], interactionMode: .interactive)
```

## Dependencies

- [swift-argument-parser](https://github.com/apple/swift-argument-parser) (1.7.0+)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
