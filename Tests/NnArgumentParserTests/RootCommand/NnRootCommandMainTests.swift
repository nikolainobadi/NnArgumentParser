//
//  NnRootCommandMainTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Testing
import Foundation
@testable import NnArgumentParser

struct NnRunCompletionTests {
    @Test
    func `An error after an interrupt has started parks instead of exiting`() {
        let completion = NnRunCompletion(outcome: .failure(MainTestError.boom), isInterrupting: true)

        #expect(isPark(completion))
    }

    @Test
    func `Success after an interrupt has started parks instead of returning`() {
        let completion = NnRunCompletion(outcome: .success(()), isInterrupting: true)

        #expect(isPark(completion))
    }

    @Test
    func `An error without an interrupt exits with that error`() {
        let completion = NnRunCompletion(outcome: .failure(MainTestError.boom), isInterrupting: false)

        guard case .exit(let error) = completion else {
            Issue.record("Expected .exit, got \(completion)")
            return
        }

        #expect(error as? MainTestError == .boom)
    }

    @Test
    func `Success without an interrupt finishes normally`() {
        let completion = NnRunCompletion(outcome: .success(()), isInterrupting: false)

        guard case .finish = completion else {
            Issue.record("Expected .finish, got \(completion)")
            return
        }
    }
}


// MARK: - main() End to End
/// `main` really exits, so each case runs in an exit test's child process.
struct NnRootCommandMainTests {
    #if compiler(>=6.2)
    @Test
    func `An error caused by an interrupt is not reported, and the process ends by the signal`() async {
        let result = await #expect(processExitsWith: .signal(SIGINT), observing: [\.standardErrorContent]) {
            await InterruptibleRoot.main(arguments: ["--outcome", "interrupt-then-fail"])
        }

        #expect(errorOutput(of: result) == "cleanup ran\n\nInterrupted.\n")
    }

    @Test
    func `Success after an interrupt still ends the process by the signal`() async {
        let result = await #expect(processExitsWith: .signal(SIGINT), observing: [\.standardErrorContent]) {
            await InterruptibleRoot.main(arguments: ["--outcome", "interrupt-then-succeed"])
        }

        #expect(errorOutput(of: result) == "cleanup ran\n\nInterrupted.\n")
    }

    @Test
    func `An error without an interrupt is reported and exits with failure`() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            await InterruptibleRoot.main(arguments: ["--outcome", "fail"])
        }

        #expect(errorOutput(of: result).contains("Error: boom"))
    }

    @Test
    func `Success without an interrupt returns normally`() async {
        await #expect(processExitsWith: .success) {
            await InterruptibleRoot.main(arguments: ["--outcome", "succeed"])
        }
    }
    #endif
}


// MARK: - Helpers
private func isPark(_ completion: NnRunCompletion) -> Bool {
    guard case .park = completion else {
        return false
    }

    return true
}

#if compiler(>=6.2)
private func errorOutput(of result: ExitTest.Result?) -> String {
    return String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
}
#endif


// MARK: - Test Doubles
private enum MainTestError: Error, Equatable, CustomStringConvertible {
    case boom

    var description: String {
        return "boom"
    }
}

private struct InterruptibleRoot: NnRootCommand {
    static var defaultFactory: Void { () }

    @Option var outcome: String

    func run() async throws {
        if outcome.hasPrefix("interrupt") {
            // Slow like real teardown, so main() reaches its decision while the cleanup is still running.
            NnInterrupt.register(cleanup: {
                usleep(200_000)
                fputs("cleanup ran\n", stderr)
            })
            kill(getpid(), SIGINT)

            // Stands in for a child killed by the interrupt: its failure surfaces after the signal lands.
            while NnInterruptSignal.received == 0 {
                try await Task.sleep(for: .milliseconds(1))
            }
        }

        if outcome.hasSuffix("fail") {
            throw MainTestError.boom
        }
    }
}
