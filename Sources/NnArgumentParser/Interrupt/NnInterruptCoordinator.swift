//
//  NnInterruptCoordinator.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Foundation

/// Turns SIGINT and SIGTERM into one orderly shutdown: the run's cleanups, `Interrupted.`, then
/// the process ending by the signal.
///
/// The signal handler only records the signal (``NnInterruptSignal``). The cleanup work runs on a
/// dispatch source, which kqueue fires for every delivered signal whatever its disposition. A
/// second signal is handled by the signal handler itself, because this queue is busy with cleanups.
final class NnInterruptCoordinator: Sendable {
    private let box: NnStateBox
    private let interruptState: @Sendable () -> Bool
    private let terminate: @Sendable (Int32) -> Void
    private let writeError: @Sendable (String) -> Void
    private let queue = DispatchQueue(label: "NnArgumentParser.interrupt")

    /// - Parameters:
    ///   - box: The run's state, read for cleanups because the queue runs outside any task.
    ///   - isInterrupting: Whether an interrupt has started. Production reads ``NnInterruptSignal/received``.
    ///   - terminate: Ends the process by the given signal. Production passes ``NnInterruptSignal/reraise(_:)``.
    ///   - writeError: Writes to stderr.
    init(
        box: NnStateBox,
        isInterrupting: @escaping @Sendable () -> Bool,
        terminate: @escaping @Sendable (Int32) -> Void,
        writeError: @escaping @Sendable (String) -> Void
    ) {
        self.box = box
        self.interruptState = isInterrupting
        self.terminate = terminate
        self.writeError = writeError
    }
}

// MARK: - Actions
extension NnInterruptCoordinator {
    static let handledSignals = [SIGINT, SIGTERM]

    /// Whether an interrupt has started.
    var isInterrupting: Bool {
        return interruptState()
    }

    /// Whether the coordinator installed in `box`, if any, reports an interrupt.
    ///
    /// Reads the box rather than ``NnInterruptSignal`` directly, so a run without a coordinator —
    /// every `testRun` — is never affected by an interrupt elsewhere in the process.
    static func isInterrupting(in box: NnStateBox?) -> Bool {
        let coordinator = box?[storageKey] as? NnInterruptCoordinator

        return coordinator?.isInterrupting ?? false
    }

    /// Installs the signal handlers and sources, and stores this coordinator in the run's box.
    ///
    /// Keep the returned installation for as long as interrupts should be handled.
    ///
    /// - Note: Code that changes these signals' handlers afterwards must restore this one, or
    ///   interrupts stop being recorded.
    func install() -> NnInterruptInstallation {
        var sources: [any DispatchSourceSignal] = []
        var previousActions: [Int32: sigaction] = [:]

        for signo in Self.handledSignals {
            previousActions[signo] = NnInterruptSignal.installHandler(for: signo)

            let source = DispatchSource.makeSignalSource(signal: signo, queue: queue)
            source.setEventHandler {
                self.handle(signal: signo)
            }
            source.resume()
            sources.append(source)
        }

        box[Self.storageKey] = self

        return .init(sources: sources, previousActions: previousActions)
    }

    /// Runs the cleanups last-registered-first, writes `Interrupted.`, then terminates by `signo`.
    func handle(signal signo: Int32) {
        for cleanup in NnInterrupt.cleanups(in: box) {
            cleanup()
        }

        writeError("\nInterrupted.\n")
        terminate(signo)
    }
}

// MARK: - Constants
extension NnInterruptCoordinator {
    static var storageKey: String {
        return "NnArgumentParser.NnInterrupt.coordinator"
    }
}

/// The signal handlers and sources one ``NnInterruptCoordinator/install()`` put in place.
struct NnInterruptInstallation: Sendable {
    let sources: [any DispatchSourceSignal]
    let previousActions: [Int32: sigaction]

    /// Stops the sources and restores the handlers that were in place before, for tests.
    func uninstall() {
        for source in sources {
            source.cancel()
        }

        for (signo, previous) in previousActions {
            NnInterruptSignal.restore(previous, for: signo)
        }
    }
}
