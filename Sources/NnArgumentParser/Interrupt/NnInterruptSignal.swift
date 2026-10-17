//
//  NnInterruptSignal.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Foundation
import Synchronization

/// The process-wide record of an interrupt, written by the signal handler itself.
///
/// The handler runs the moment a signal is delivered, so the flag is set before any error the
/// interrupt causes — a killed child, a cancelled picker — can reach `main()`. Everything slower
/// happens later, on the coordinator's queue.
enum NnInterruptSignal {
    /// The first signal received, or `0` when no interrupt has started.
    static var received: Int32 {
        return receivedSignal.load(ordering: .sequentiallyConsistent)
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

    /// Only async-signal-safe work: an atomic exchange, and on a repeat signal, `sigaction` and `raise`.
    ///
    /// A repeated signal stays blocked until the handler returns, then kills the process by the
    /// default action.
    static let signalHandler: @convention(c) (Int32) -> Void = { signo in
        let (isFirst, _) = receivedSignal.compareExchange(expected: 0, desired: signo, ordering: .sequentiallyConsistent)

        if !isFirst {
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
