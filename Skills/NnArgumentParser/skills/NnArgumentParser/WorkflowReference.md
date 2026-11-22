# NnArgumentParser Workflow Reference

API for structuring a command's `run()` as a typed pipeline: **inspect → interpret → collect → interpret → perform**.

**Import:** `import NnArgumentParser`

Requires NnArgumentParser 2.0.0 or later for the workflow interfaces shown here.

---

## Stage semantics

Each stage has one job. The protocols enforce the data flow between stages; these definitions say what belongs in each one.

| Stage | Protocol | Job | May prompt? |
|-------|----------|-----|-------------|
| **Inspect** | `NnInspector` | Checks the command can run: tools installed, config files present, repository state. Gathers **facts only** and makes no decisions. | No |
| **Interpret inspection** | `NnInspectionInterpreter` | Turns facts (plus command-line input) into **findings**, meaning what is settled, and **requirements**, meaning what is still missing. Throws when the command can't run. | No |
| **Collect** | `NnCollector` | Prompts for the **missing** information the command needs before it can start. Optional: a command with nothing missing uses `NnPassthroughCollector`. | Yes, but only for unknown requirements |
| **Interpret collection** | `NnCollectionInterpreter` | Combines findings, requirements, and answers into the performer's **brief**. Validates answers. | No |
| **Perform** | `NnPerformer` | Does the work. Usually the largest stage, so it's split into use cases. Returns **results**. | Only for *additional* information that comes up during the work, never for what Collect exists to gather |

Decisions belong in the two interpreters. Keep them out of the inspector and the collector. If the inspector chooses between options or the collector decides whether to ask, the pipeline's separation is lost.

