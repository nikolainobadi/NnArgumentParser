# NnArgumentParser Testing Reference

Utilities from the `NnArgumentParserTesting` module for driving whole commands in tests.

**Import:** `import NnArgumentParserTesting`

---

<!-- type:testRun -->
## Method: testRun(contextFactory:args:interactionMode:)

Runs a root command end-to-end in a test and returns its captured stdout.

```swift
extension NnRootCommand {
    @discardableResult
    static func testRun(
        contextFactory: Factory? = nil,
        args: [String]? = [],
        interactionMode: InteractionMode? = .nonInteractive(assumeYes: false)
    ) throws -> String
}
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `contextFactory` | `Factory?` | Factory to inject for this run. When non-nil it's assigned to the root command's thread-local `contextFactory`. When `nil`, `defaultFactory` is used. |
| `args` | `[String]?` | The command-line arguments, e.g. `["greet", "--name", "Ada"]`. Defaults to `[]`. |
| `interactionMode` | `InteractionMode?` | Mode applied for the duration of the run, **after parsing**, so it overrides any parsed interactivity flags. Defaults to `.nonInteractive(assumeYes: false)`. Pass `nil` to let the parsed args and environment decide. |

### Returns / Behavior

- Returns everything the command wrote to **stdout**, trimmed.
- Parses `args` via `parseAsRoot`, registers `interactionMode` if non-nil, then calls the resolved command's `run()`.
- **Rethrows** whatever `run()` throws (restoring stdout first), so `#expect(throws:)` works.
- stdout capture is serialized with a lock (stdout is process-global).
- Always calls `InteractionMode.reset()` on the way out, so no mode leaks to the next test on that thread.
<!-- /type:testRun -->

## Tests are non-interactive by default

`testRun` registers `.nonInteractive(assumeYes: false)` unless told otherwise. A test that reaches a prompt therefore **fails instead of blocking the suite** on input that will never arrive.

This only helps to the extent that your factory consults `InteractionMode.current` when building prompt-driven dependencies. A factory that hardcodes a real picker will still hang.

The default is applied *after* parsing, so it wins over flags in `args`. **To test the flags themselves, pass `interactionMode: nil`:**

```swift
@Test
func `--non-interactive is honored`() throws {
    // nil → the parsed --non-interactive flag decides, not the testRun default
    try MyTool.testRun(contextFactory: MockDependencies(),
                       args: ["add-user", "--non-interactive"],
                       interactionMode: nil)
}

@Test
func `Prompts when a terminal is available`() throws {
    // Explicitly opt into interactive for this run
    try MyTool.testRun(contextFactory: MockDependencies(),
                       args: ["add-user"],
                       interactionMode: .interactive(assumeYes: false))
}
```

## The command-testing pattern

`testRun` injects *your* `Factory`. Supply a test double of it that vends fakes, drive the real command tree, then **assert on outcomes** (printed output, values produced, side effects on your fakes) — not on interactions or call counts.

```swift
import Testing
import NnArgumentParserTesting

struct GreetCommandTests {
    @Test
    func `Greets the provided name`() throws {
        let output = try MyTool.testRun(contextFactory: MockDependencies(), args: ["greet", "--name", "Ada"])

        #expect(output == "Hello, Ada!")
    }
}

// A test double of the tool's own factory type.
private struct MockDependencies: Dependencies {
    func makeGreeter() -> any Greeter { StubGreeter() }
}
```

## Mocking infrastructure

NnArgumentParser only requires that your `Factory` can be swapped for a test double — it's agnostic about what the factory vends. Test doubles for specific infrastructure ship with their own packages:

- **File systems** → `MockFileSystem` / `MockDirectory` — see the **NnFileKit** skill
- **Interactive pickers** → `MockSwiftPicker` — see the **SwiftPickerKit** skill
- **Shell execution** → `MockShell` — see the **NnShellKit** skill

Have your factory's test double vend those mocks, then inject the factory via `testRun`.

## Best Practices

- **Inject a fresh factory per test** — `testRun` sets the thread-local `contextFactory`; a new factory per test keeps cases isolated.
- **Assert outcomes, not interactions** — check printed output or your fakes' resulting state, not call counts.
- **`testRun` returns stdout** — use it for output assertions; use your injected fakes' state for side-effect assertions.
- **Test through the root command type** — `testRun` is called on the `@main` `NnRootCommand`; it runs the whole parsed command tree, so subcommands are exercised through it.
- **Leave `interactionMode` at its default** unless the test is *about* interactivity. The non-interactive default is a guardrail against a hung suite.
- **Pass `interactionMode: nil` to exercise the flags** — otherwise the default silently overrides whatever `--non-interactive` / `--yes` you put in `args`.
- **Don't call `InteractionMode.reset()` yourself after `testRun`** — it already does, in a `defer`. Do reset if you registered a mode outside a `testRun` call.
