//
//  NnInterruptCoordinatorTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Testing
import Foundation
@testable import NnArgumentParser
import NnArgumentParserTesting

struct NnInterruptCoordinatorTests {
    @Test
    func `An interrupt runs the cleanups newest first, then writes the message, then terminates`() {
        let log = EventLog()

        withIsolatedState {
            NnInterrupt.register(cleanup: { log.record("cleanup: first") })
            NnInterrupt.register(cleanup: { log.record("cleanup: second") })

            makeSUT(log: log).handle(signal: SIGINT)
        }

        #expect(log.entries == ["cleanup: second", "cleanup: first", "error: \nInterrupted.\n", "terminate: \(SIGINT)"])
    }

    @Test
    func `SIGTERM terminates by SIGTERM`() {
        let log = EventLog()

        withIsolatedState {
            makeSUT(log: log).handle(signal: SIGTERM)
        }

        #expect(log.entries.last == "terminate: \(SIGTERM)")
    }

    @Test
    func `With no cleanups registered, an interrupt only writes the message and terminates`() {
        let log = EventLog()

        withIsolatedState {
            makeSUT(log: log).handle(signal: SIGINT)
        }

        #expect(log.entries == ["error: \nInterrupted.\n", "terminate: \(SIGINT)"])
    }

    @Test
    func `Installing stores the coordinator in the run's box`() {
        withIsolatedState {
            let box = NnStateScope.requiredBox(for: "NnInterruptCoordinatorTests")
            let sut = NnInterruptCoordinator(box: box, isInterrupting: { false }, terminate: { _ in }, writeError: { _ in })

            let installation = sut.install()
            defer { installation.uninstall() }

            #expect(box[NnInterruptCoordinator.storageKey] as? NnInterruptCoordinator === sut)
        }
    }
}


// MARK: - Real Signals
/// Every real signal is sent inside an exit test's child process. A debugger attached to the test
/// runner, as Xcode's is, stops the process on SIGINT instead of delivering it.
struct NnInterruptRealSignalTests {
    #if compiler(>=6.2)
    @Test
    func `A real SIGINT runs the cleanups, writes the message, and ends the process by SIGINT`() async {
        let result = await #expect(processExitsWith: .signal(SIGINT), observing: [\.standardErrorContent]) {
            withIsolatedState {
                let sut = NnInterruptCoordinator(
                    box: NnStateScope.requiredBox(for: "NnInterruptRealSignalTests"),
                    isInterrupting: { NnInterruptSignal.received != 0 },
                    terminate: { NnInterruptSignal.reraise($0) },
                    writeError: { fputs($0, stderr) }
                )

                NnInterrupt.register(cleanup: { fputs("cleanup ran, recorded signal \(NnInterruptSignal.received)\n", stderr) })
                withExtendedLifetime(sut.install()) {
                    kill(getpid(), SIGINT)
                    sleep(5)
                }
            }
        }

        let errorOutput = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)

        #expect(errorOutput == "cleanup ran, recorded signal \(SIGINT)\n\nInterrupted.\n")
    }

    @Test
    func `Re-raising from a dispatch queue ends the process by the signal rather than a normal exit`() async {
        await #expect(processExitsWith: .signal(SIGINT)) {
            _ = NnInterruptSignal.installHandler(for: SIGINT)
            DispatchQueue(label: "reraise").sync {
                NnInterruptSignal.reraise(SIGINT)
            }
        }
    }

    @Test
    func `A second signal ends the process by that signal while the first is still being handled`() async {
        await #expect(processExitsWith: .signal(SIGINT)) {
            _ = NnInterruptSignal.installHandler(for: SIGINT)
            kill(getpid(), SIGINT)

            // Pending signals coalesce, so the second is only distinct once the first has landed.
            while NnInterruptSignal.received == 0 {
                usleep(1_000)
            }

            kill(getpid(), SIGINT)
            sleep(5)
        }
    }
    #endif
}


// MARK: - SUT
private extension NnInterruptCoordinatorTests {
    func makeSUT(log: EventLog) -> NnInterruptCoordinator {
        return .init(
            box: NnStateScope.requiredBox(for: "NnInterruptCoordinatorTests"),
            isInterrupting: { false },
            terminate: { log.record("terminate: \($0)") },
            writeError: { log.record("error: \($0)") }
        )
    }
}


// MARK: - Test Doubles
private final class EventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    var entries: [String] {
        return lock.withLock { recorded }
    }

    func record(_ entry: String) {
        lock.withLock { recorded.append(entry) }
    }
}