The four stages of a shared check follow the same rules. See [Shared checks](#shared-checks).

---

## Protocol: NnWorkflow

Groups the five stages and ties their types together, so a mismatched stage fails to compile.

```swift
public protocol NnWorkflow {
    associatedtype InspectorType: NnInspector

    associatedtype InspectionInterpreter: NnInspectionInterpreter
    where InspectionInterpreter.Facts == InspectorType.Facts

    associatedtype CollectorType: NnCollector
    where CollectorType.Requirements == InspectionInterpreter.Requirements

    associatedtype CollectionInterpreter: NnCollectionInterpreter
    where CollectionInterpreter.Findings == InspectionInterpreter.Findings,
          CollectionInterpreter.Requirements == CollectorType.Requirements,
          CollectionInterpreter.Answers == CollectorType.Answers

    associatedtype PerformerType: NnPerformer
    where PerformerType.Brief == CollectionInterpreter.Brief

    var inspector: InspectorType { get }
    var inspectionInterpreter: InspectionInterpreter { get }
    var collector: CollectorType { get }
    var collectionInterpreter: CollectionInterpreter { get }
    var performer: PerformerType { get }

    func run() async throws -> PerformerType.Results
}

public extension NnWorkflow {
    func run() async throws -> PerformerType.Results
}
```

### `run()`, a requirement with a default

`run()` is a protocol requirement with a default, so a conforming struct doesn't write it. Because it is a requirement, a wrapper such as `NnCheckedWorkflow` can supply its own, and `NnWorkflowCommand` calls that one. The default is:

```swift
let facts = try await inspector.inspect()
let inspection = try inspectionInterpreter.interpret(facts: facts)
let answers = try collector.collect(requirements: inspection.requirements)
let brief = try collectionInterpreter.interpret(findings: inspection.findings, requirements: inspection.requirements, answers: answers)

return try await performer.perform(brief: brief)
```

### Type flow

```
Inspector ──Facts──▶ InspectionInterpreter ──NnInspection<Findings, Requirements>──┐
                                                                                   │
        ┌──────────────────────── Requirements ────────────────────────────────────┤
        ▼                                                                          │
    Collector ──Answers──▶ CollectionInterpreter(findings, requirements, answers) ◀┘
                                     │
                                   Brief
                                     ▼
                                 Performer ──▶ Results
```

### Behavioral Notes

- **The inspector and performer are async.** Call the workflow with `try await`; collectors and both interpreters remain synchronous. A synchronous implementation can still satisfy an async stage requirement.
- **The first error stops the run.** Each stage is called with `try`. A throwing inspector means the collector never runs, and a throwing collector means the performer never runs.
- **The collector is always called.** `run()` doesn't check whether anything is missing, so the collector must skip requirements that are already known. `NnRequirement.ask(_:)` handles this.
- **Findings skip the collector.** They go straight from the inspection interpreter to the collection interpreter, so the collector sees only what it has to ask about.
- **Conform with a plain struct of five `let`s.** The associated types are inferred from the property types:

```swift
struct PublishWorkflow: NnWorkflow {
    let inspector: PublishInspector
    let inspectionInterpreter: PublishInspectionInterpreter
    let collector: PublishCollector
    let collectionInterpreter: PublishCollectionInterpreter
    let performer: PublishPerformer
}
```

---

## Protocol: NnInspector

```swift
public protocol NnInspector {
    associatedtype Facts: Sendable

    func inspect() async throws -> Facts
}
```

- Reads the environment (shell, file system, git, config) and reports what it found. A missing config is a fact (`nil`), not an error. Whether that blocks the command is for the interpreter to decide.
- **Retroactive conformance works.** An inspector defined in a library module that already has a matching `inspect() async throws -> Facts` can adopt the protocol with an empty extension in the executable:

```swift
extension ProjectInspector: @retroactive NnInspector { }
```

---

## Protocol: NnInspectionInterpreter

```swift
public protocol NnInspectionInterpreter {
    associatedtype Facts: Sendable
    associatedtype Findings: Sendable
    associatedtype Requirements: Sendable

    func interpret(facts: Facts) throws -> NnInspection<Findings, Requirements>
}
```

- Throws when a fact rules the command out, for example when the directory isn't a git repository or a required config is missing.
- Command-line input reaches this stage through the interpreter's initializer. A value the caller passed makes its requirement `.known`, and an omitted value makes it `.unknown`.

## Struct: NnInspection

What the inspection interpreter learned (`findings`) and what it still needs (`requirements`).

```swift
public struct NnInspection<Findings: Sendable, Requirements: Sendable>: Sendable {
    public let findings: Findings
    public let requirements: Requirements

    public init(findings: Findings, requirements: Requirements)
}
```

---

## Protocol: NnCollector

```swift
public protocol NnCollector {
    associatedtype Requirements: Sendable
    associatedtype Answers: Sendable

    func collect(requirements: Requirements) throws -> Answers
}
```

- **Ask only for unknown requirements.** Call `requirement.ask(prompt)` for each field. It prompts only when the requirement is `.unknown` and returns `nil` when it's known.
- **`Answers` holds only what the user answered.** Each field is optional and is `nil` when its requirement was already known. Turning a requirement and its answer back into a value is the collection interpreter's job, through `resolve(answer:)`.
- **The collector doesn't check interactivity.** It prompts through whatever picker the factory vended. In non-interactive mode, that's a non-interactive picker that answers or throws.

---

## Protocol: NnCollectionInterpreter

```swift
public protocol NnCollectionInterpreter {
    associatedtype Findings: Sendable
    associatedtype Requirements: Sendable
    associatedtype Answers: Sendable
    associatedtype Brief: Sendable

    func interpret(findings: Findings, requirements: Requirements, answers: Answers) throws -> Brief
}
```

- Resolves each requirement with its answer (`try requirements.version.resolve(answer: answers.version)`), validates what the user typed, and builds the performer's `Brief`.
- `Brief` should carry everything the performer needs, so the performer never reads facts or requirements directly.

---

## Protocol: NnPerformer

```swift
public protocol NnPerformer {
    associatedtype Brief: Sendable
    associatedtype Results: Sendable

    func perform(brief: Brief) async throws -> Results
}
```

- Performs the side effects. Split large performers into use cases (`ProjectBuilder`, `ReleasePublisher`, …) injected through `init`.
- `Results` describes what happened, often as an enum (`.released`, `.prepared`, `.dryRun`). The performer doesn't print it; `NnWorkflowCommand.handleResults(_:)` does.

---

## Enum: NnRequirement

One input the command needs, either already settled or still missing.

```swift
public enum NnRequirement<Value: Sendable, Info: Sendable>: Sendable {
    case known(Value)
    case unknown(Info)
}

public extension NnRequirement {
    func ask(_ asker: (Info) throws -> Value) rethrows -> Value?
    func resolve(answer: Value?) throws -> Value
}
```

| Case / Member | Meaning |
|---------------|---------|
| `.known(Value)` | Settled from command-line input or facts. Nobody is asked. |
| `.unknown(Info)` | Missing. `Info` carries what the collector needs to ask well, such as the candidates to pick from or the latest version. Use `Void` when nothing extra is needed. |
| `ask(_:)` | **Collector side.** Calls `asker(info)` only when `.unknown`, and returns `nil` when `.known`. Rethrows the asker's error. |
| `resolve(answer:)` | **Collection-interpreter side.** `.known(v)` returns `v` and ignores the answer. `.unknown` returns the answer or throws `NnWorkflowError.missingAnswer` if it's `nil`. |

### Usage Example

```swift
// Inspection interpreter: decide known vs unknown.
let version: NnRequirement<VersionRequest, VersionInfo> =
    input.version.map { .known($0) } ?? .unknown(.init(latestTag: facts.latestTag))

// Collector: ask only when unknown.
let answer = try requirements.version.ask(versionPrompter.collectVersion)

// Collection interpreter: merge back into a value.
let request = try requirements.version.resolve(answer: answers.version)
```

A requirement can be nested inside another requirement's `Value`. For example, each target candidate can carry its own `buildAndTest` requirement. The collector resolves the outer requirement first so it can ask about the inner one:

```swift
let selected = try requirements.target.ask(pickTarget)
let target = try requirements.target.resolve(answer: selected)
// buildAndTest is NnRequirement<BuildAndTestAnswer, Void>, so the closure takes no info.
// With a non-Void Info, the closure receives it: `{ info in ... }`.
let buildAndTest = try target.buildAndTest.ask { try buildAndTestPrompter.collect(target: target.target) }
```

## Enum: NnWorkflowError

```swift
public enum NnWorkflowError: Error, Equatable {
    case missingAnswer
}

extension NnWorkflowError: LocalizedError {
    // .missingAnswer → "A required value was neither known nor answered."
    public var errorDescription: String? { get }
}
```

Thrown by `NnRequirement.resolve(answer:)` for an `.unknown` requirement with a `nil` answer. Getting this error means the collector skipped a requirement it should have asked about.

---

## Passthrough stages

For commands that have nothing to ask. Requirements and answers are both `Void`.

```swift
public struct NnPassthroughCollector: NnCollector {
    // Requirements = Void, Answers = Void
    public init()
    public func collect(requirements: Void) throws
}

public struct NnPassthroughCollectionInterpreter<Findings: Sendable>: NnCollectionInterpreter {
    // Requirements = Void, Answers = Void, Brief = Findings
    public init()
    public func interpret(findings: Findings, requirements: Void, answers: Void) throws -> Findings
}
```

Use them together. The inspection interpreter returns `NnInspection<Findings, Void>`, and the performer's `Brief` *is* the findings:

```swift
struct StatusWorkflow: NnWorkflow {
    let inspector: StatusInspector
    let inspectionInterpreter: StatusInspectionInterpreter   // -> NnInspection<StatusFindings, Void>
    let collector: NnPassthroughCollector
    let collectionInterpreter: NnPassthroughCollectionInterpreter<StatusFindings>
    let performer: StatusPerformer                            // Brief == StatusFindings
}
```

---

## Struct: NnTrackedInspector

Requires NnArgumentParser 2.0.0 or later for the `NnInspector`-based interface shown below.

Wraps an inspector so a tool can show progress during inspection without the inspector knowing about it. Use it when inspection is slow enough that the command would otherwise look stalled. The `track` closure decides how progress is reported, so the inspector stays unchanged and the package needs no progress dependency.

```swift
public struct NnTrackedInspector<Base: NnInspector>: NnInspector {
    public init(base: Base, track: @escaping (() async throws -> Base.Facts) async throws -> Base.Facts)
    public func inspect() async throws -> Base.Facts
}
```

Name the wrapper as the workflow's inspector type, and build it in `makeWorkflow()`:

```swift
struct StatusWorkflow: NnWorkflow {
    let inspector: NnTrackedInspector<StatusInspector>
    // other stages
}

inspector: .init(base: .init(gitClient: gitClient), track: { work in
    reporter.start("Checking the repository")

    do {
        let facts = try await work()
        reporter.finish(succeeded: true)

        return facts
    } catch {
        reporter.finish(succeeded: false)
        throw error
    }
}),
```

- The wrapper covers all of `inspect()`, so it reports one activity for the whole stage.
- A fact recorded as missing, such as a failed fetch stored as `nil`, still returns normally, so `track` sees success. Only a thrown error reaches `track` as a failure.
- The closure must call `work` exactly once and return its result. The type requires a return value, but nothing enforces the single call.

---

## Shared checks

Checks that several commands run before their own work: a tool is installed, the working tree is clean, the user confirms an unusual state. A check is a workflow without a performer. It has its own inspector and its own facts, so the same check fits in front of any command, whatever that command's stage types are.

```swift
public protocol NnRunnableCheck {
    func run() async throws
}

public protocol NnCheck: NnRunnableCheck {
    associatedtype InspectorType: NnInspector

    associatedtype InspectionInterpreter: NnInspectionInterpreter
    where InspectionInterpreter.Facts == InspectorType.Facts

    associatedtype CollectorType: NnCollector
    where CollectorType.Requirements == InspectionInterpreter.Requirements

    associatedtype CollectionInterpreter: NnCollectionInterpreter
    where CollectionInterpreter.Findings == InspectionInterpreter.Findings,
          CollectionInterpreter.Requirements == CollectorType.Requirements,
          CollectionInterpreter.Answers == CollectorType.Answers

    var inspector: InspectorType { get }
    var inspectionInterpreter: InspectionInterpreter { get }
    var collector: CollectorType { get }
    var collectionInterpreter: CollectionInterpreter { get }
}

public extension NnCheck {
    func run() async throws
}

public struct NnCheckGroup<each Check: NnRunnableCheck>: NnRunnableCheck {
    public init(_ checks: repeat each Check)
    public func run() async throws
}

public struct NnCheckedWorkflow<Checks: NnRunnableCheck, Base: NnWorkflow>: NnWorkflow {
    public init(checks: Checks, base: Base)
    public func run() async throws -> Base.PerformerType.Results
}
```

| Type | Role |
|------|------|
| `NnCheck` | What you write: a struct of four `let`s, one per stage. The provided `run()` calls the four stages in order and discards the brief. |
| `NnRunnableCheck` | Anything that can run before a workflow and stop it by throwing. `NnCheck` refines it, and `NnCheckGroup` conforms to it. You rarely conform to it directly. |
| `NnCheckGroup` | Runs its checks in declaration order. A group is itself a runnable check, so a named shared group nests inside another group. |
| `NnCheckedWorkflow` | Wraps a workflow. Its `run()` runs the checks, then the base workflow. Its five stages are the base's stages, and its results type is the base's results type. |

A check's stages follow the [stage semantics](#stage-semantics) unchanged. The inspector gathers the check's own facts, the inspection interpreter throws when the command can't run, the collector asks only for unknown requirements, and the collection interpreter validates the answer and throws to stop the run. A check with nothing to ask uses `NnPassthroughCollector` and `NnPassthroughCollectionInterpreter`.

### Order of work

1. The first check runs its four stages: inspect, interpret, collect, interpret.
2. Each later check does the same, in declaration order.
3. The base workflow runs its five stages.

The first throw stops the run. A failed or declined check stops every later check and the whole base workflow before they inspect or ask anything.

### Usage Example

```swift
struct CleanTreeCheck: NnCheck {
    let inspector: CleanTreeInspector                         // Facts == TreeStatus
    let inspectionInterpreter: CleanTreeInspectionInterpreter // Requirements == NnRequirement<Bool, [String]>
    let collector: CleanTreeCollector                         // asks whether to continue with uncommitted changes
    let collectionInterpreter: CleanTreeCollectionInterpreter // throws when the answer is no
}

struct CleanTreeCollectionInterpreter: NnCollectionInterpreter {
    func interpret(findings: TreeStatus, requirements: NnRequirement<Bool, [String]>, answers: Bool?) throws -> TreeStatus {
        guard try requirements.resolve(answer: answers) else {
            throw CleanTreeError.declined
        }

        return findings
    }
}
```

A command adopts checks by wrapping its workflow in `makeWorkflow()`. The workflow type and `handleResults(_:)` don't change:

```swift
struct Publish: NnWorkflowCommand {
    @Argument(help: "The version to publish. Prompts when omitted.")
    var version: String?

    func makeWorkflow() throws -> NnCheckedWorkflow<NnCheckGroup<CleanTreeCheck, OffMainBranchCheck>, PublishWorkflow> {
        let context = MyTool.makeContext()

        return .init(
            checks: .init(
                CleanTreeCheck(inspector: .init(shell: context.shell), inspectionInterpreter: .init(), collector: .init(picker: context.picker), collectionInterpreter: .init()),
                OffMainBranchCheck(inspector: .init(shell: context.shell), inspectionInterpreter: .init(), collector: .init(), collectionInterpreter: .init())
            ),
            base: .init(
                inspector: .init(shell: context.shell, fileSystem: context.fileSystem),
                inspectionInterpreter: .init(requestedVersion: version),
                collector: .init(picker: context.picker),
                collectionInterpreter: .init(),
                performer: .init(shell: context.shell, picker: context.picker)
            )
        )
    }

    func handleResults(_ results: PublishPerformer.Results) throws {
        NnOutput.write(PublishResultsFormatter.message(for: results))
    }
}
```

A single check needs no group: `NnCheckedWorkflow(checks: cleanTreeCheck, base: ...)`. To share a set between commands, name the group and nest it:

```swift
typealias RepositoryChecks = NnCheckGroup<CleanTreeCheck, OffMainBranchCheck>

let repositoryChecks = RepositoryChecks(cleanTreeCheck, offMainBranchCheck)
NnCheckGroup(repositoryChecks, signingKeyCheck)   // clean tree, off main, then signing key
```

### Behavioral Notes

- **Each check finishes before the next thing starts.** A check may therefore prompt before the command's own inspection finds a blocker, and the user can answer a confirmation and then see the command stop anyway.
- **Decide in the interpreters.** Any stage's throw stops the run, but only an interpreter should decide to stop it: the inspection interpreter when the command can't run, the collection interpreter when the answer is no. The collector never decides.
- **A check's output is discarded.** Its findings, answers, and brief never reach the command, and a check can't see the command's facts. If both need the same fact, both inspect it. If the command needs a value from the user, the command's own collector asks for it.
- **Only `run()` runs the checks.** `NnWorkflowCommand` calls it. Calling the checked workflow's five stages one by one runs the base workflow and skips every check.
- **A check included through two groups runs twice.** Groups don't deduplicate.
- **Track each inspection separately.** Name `NnTrackedInspector<...>` as a check's inspector type to track that check, and as the base workflow's inspector type to track the command's own inspection.
- **Checks get no special interactivity handling.** `NnRequirement.ask(_:)` never reads the interaction mode. A check's collector behaves under `--non-interactive` and `--yes` exactly as the prompting dependency you hand it does, the same as any other collector.

---

## Protocol: NnWorkflowCommand

An `AsyncParsableCommand` whose `run()` builds and runs a workflow, then hands the results back to the command.

```swift
public protocol NnWorkflowCommand: AsyncParsableCommand {
    associatedtype Workflow: NnWorkflow

    func makeWorkflow() throws -> Workflow
    func handleResults(_ results: Workflow.PerformerType.Results) throws
}

public extension NnWorkflowCommand {
    mutating func run() async throws
}
```

| Member | Role |
|--------|------|
| `makeWorkflow()` | The command's **composition root**. Pull infrastructure from the root command's `contextFactory`, build the stages, and inject parsed options into the inspection interpreter. |
| `handleResults(_:)` | Presentation. Format `Results` and write them with `NnOutput.write`, usually through a formatter type. This is the only stage that writes the final report to stdout. |

Don't implement `run()` yourself. The extension builds the workflow, awaits it with a blocking-tolerant executor preference, then calls synchronous `handleResults(_:)`. This lets workflow task-group children make blocking calls without occupying the cooperative pool's threads. Calling `workflow.run()` directly does not install this preference. Use `NnOutput.write` so `testRun` can capture the report.

### Usage Example

```swift
import NnArgumentParser

extension MyTool {
    struct Publish: NnWorkflowCommand {
        static let configuration = CommandConfiguration(abstract: "Tags and publishes a release.")

        @Argument(help: "The version to publish. Prompts when omitted.")
        var version: String?

        func makeWorkflow() throws -> PublishWorkflow {
            let context = MyTool.makeContext()   // infrastructure from contextFactory

            return .init(
                inspector: .init(shell: context.shell, fileSystem: context.fileSystem),
                inspectionInterpreter: .init(requestedVersion: version),
                collector: .init(picker: context.picker),
                collectionInterpreter: .init(),
                performer: .init(shell: context.shell, picker: context.picker)
            )
        }

        func handleResults(_ results: PublishPerformer.Results) throws {
            NnOutput.write(PublishResultsFormatter.message(for: results))
        }
    }
}
```

---

## Protocol: NnFormattedWorkflowCommand

An `NnWorkflowCommand` whose `handleResults(_:)` is provided: it asks a formatter for the message and writes it. Use it when `handleResults(_:)` would only format the results and write them.

```swift
public protocol NnResultsFormatter {
    associatedtype Results

    func message(for results: Results) -> String?
}

public protocol NnFormattedWorkflowCommand: NnWorkflowCommand {
    associatedtype ResultsFormatter: NnResultsFormatter
    where ResultsFormatter.Results == Workflow.PerformerType.Results

    var resultsFormatter: ResultsFormatter { get }
}

public extension NnFormattedWorkflowCommand {
    func handleResults(_ results: Workflow.PerformerType.Results) throws
}
```

The provided `handleResults(_:)` asks `resultsFormatter` for the message and writes it with `NnOutput.write`. When the message is `nil`, it writes nothing. Swift infers `ResultsFormatter` from the property's type, so no `typealias` is needed.

Declare `resultsFormatter` as a computed property. A stored one makes the command fail to compile with an error that it doesn't conform to `Decodable`, because ArgumentParser decodes every stored property of a command.

The command builds the formatter, so parsed options can shape the output. A command with a `--json` flag passes it in: `var resultsFormatter: StatusResultsFormatter { .init(json: json) }`.

A command that needs more than one write, or anything besides writing, keeps its own `handleResults(_:)`.

### Usage Example

```swift
struct PublishMessageFormatter: NnResultsFormatter {
    func message(for results: PublishPerformer.Results) -> String? {
        switch results {
        case .released(let version):
            return "Released \(version)."
        case .dryRun:
            return nil
        }
    }
}

extension MyTool {
    struct Publish: NnFormattedWorkflowCommand {
        static let configuration = CommandConfiguration(abstract: "Tags and publishes a release.")

        @Argument(help: "The version to publish. Prompts when omitted.")
        var version: String?

        var resultsFormatter: PublishMessageFormatter {
            return .init()
        }

        func makeWorkflow() throws -> PublishWorkflow {
            let context = MyTool.makeContext()

            return .init(
                inspector: .init(shell: context.shell, fileSystem: context.fileSystem),
                inspectionInterpreter: .init(requestedVersion: version),
                collector: .init(picker: context.picker),
                collectionInterpreter: .init(),
                performer: .init(shell: context.shell, picker: context.picker)
            )
        }
    }
}
```

---

## Best Practices

- **The inspector reports, the interpreters decide.** A missing file or an absent tool is a fact. Whether it's fatal is an interpretation.
- **Make every requirement an `NnRequirement`.** That keeps the "asked only when missing" rule enforced by the types instead of by `if` checks in the collector.
- **Put prompt details in `Info`.** The collector shouldn't read facts to find out what to offer. The interpreter that created the `.unknown` passes what's needed.
- **Validate typed answers in the collection interpreter**, not the collector. The collector records what was entered, and the interpreter decides whether it's valid.
- **The performer's use cases may prompt for follow-ups**, such as a final confirmation or an AI suggestion to accept. They never prompt for an input the command needed before it started; that's a requirement.
- **Use the passthrough stages** when a command has nothing to ask, instead of writing empty collectors.
- **Use `Sendable` value types for stage payloads.** Internal structs with `Sendable` members get the conformance implicitly. `public` ones must declare it.
