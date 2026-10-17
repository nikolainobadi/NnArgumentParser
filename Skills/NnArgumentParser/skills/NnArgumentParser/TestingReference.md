# NnArgumentParser Testing Reference

Utilities from the `NnArgumentParserTesting` module for driving whole commands in tests.

**Import:** `import NnArgumentParserTesting`

---

<!-- type:testRun -->
## Method: testRun(contextFactory:args:interactionMode:)

Runs a root command end-to-end in a test and returns its captured `NnOutput.write` output.

```swift
extension NnRootCommand {
    @discardableResult
    static func testRun(contextFactory: Factory?, args: [String]?, interactionMode: InteractionMode?) async throws -> String
}
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `contextFactory` | `Factory?` | Factory to inject for this run. When non-nil it's injected into the run's command scope. When `nil`, `defaultFactory` is used. |
| `args` | `[String]?` | The command-line arguments, e.g. `["greet", "--name", "Ada"]`. Pass `[]` for no arguments; `nil` uses process arguments. |
| `interactionMode` | `InteractionMode?` | Mode applied for the duration of the run, **after parsing**, so it overrides any parsed interactivity flags. Pass `.nonInteractive(assumeYes: false)` explicitly to suppress prompting. Pass `nil` to let the parsed args and environment decide. |

### Returns / Behavior

- All three arguments are required; none has a default. Call with `try await`.
- Returns only `NnOutput.write` output, trimmed. Plain `print` writes to stdout and is not captured. Registered output writers are bypassed during capture.
- Parses `args` via `asyncParseAsRoot`, registers `interactionMode` if non-nil, then runs the selected command, awaiting it when it conforms to `AsyncParsableCommand`. Synchronous subcommands are also supported.
- Propagates parsing and command errors. Use an async `#expect(throws:)` closure for an async call.
- Each run owns its factory, mode, and output buffer; parallel runs do not share captured output or require process-wide stdout redirection.
- The scope is discarded on return or throw. There is no mode to reset afterward.
- Installs no signal handlers. `NnInterrupt` cleanups registered during the run are discarded without being executed.
<!-- /type:testRun -->

<!-- type:MockCommandInspector -->
## Workflow stage mocks

Test doubles for the three side-effecting `NnWorkflow` stages. All are `final class`es that record what they received and return a canned value. Pass `throwError: true` to make the stage throw `MockWorkflowError.stageFailed` instead.

```swift
public final class MockCommandInspector<Facts: Sendable>: NnCommandInspector {
    public private(set) var inspectCallCount: Int
    public init(facts: Facts, throwError: Bool)
}

public final class MockCommandCollector<Requirements: Sendable, Answers: Sendable>: NnCommandCollector {
    public private(set) var capturedRequirements: [Requirements]
    public init(answers: Answers, throwError: Bool)
}

public final class MockCommandResolver<Context: Sendable, Results: Sendable>: NnCommandResolver {
    public private(set) var capturedContexts: [Context]
    public init(results: Results, throwError: Bool)
}

public enum MockWorkflowError: Error, Equatable {
    case stageFailed
}
```

| Mock | Returns | Records |
|------|---------|---------|
| `MockCommandInspector` | `facts` | `inspectCallCount` |
| `MockCommandCollector` | `answers` | `capturedRequirements`, each `requirements` value it was asked to collect |
| `MockCommandResolver` | `results` | `capturedContexts`, each `context` it was asked to resolve |

There are **no interpreter mocks.** Interpreters are pure functions of their inputs, so test them directly: call `interpret(...)` and assert on the returned findings, requirements, or context. Mock the stages *around* the one under test.

### Usage Example

```swift
import Testing
import NnArgumentParser
import NnArgumentParserTesting

struct PublishWorkflowTests {
    @Test
    func `An omitted version is collected and reaches the resolver`() async throws {
        let inspector = MockCommandInspector(facts: PublishFacts(latestTag: "1.2.0"), throwError: false)
        let collector = MockCommandCollector<PublishRequirements, PublishAnswers>(answers: .init(version: .exact("1.3.0")), throwError: false)
        let resolver = MockCommandResolver<PublishContext, PublishResults>(results: .published, throwError: false)
        let sut = TestWorkflow(
            inspector: inspector,
            inspectionInterpreter: .init(requestedVersion: nil),
            collector: collector,
            collectionInterpreter: .init(),
            resolver: resolver
        )

        _ = try await sut.run()

        #expect(resolver.capturedContexts.map(\.version) == [.exact("1.3.0")])
    }
}

// The workflow under test, with the real interpreters and mocked edges.
private struct TestWorkflow: NnWorkflow {
    let inspector: MockCommandInspector<PublishFacts>
    let inspectionInterpreter: PublishInspectionInterpreter
    let collector: MockCommandCollector<PublishRequirements, PublishAnswers>
    let collectionInterpreter: PublishCollectionInterpreter
    let resolver: MockCommandResolver<PublishContext, PublishResults>
}
```

