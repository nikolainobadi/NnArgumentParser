---
name: NnArgumentParser
description: NnArgumentParser Swift API reference for building testable command-line tools on top of Apple's ArgumentParser. USE WHEN importing NnArgumentParser, building a CLI root command, using the NnRootCommand protocol, ContextFactory dependency injection for commands, defaultFactory / contextFactory, the @main entry point of a Swift CLI, suppressing prompts with InteractionMode / InteractivityOptions / --non-interactive / --yes / NO_PROMPT, parsing enum options case-insensitively with CaseInsensitiveArgument, parsing <key>=<value> options with KeyValueArgument, structuring a command as an inspect/collect/resolve pipeline with NnWorkflow / NnWorkflowCommand / NnRequirement / NnCommandInspector / NnCommandCollector / NnCommandResolver, testing workflows with MockCommandInspector / MockCommandCollector / MockCommandResolver, routing output with NnOutput / NnOutputWriter, registering interrupt cleanup with NnInterrupt, isolating test state with withIsolatedState, or testing commands end-to-end with testRun and an injected mock factory.
user-invocable: true
---

# NnArgumentParser

A thin layer over Apple's [swift-argument-parser](https://github.com/apple/swift-argument-parser) that adds a dependency-injection seam for command-line tools, so commands and subcommands get their dependencies from an injectable factory and can be tested without global mutable state.

**Dependency:** `.package(url: "https://github.com/nikolainobadi/NnArgumentParser.git", from: "1.0.0")`
**Platforms:** macOS 15+ | **Swift:** 6.2 | **Depends on:** swift-argument-parser 1.8.2+

This skill lives in the package repo it documents (`Skills/NnArgumentParser`), so an API change and its
documentation land in the same PR.

## Context Files

| File | Purpose | Load When |
|------|---------|-----------|
| `ApiReference.md` | `NnRootCommand` protocol, the `contextFactory` injection seam, `InteractionMode` / `InteractivityOptions`, `NnOutput` / `NnOutputWriter`, `NnInterrupt`, and the re-exported ArgumentParser surface | Building a CLI root command, wiring the factory, `defaultFactory` vs `contextFactory`, suppressing prompts, routing output, cleaning up on interrupt |
| `WorkflowReference.md` | `NnWorkflow` and its five stage protocols, `NnInspection`, `NnRequirement`, `NnWorkflowError`, the passthrough stages, `NnWorkflowCommand`, and what each stage may and may not do | Structuring a command's `run()` as inspect → collect → resolve, asking only for missing input, wiring a workflow in `makeWorkflow()` |
| `TestingReference.md` | `testRun(contextFactory:args:interactionMode:)`, the command-testing pattern (inject a mock factory, run, assert on outcomes), `withIsolatedState`, and the workflow stage mocks | Writing tests that drive whole commands end-to-end, testing the interactivity flags, or testing a workflow's stages |

## Quick Reference

### Production
- **NnRootCommand** — protocol refining ArgumentParser's `AsyncParsableCommand`. Adds `associatedtype Factory` and `static var defaultFactory: Factory`. The `@main` root command conforms to it.
- **contextFactory** — publicly read-only `static var`: returns the factory injected into the command scope, else `defaultFactory`. The root’s async `main()` and `testRun` install the scope. It survives `await` and is inherited by task-group children and `Task { }`, but not `Task.detached`; reading the factory outside a scope traps.
- **Factory** — *your* type (e.g. a `ContextFactory` protocol) vending the tool's infrastructure. NnArgumentParser doesn't define it.
- **@_exported ArgumentParser** — `import NnArgumentParser` re-exports all of ArgumentParser (`ParsableCommand`, `CommandConfiguration`, `@Option`, `@Flag`, `@Argument`). Don't import ArgumentParser separately.

### Output and interrupts
- **NnOutput.write(_:)** — prints a line in production, routes to a registered `NnOutputWriter`, or captures into the current `testRun` buffer. Capture takes precedence over a writer. Writes are dropped once that production run is interrupting.
- **NnOutput.register(writer:)** — requires a command scope. Writers are `Sendable`, deliver synchronously in call order, support concurrent calls, and add their own line ending.
- **NnInterrupt.register(cleanup:)** — registers a synchronous `@Sendable` cleanup in the command scope. Production `main()` runs cleanups last-registered-first on SIGINT/SIGTERM. `testRun` installs no signal handlers and discards cleanups without running them.

### Interactivity
- **InteractionMode** — `enum` with `.interactive(assumeYes:)` / `.nonInteractive(assumeYes:)`. Read `InteractionMode.current` in your factory to decide between a real picker and a non-interactive one. Stored in the command scope; outside a scope, reads fall back to environment and terminal resolution. Registration requires a scope. There is no `reset()`.
- **InteractivityOptions** — `@OptionGroup` adding `--non-interactive` and `--yes`. Its `validate()` resolves and registers the mode, and ArgumentParser calls that for *every command in the parsed chain* — which is why it works for subcommands.
- **Declare it once on the root** — because the whole chain is validated, one `@OptionGroup` on the root registers the mode for every subcommand, in either flag position. Trade: only root `--help` lists the flags. Per-command declaration is for when each subcommand's own help must advertise them.
- **No protocol can supply it** — ArgumentParser reflects over stored properties, and Swift protocols can't add one. Root-only declaration is the way to avoid repeating the property.
- **Suppressed when any of** — `--non-interactive` passed, `NO_PROMPT` set to a non-empty value, or stdin isn't a terminal (pipe, redirect, cron). The last is what makes it safe by default.
- **`--yes` ≠ `--non-interactive`** — orthogonal. `--yes` pre-approves confirmations without silencing other prompts.

