import Foundation
import Synchronization

/// The process-wide record of an interrupt, written by the signal handler and the coordinator's queue.
///
/// Whichever of the two sees the signal first records it, so the flag is set before any cleanup runs
/// and before any error the interrupt causes — a killed child, a cancelled picker — can reach
/// `main()`. The queue can see a signal before the handler does: kqueue notes a signal when it is
/// sent, and the handler runs only once the signal is delivered to a thread.
enum NnInterruptSignal {
    /// The first signal received, or `0` when no interrupt has started.
    static var received: Int32 {
        return receivedSignal.load(ordering: .sequentiallyConsistent)
    }

    /// Records `signo` as the interrupt, unless one is already recorded.
    ///
    /// Async-signal-safe: a single atomic compare-exchange.
    static func record(_ signo: Int32) {
        _ = receivedSignal.compareExchange(expected: 0, desired: signo, ordering: .sequentiallyConsistent)
    }

    /// Installs the handler for `signo` and returns the action it replaced.
    static func installHandler(for signo: Int32) -> sigaction {
        var action = sigaction()
        action.__sigaction_u = __sigaction_u(__sa_handler: signalHandler)
        action.sa_flags = SA_RESTART
        sigemptyset(&action.sa_mask)

        var previous = sigaction()
        sigaction(signo, &action, &previous)

        return previous
    }

    /// Puts back an action saved by ``installHandler(for:)``.
    static func restore(_ previous: sigaction, for signo: Int32) {
        var previous = previous
        sigaction(signo, &previous, nil)
    }

    /// Ends the process by `signo`, so the parent sees it killed by that signal.
    ///
    /// The signal is sent to the process, not the calling thread: this runs on a dispatch queue, and
    /// Darwin's workqueue threads keep signals blocked, so `raise` would never be delivered. If no
    /// thread takes the signal within a second, the process exits with the conventional status instead.
    static func reraise(_ signo: Int32) {
        resetToDefault(signo)
        kill(getpid(), signo)
        sleep(1)
        _exit(128 + signo)
    }
}

// MARK: - Handler
private extension NnInterruptSignal {
    static let receivedSignal = Atomic<Int32>(0)

    /// How many signals the handler has taken. Only the handler counts, so a signal the queue
    /// recorded first is still the handler's first delivery, not a repeat.
    static let deliveries = Atomic<Int32>(0)

    /// Only async-signal-safe work: atomic operations, and on a repeat signal, `sigaction` and `raise`.
    ///
    /// A repeated signal stays blocked until the handler returns, then kills the process by the
    /// default action.
    static let signalHandler: @convention(c) (Int32) -> Void = { signo in
        record(signo)
        let (_, deliveryCount) = deliveries.wrappingAdd(1, ordering: .sequentiallyConsistent)

        if deliveryCount > 1 {
            resetToDefault(signo)
            raise(signo)
        }
    }

    static func resetToDefault(_ signo: Int32) {
        var action = sigaction()
        action.__sigaction_u = __sigaction_u(__sa_handler: SIG_DFL)
        sigemptyset(&action.sa_mask)
        sigaction(signo, &action, nil)
    }
}
