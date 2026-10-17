# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-10-17

### Added

- Add `NnRequirement.knownValue` and `NnRequirement.unknownInfo` in `NnArgumentParserTesting`
  for asserting on requirement payloads. Each returns the matching case's payload or `nil`
  for the other case, including support for `Void` info.
- Re-export `NnArgumentParser` from `NnArgumentParserTesting`, so test files can access both
  modules' public APIs with only `import NnArgumentParserTesting`.

## [1.0.1] - 2026-10-17

### Added

- Add `NnRootCommand.testRunCapturingCleanups(contextFactory:args:interactionMode:)` in
  `NnArgumentParserTesting`, returning an `NnTestRunResult` with captured output and registered
  interrupt cleanups in reverse registration order. Invoke the returned `interruptCleanups` to
  test command teardown; the helper installs no signal handlers and does not run cleanups itself.

## [1.0.0] - 2026-10-17

### Added

- Add `NnOutput.write(_:)` for command output and `NnOutputWriter` with
  `NnOutput.register(writer:)` for routing output through an app-provided sink.
- Add `NnInterrupt.register(cleanup:)` for SIGINT and SIGTERM cleanup under the root command's
  `main()`. Cleanups run in reverse registration order before reporting `Interrupted.` and
  terminating by the signal; further `NnOutput` writes and command errors are suppressed during
  interruption. `testRun` installs no signal handlers and does not execute registered cleanups.
- Add synchronous and asynchronous `withIsolatedState` helpers to `NnArgumentParserTesting`,
  including `NnRootCommand.withIsolatedState(contextFactory:_:)` for scoped factory injection.

### Changed

- Require Swift 6.2 and ArgumentParser 1.8.2 or later. Upgrade the toolchain and dependency
  constraints when adopting this release (breaking).
- Make `NnRootCommand` and `NnWorkflowCommand` conform to `AsyncParsableCommand`, and make
  `NnWorkflow.run()`, `NnCommandInspector.inspect()`, and `NnCommandResolver.resolve(context:)`
  asynchronous. Await these calls and use async command entry points; synchronous subcommands
  remain supported (breaking).
- Keep the factory and interaction mode in a command scope that survives `await` and is inherited
  by child tasks. Reading `contextFactory` or registering an interaction mode outside a scope now
  traps, and `contextFactory` is no longer publicly settable. Run production commands through the
  root's `main()`, inject test factories through `testRun` or `withIsolatedState`, and avoid reading
  scoped state from `Task.detached` (breaking).
- Make `testRun(contextFactory:args:interactionMode:)` asynchronous and require all three arguments
  explicitly. Use `try await` and pass `.nonInteractive(assumeYes: false)` to retain the former
  prompt-suppression default, or `nil` to use parsed flags and environment resolution (breaking).
- Capture only `NnOutput.write(_:)` output in `testRun`, with a separate buffer for each parallel
  run; registered output writers are bypassed during capture. Replace `print` calls whose output
  must be asserted with `NnOutput.write(_:)` (breaking).
- Run `NnWorkflowCommand` workflows on a blocking-tolerant executor so synchronous blocking work
  in task-group children does not occupy the cooperative pool's threads.

### Removed

- Remove `InteractionMode.reset()`. Remove explicit reset calls and use `testRun` or
  `withIsolatedState` in tests; registered state is discarded when its scope ends (breaking).

## [0.3.0] - 2026-10-13

### Added

- Add `NnWorkflow` and `NnWorkflowCommand` for structuring commands as typed inspect, interpret,
  collect, interpret, and resolve stages, with `NnPassthroughCollector` and
  `NnPassthroughCollectionInterpreter` for commands that need no input.
- Add `NnInspection`, `NnRequirement`, and `NnWorkflowError` to represent findings and missing
  input, ask only for unknown values, and report when a required answer is missing.
- Add `MockCommandInspector`, `MockCommandCollector`, `MockCommandResolver`, and
  `MockWorkflowError` to `NnArgumentParserTesting` for testing workflow stages.

### Changed

- Correct the guidance for `InteractivityOptions`: declaring it once on the root command registers
  the interaction mode for every subcommand, so it does not need repeating on each prompting
  command. Declare it per-command only when that command's own `--help` should list the flags.

## [0.1.0] - 2026-08-15

### Added

- Add `NnRootCommand`, a `ParsableCommand` protocol with a `Factory` associated type and a
  `defaultFactory` requirement, giving command-line tools a dependency-injection seam.
- Add `NnRootCommand.contextFactory`, a thread-local override of `defaultFactory` so tests can
  swap a command's dependencies without affecting commands running in parallel.
- Re-export ArgumentParser from `NnArgumentParser`, so `import NnArgumentParser` alone provides
  the full ArgumentParser surface.
- Add `InteractionMode`, an `.interactive` / `.nonInteractive` mode that records whether a command
  may prompt, with an `assumeYes` value on both cases so pre-approving confirmations is
  independent of suppressing prompts.
- Add `InteractionMode.resolve(...)`, which suppresses prompting when `--non-interactive` is
  passed, when the `NO_PROMPT` environment variable is set to a non-empty value, or when standard
  input is not a terminal — so piped, redirected, and scheduled invocations never hang on a prompt.
- Add `InteractionMode.current`, `register(_:)`, and `reset()` for reading and setting the mode
  through thread-local storage.
- Add `InteractivityOptions`, an `@OptionGroup` supplying the `--non-interactive` and `--yes`
  flags and registering the resolved mode during validation. Declaring it on the root command
  registers the mode for every subcommand; declaring it per-command lists the flags in that
  command's own `--help`.
- Add the `NnArgumentParserTesting` library with `testRun(contextFactory:args:interactionMode:)`,
  which parses and runs a whole command, captures its standard output, and defaults to
  non-interactive so a test that reaches a prompt fails instead of blocking.

[Unreleased]: https://github.com/nikolainobadi/NnArgumentParser/compare/1.1.0...HEAD
[1.1.0]: https://github.com/nikolainobadi/NnArgumentParser/compare/1.0.1...1.1.0
[1.0.1]: https://github.com/nikolainobadi/NnArgumentParser/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/nikolainobadi/NnArgumentParser/compare/0.3.0...1.0.0
[0.3.0]: https://github.com/nikolainobadi/NnArgumentParser/compare/0.2.0...0.3.0
[0.1.0]: https://github.com/nikolainobadi/NnArgumentParser/releases/tag/0.1.0