### Arguments
- **CaseInsensitiveArgument** — marker protocol for a `String`-raw `CaseIterable` enum. Conform and `--scope STAGED` parses like `--scope staged`. Replaces the hand-written `switch argument.lowercased()`.
- **Only parsing loosens** — `--help`, shell completion, `init?(rawValue:)` and synthesized `Codable` still use the exact `rawValue`. Accepting `--format JSON` does not make a config file accept `"JSON"`.
- **Exact match wins first** — so an enum with raw values differing only by case (`"run"`/`"RUN"`) keeps both reachable.
- **Requires `CaseIterable`** — adding that retroactively to another package's type means hand-writing `allCases`, which goes stale silently. Adopt only where it already exists.
- **KeyValueArgument** — a `<key>=<value>` pair. Splits on the **first** `=`, so values may contain `=` (`core=swift test --filter=Foo`). Rejects a missing separator or an empty half. Whitespace is kept.
- **`[KeyValueArgument].asDictionary()`** — folds pairs into `[String: String]`; a repeated key resolves to the last value.
- **Put the shape in your help string** — `KeyValueArgument` can't describe itself in `--help` or in its parse error, so write `help: "... as <target>=<command>."`

### Workflows
- **NnWorkflow** — five stages with type-checked hand-offs: `inspector` → `inspectionInterpreter` → `collector` → `collectionInterpreter` → `resolver`. `run()` is `async throws`; the extension awaits inspection and resolution in order and returns `Results`; the first throw stops the run.
- **Stage jobs** — *Inspect* gathers facts and makes no decisions. *Collect* prompts only for **missing** info, and it's optional. *Resolve* does the work through use cases, which may prompt only for **additional** info that comes up mid-work. The interpreters make the decisions.
- **NnInspection<Findings, Requirements>** — what the inspection interpreter returns. Findings skip the collector; requirements go to it.
- **NnRequirement<Value, Info>** — `.known(Value)` or `.unknown(Info)`. `ask(_:)` (collector) prompts only when unknown and returns `nil` when known. `resolve(answer:)` (collection interpreter) returns the known value or the answer, or throws `NnWorkflowError.missingAnswer`.
- **Passthrough stages** — `NnPassthroughCollector` plus `NnPassthroughCollectionInterpreter<Findings>` for commands that ask nothing. The findings become the resolver's context.
- **NnWorkflowCommand** — an `AsyncParsableCommand` that implements `makeWorkflow()` (its composition root) and `handleResults(_:)` (printing). Async `run()` is provided; use `NnOutput.write` in `handleResults(_:)`.

### Testing
- **withIsolatedState** — from `NnArgumentParserTesting`, scopes synchronous or async test code that reads or registers command state outside `testRun`. Use `MyTool.withIsolatedState(contextFactory:_:)` to inject a factory; callers cannot assign `contextFactory` directly.
- **testRun(contextFactory:args:interactionMode:)** — from `NnArgumentParserTesting`: is `async throws` and requires all three arguments explicitly. Injects an optional factory, parses `args` against the root command, runs it, and returns only captured `NnOutput.write` output (trimmed); plain `print` is not captured. `@discardableResult`.
- **Choose non-interactive explicitly** — pass `interactionMode: .nonInteractive(assumeYes: false)` to keep prompt-aware dependencies from waiting for input. The override is applied *after* parsing. Pass `nil` when the test is about the flags themselves.
- **Workflow mocks** — `MockCommandInspector(facts:throwError:)`, `MockCommandCollector(answers:throwError:)`, `MockCommandResolver(results:throwError:)` record `inspectCallCount` / `capturedRequirements` / `capturedContexts`. When `throwError` is true they throw `MockWorkflowError.stageFailed`. Interpreters have no mocks; test them directly.
- **Pattern** — pass a test double of *your* `Factory` to `testRun`, run the command, assert on captured output or the outcome. NnArgumentParser is agnostic about what the factory vends; for mocking specific infrastructure (file systems, pickers) see the **NnFileKit** / **SwiftPickerKit** skills.

## Examples

- "How do I make my CLI's root command injectable?" -> Loads ApiReference.md
- "Difference between defaultFactory and contextFactory?" -> Loads ApiReference.md
- "Do I need to import ArgumentParser too?" -> Loads ApiReference.md
- "How do I stop my CLI prompting when it runs in CI?" -> Loads ApiReference.md
- "What's the difference between --yes and --non-interactive?" -> Loads ApiReference.md
- "Can I avoid adding InteractivityOptions to every command?" -> Loads ApiReference.md
- "Can a protocol give my commands the interactivity flags automatically?" -> Loads ApiReference.md
- "How do I make my CLI accept --scope STAGED as well as staged?" -> Loads ApiReference.md
- "Why does my enum option reject uppercase values?" -> Loads ApiReference.md
- "How do I parse a --define key=value option?" -> Loads ApiReference.md
- "How do I collect repeated key=value flags into a dictionary?" -> Loads ApiReference.md
- "How should I structure a command that checks state, prompts, then does work?" -> Loads WorkflowReference.md
- "How do I only prompt for values the user didn't pass as flags?" -> Loads WorkflowReference.md
- "What's the difference between findings and requirements?" -> Loads WorkflowReference.md
- "My command has nothing to ask. Do I need a collector?" -> Loads WorkflowReference.md
- "Why am I getting NnWorkflowError.missingAnswer?" -> Loads WorkflowReference.md
- "How do I test a workflow's interpreters and resolver?" -> Loads TestingReference.md
- "How do I test a command end-to-end?" -> Loads TestingReference.md
- "How do I assert a command's printed output in a test?" -> Loads TestingReference.md
- "Why does my test ignore the --non-interactive flag I passed?" -> Loads TestingReference.md
