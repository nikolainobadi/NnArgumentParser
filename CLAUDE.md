# NnArgumentParser

A thin layer over Apple's [swift-argument-parser](https://github.com/apple/swift-argument-parser)
adding a dependency-injection seam for command-line tools, plus an interaction-mode system for
suppressing prompts in automated contexts.

- `Sources/NnArgumentParser` — the library. `NnRootCommand`, `InteractionMode`, `InteractivityOptions`.
- `Sources/NnArgumentParserTesting` — `testRun`, for driving whole commands in tests.
- `Skills/NnArgumentParser` — **the published API reference.** See below.

## The skill lives in this repo

`Skills/NnArgumentParser` is the Claude skill documenting this package's API. It is published
through the `nn-swift-skills` marketplace as a `git-subdir` source pointing at this directory.

It lives here rather than in a marketplace repo for one reason: an API change and its
documentation are then the **same diff**, reviewed together. When they lived in separate repos
they drifted — the interaction-mode feature shipped in `6d02ef6` and the docs did not catch up
until the migration, a gap nothing detected.

### Rules

- **A PR changing the public API must also touch `Skills/`.** `.github/workflows/skill-docs.yml`
  enforces this: it fails any PR whose diff adds or removes `public`/`open`/`package` declarations
  under `Sources/` without touching `Skills/`. Apply the **`skip-skill-check`** label when a PR
  genuinely changes no documented behavior — reformatting, renaming a local parameter, moving a file.
- **`Skills/NnArgumentParser/.claude-plugin/plugin.json` deliberately has no `version` field.**
  Do not reintroduce one. Git-based sources are cached by commit sha, so a hand-typed version number
  is a second source of truth that nothing verifies — exactly the staleness this layout removes.
- **Keep `Skills/.../manifest.json` current** when adding or removing a public type: it records the
  sha, tag, per-file hashes, and the type-to-document map used to detect drift.
- **`Skills/` is invisible to SwiftPM.** It is not a target path; `swift build` ignores it. Verify
  with `swift package describe --type json` if that ever seems in doubt.

## Releasing

The marketplace entry is **pinned to a release tag**, not to `main`. Two consequences:

- **Doc changes ship on release, not on merge.** Merging a correction to `Skills/` changes nothing
  for readers until the next tag. This is the intended trade — the docs someone reads always match
  a version they can actually depend on — but it surprises you if you just merged a fix.
- **The pin must be bumped every release.** `.github/workflows/skill-ref-bump.yml` does this
  automatically: on tag push it rewrites the `ref` in `nikolainobadi/nn-swift-skills` and opens a PR
  there. It needs the repo secret **`MARKETPLACE_TOKEN`** (`contents:write` + `pull-requests:write`
  on the marketplace repo).

  That token is a fine-grained PAT named `nn-swift-skills-ref-bump`, scoped to `nn-swift-skills`
  only, **expiring 2027-08-15**. It is **shared across every package repo** publishing to that
  marketplace, not specific to this one — so rotating it means re-setting the secret in each of
  them, and this repo is not the only place it lives.

  When it expires the workflow fails loudly on tag push — a red X, not silence — so treat that
  failure as "rotate the token", not "the workflow is broken". Regenerate it, then re-run
  `gh secret set MARKETPLACE_TOKEN --repo <owner>/<package>` for every package repo using it.

**If that automation is ever removed or its token expires, the bump becomes manual.** Nothing errors
and nothing warns when it is skipped — the marketplace simply keeps serving the previous release's
documentation indefinitely. A silently stale pin is the one failure mode this layout does not fix on
its own.

## Conventions

- Swift 6.0, macOS 15+.
- `@_exported import ArgumentParser` in `Exports.swift` — consumers get the full ArgumentParser
  surface from `import NnArgumentParser` and should never import ArgumentParser separately.
- Thread-local storage backs both `NnRootCommand.contextFactory` and `InteractionMode.current`, so
  parallel tests don't interfere. Anything registered in a test must be reset; `testRun` handles its
  own cleanup in a `defer`.
- Tests use Swift Testing (`import Testing`), with backtick-quoted descriptive test names.
