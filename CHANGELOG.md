# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/nikolainobadi/NnArgumentParser/compare/0.1.0...HEAD
[0.1.0]: https://github.com/nikolainobadi/NnArgumentParser/releases/tag/0.1.0
