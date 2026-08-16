---
name: NnArgumentParser
description: NnArgumentParser Swift API reference for building testable command-line tools on top of Apple's ArgumentParser. USE WHEN importing NnArgumentParser, building a CLI root command, using the NnRootCommand protocol, ContextFactory dependency injection for commands, defaultFactory / contextFactory, the @main entry point of a Swift CLI, suppressing prompts with InteractionMode / InteractivityOptions / --non-interactive / --yes / NO_PROMPT, or testing commands end-to-end with testRun and an injected mock factory.
user-invocable: true
---

# NnArgumentParser

A thin layer over Apple's [swift-argument-parser](https://github.com/apple/swift-argument-parser) that adds a dependency-injection seam for command-line tools, so commands and subcommands get their dependencies from an injectable factory and can be tested without global mutable state.

**Dependency:** `.package(url: "https://github.com/nikolainobadi/NnArgumentParser.git", from: "0.1.0")`
**Platforms:** macOS 15+ | **Swift:** 6.0 | **Depends on:** swift-argument-parser 1.7.0+

This skill lives in the package repo it documents (`Skills/NnArgumentParser`), so an API change and its
documentation land in the same PR.

## Context Files

| File | Purpose | Load When |
|------|---------|-----------|
| `ApiReference.md` | `NnRootCommand` protocol, the `contextFactory` injection seam, `InteractionMode` / `InteractivityOptions`, and the re-exported ArgumentParser surface | Building a CLI root command, wiring the factory, `defaultFactory` vs `contextFactory`, suppressing prompts |
| `TestingReference.md` | `testRun(contextFactory:args:interactionMode:)` and the command-testing pattern (inject a mock factory, run, assert on outcomes) | Writing tests that drive whole commands end-to-end, or testing the interactivity flags |

## Quick Reference

### Production
- **NnRootCommand** — protocol refining ArgumentParser's `ParsableCommand`. Adds `associatedtype Factory` and `static var defaultFactory: Factory`. The `@main` root command conforms to it.
- **contextFactory** — `static var` (extension): returns the thread-local factory if set, else `defaultFactory`. Subcommands read it for their dependencies. Thread-local → concurrent tests are safe.
- **Factory** — *your* type (e.g. a `ContextFactory` protocol) vending the tool's infrastructure. NnArgumentParser doesn't define it.
- **@_exported ArgumentParser** — `import NnArgumentParser` re-exports all of ArgumentParser (`ParsableCommand`, `CommandConfiguration`, `@Option`, `@Flag`, `@Argument`). Don't import ArgumentParser separately.

### Interactivity
- **InteractionMode** — `enum` with `.interactive(assumeYes:)` / `.nonInteractive(assumeYes:)`. Read `InteractionMode.current` in your factory to decide between a real picker and a non-interactive one. Thread-local, like `contextFactory`.
- **InteractivityOptions** — `@OptionGroup` adding `--non-interactive` and `--yes`. Its `validate()` resolves and registers the mode, and ArgumentParser calls that for the command *actually invoked* — which is why it works for subcommands.
- **Suppressed when any of** — `--non-interactive` passed, `NO_PROMPT` set to a non-empty value, or stdin isn't a terminal (pipe, redirect, cron). The last is what makes it safe by default.
- **`--yes` ≠ `--non-interactive`** — orthogonal. `--yes` pre-approves confirmations without silencing other prompts.

### Testing
- **testRun(contextFactory:args:interactionMode:)** — from `NnArgumentParserTesting`: injects an optional factory, parses `args` against the root command, runs it, returns captured stdout (trimmed). `@discardableResult`.
- **Non-interactive by default** — `interactionMode` defaults to `.nonInteractive(assumeYes: false)` and is applied *after* parsing, so a test hitting a prompt fails rather than hanging. Pass `nil` when the test is about the flags themselves.
- **Pattern** — pass a test double of *your* `Factory` to `testRun`, run the command, assert on stdout or the outcome. NnArgumentParser is agnostic about what the factory vends; for mocking specific infrastructure (file systems, pickers) see the **NnFileKit** / **SwiftPickerKit** skills.

## Examples

- "How do I make my CLI's root command injectable?" -> Loads ApiReference.md
- "Difference between defaultFactory and contextFactory?" -> Loads ApiReference.md
- "Do I need to import ArgumentParser too?" -> Loads ApiReference.md
- "How do I stop my CLI prompting when it runs in CI?" -> Loads ApiReference.md
- "What's the difference between --yes and --non-interactive?" -> Loads ApiReference.md
- "How do I test a command end-to-end?" -> Loads TestingReference.md
- "How do I assert a command's printed output in a test?" -> Loads TestingReference.md
- "Why does my test ignore the --non-interactive flag I passed?" -> Loads TestingReference.md