To stop a run at a given stage, pass `throwError: true` and assert with `await #expect(throws: MockWorkflowError.stageFailed) { try await sut.run() }`. Then check that later stages recorded nothing, for example `collector.capturedRequirements.isEmpty`.
<!-- /type:MockCommandInspector -->

## Choose the test interaction mode explicitly

Pass `interactionMode: .nonInteractive(assumeYes: false)` to `testRun`. A test that reaches a prompt therefore **fails instead of blocking the suite** on input that will never arrive.

This only helps to the extent that your factory consults `InteractionMode.current` when building prompt-driven dependencies. A factory that hardcodes a real picker will still hang.

The explicit override is applied *after* parsing, so it wins over flags in `args`. **To test the flags themselves, pass `interactionMode: nil`:**

```swift
@Test
func `--non-interactive is honored`() async throws {
    // nil → the parsed --non-interactive flag decides, not a test override
    try await MyTool.testRun(contextFactory: MockDependencies(), args: ["add-user", "--non-interactive"], interactionMode: nil)
}

@Test
func `Prompts when a terminal is available`() async throws {
    // Explicitly opt into interactive for this run
    try await MyTool.testRun(contextFactory: MockDependencies(), args: ["add-user"], interactionMode: .interactive(assumeYes: false))
}
```

## Isolated state without running a command

`withIsolatedState(_:)` creates a fresh command scope for a synchronous or async closure. Use it when testing a factory accessor, registering a mode or output writer, or parsing a command with `InteractivityOptions` directly. `MyTool.withIsolatedState(contextFactory:_:)` also injects a factory; `contextFactory` cannot be assigned by package consumers.

```swift
import Testing
import NnArgumentParser
import NnArgumentParserTesting

@Test
func registeredModeIsVisible() {
    withIsolatedState {
        InteractionMode.register(.nonInteractive(assumeYes: true))
        #expect(InteractionMode.current == .nonInteractive(assumeYes: true))
    }
}
```

The scope follows `await` and is inherited by task-group children and `Task { }`, but not `Task.detached`. Reading `contextFactory` or registering state without a scope traps. `InteractionMode.current` alone can be read outside a scope and falls back to environment and terminal resolution. These helpers do not install output capture or signal handling.

## The command-testing pattern

`testRun` injects *your* `Factory`. Supply a test double of it that vends fakes, drive the real command tree, then **assert on outcomes** (printed output, values produced, side effects on your fakes) — not on interactions or call counts.

The command must emit its greeting with `NnOutput.write`, as in `ApiReference.md`.

```swift
import Testing
import NnArgumentParserTesting

struct GreetCommandTests {
    @Test
    func `Greets the provided name`() async throws {
        let output = try await MyTool.testRun(contextFactory: MockDependencies(), args: ["greet", "--name", "Ada"], interactionMode: .nonInteractive(assumeYes: false))

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

- **Inject a fresh factory per test** — `testRun` injects the factory into its own scope; a new factory per test keeps cases isolated.
- **Assert outcomes, not interactions** — check printed output or your fakes' resulting state, not call counts.
- **`testRun` returns `NnOutput` writes** — use it for output assertions; use your injected fakes' state for side-effect assertions.
- **Test through the root command type** — `testRun` is called on the `@main` `NnRootCommand`; it runs the whole parsed command tree, so subcommands are exercised through it.
- **Pass `.nonInteractive(assumeYes: false)` explicitly** unless the test is *about* interactivity. This keeps prompt-aware dependencies from waiting for input.
- **Pass `interactionMode: nil` to exercise the flags** — otherwise the explicit mode overrides whatever `--non-interactive` / `--yes` you put in `args`.
- **Use `withIsolatedState` for direct state tests** — registration requires a scope, and the scope discards state automatically. `InteractionMode.reset()` no longer exists.
- **Test workflow interpreters directly.** They're pure, so give them inputs and assert on outputs, without mocks.
- **Test a workflow's wiring with the stage mocks.** Use real interpreters between a `MockCommandInspector` and a `MockCommandResolver`, then assert on `capturedContexts`.
- **Test an `NnWorkflowCommand` end-to-end with `testRun`**, like any other command. It runs `makeWorkflow()` against your injected factory.
