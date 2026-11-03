# NnArgumentParser

A thin layer over Apple's [swift-argument-parser](https://github.com/apple/swift-argument-parser)
adding a dependency-injection seam for command-line tools, an interaction-mode system for
suppressing prompts in automated contexts, and composable command workflows.

- `Sources/NnArgumentParser` — the library. `Arguments/`, `Completion/`, `Exports/`, `Interactivity/`,
  `Interrupt/`, `Output/`, `RootCommand/`, `Storage/`, and `Workflow/` organize its APIs and
  command-scoped state; `NnWorkflow` composes inspect, interpret,
  collect, interpret, and resolve stages, while `NnWorkflowCommand` adapts a workflow to a command.
- `Sources/NnArgumentParserTesting` — async `testRun` for driving whole commands in tests,
  `withIsolatedState` for scoped state access, and workflow stage mocks for exercising pipeline wiring.
- `Skills/NnArgumentParser` — **the published API reference.** See below.

Interactivity guidance appears in four places — the `InteractivityOptions` doc comment, `Skills/`,
`README.md`, and `CHANGELOG.md`. They drifted once already: all four said to declare the option
group on every prompting command, when one declaration on the root registers the mode for the whole
chain. Change them together.

## The skill lives in this repo

`Skills/NnArgumentParser` is the Claude skill documenting this package's API. It is published
through the `nn-swift-skills` marketplace as a `git-subdir` source pointing at this directory.

It lives here rather than in a marketplace repo for one reason: an API change and its
documentation are then the **same diff**, reviewed together. When they lived in separate repos
they drifted — the interaction-mode feature shipped in `6d02ef6` and the docs did not catch up
until the migration, a gap nothing detected.

### Rules

- **A PR changing the public API must also touch `Skills/`.** No PR workflow currently enforces
  this, so verify the source and skill changes together in the diff.
- **`Skills/` is invisible to SwiftPM.** It is not a target path; `swift build` ignores it. Verify
  with `swift package describe --type json` if that ever seems in doubt.

## Releasing

Release preparation is configured in `.nnex/nnex.json` for the `NnArgumentParser` library target
at `.`. Its commands are `swift build --build-tests` followed by `swift test --skip-build`.

**`CHANGELOG.md` is updated before the tag, not after.** It follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/): entries accumulate under `Unreleased`
during development, and cutting a release means renaming that heading to the version, dating it, and
adding its comparison link at the bottom of the file. **Tags carry no `v` prefix** (`0.1.0`, not
`v0.1.0`) — those links break if you add one. Nothing enforces any of this; no workflow checks the
changelog, so a release cut without the rename silently ships an empty entry.

## Conventions

- Swift 6.2, macOS 15+. Pull-request CI uses Xcode 26.3 on macOS 15 and runs `swift test`.
- `@_exported import ArgumentParser` in `Exports.swift` — consumers get the full ArgumentParser
  surface from `import NnArgumentParser` and should never import ArgumentParser separately.
  `NnArgumentParserTesting` likewise does `@_exported import NnArgumentParser`, so test files need
  only `import NnArgumentParserTesting`.
- `NnRootCommand` and `NnWorkflowCommand` conform to `AsyncParsableCommand`. Workflow `run()`,
  inspector `inspect()`, and resolver `resolve(context:)` are async; collection and interpretation
  remain synchronous. `NnWorkflowCommand` runs the workflow with a dispatch-backed task executor
  preference to accommodate blocking stages.
- Task-local command scopes back `NnRootCommand.contextFactory` and `InteractionMode.current`.
  The root's `main()` installs the production scope; `testRun` installs one per run. State survives
  `await` and is inherited by child tasks, but not `Task.detached`. Reading the factory or registering
  state outside a scope traps; an unscoped mode read falls back to environment and terminal resolution.
  Tests accessing state directly use `withIsolatedState`, or the root's
  `withIsolatedState(contextFactory:_:)` to inject a factory. Scope lifetime handles cleanup;
  there is no reset call, and the factory setter is package-only.
- `testRun(contextFactory:args:interactionMode:)` is async and requires all three arguments.
  An explicit mode overrides parsed flags; pass `nil` to use argument and environment resolution.
  It captures only `NnOutput.write(_:)` output, not plain `print`, and capture takes precedence over
  a writer registered through `NnOutput.register(writer:)`.
- `NnInterrupt.register(cleanup:)` registers cleanup in the command scope. Production runs cleanups
  in reverse registration order on SIGINT or SIGTERM and suppresses subsequent `NnOutput` writes.
  `testRun` installs no signal handlers and discards registered cleanups without running them.
  To test cleanups, use async `testRunCapturingCleanups(contextFactory:args:interactionMode:)`
  with the same three required arguments. It returns `NnTestRunResult` with captured `output`
  and `interruptCleanups` in reverse registration order. It installs no signal handlers and runs
  no cleanups; call the returned closures explicitly, then assert on the test doubles.
- `NnCompletion.register(observer:)` registers a completion observer in the command scope. Observers
  run once, in registration order, after the command returns or throws and before `main()` reports a
  failure; interrupted runs notify nobody. `NnRunOutcome.failed` carries `message(for:)` (no `Error: `
  prefix) and the exit code; clean exits are `.succeeded`. `testRun` and `testRunCapturingCleanups`
  notify observers too, for parse failures as well as run failures, before returning or rethrowing.
- `NnArgumentParserTesting` adds `knownValue` and `unknownInfo` accessors to `NnRequirement`.
  Each returns the matching case's payload, or `nil` for the other case. For requirement assertions,
  unwrap the expected payload with `#require`, then assert on its value or fields.
- Tests use Swift Testing (`import Testing`), with backtick-quoted descriptive test names.
