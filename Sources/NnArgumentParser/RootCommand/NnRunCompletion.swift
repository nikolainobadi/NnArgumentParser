//
//  NnRunCompletion.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

/// What ``NnRootCommand/main()`` does once the command has run.
enum NnRunCompletion {
    /// Return normally, as ArgumentParser does after a successful run.
    case finish

    /// Print the error and exit, as ArgumentParser does after a failed run.
    case exit(any Error)

    /// Wait without printing or exiting, so the interrupt's cleanups end the process.
    case park
}

extension NnRunCompletion {
    /// Parks whenever an interrupt has started, whatever the outcome: an error caused by the
    /// interrupt, a killed child or a cancelled prompt, must not be reported as the command's own.
    init(outcome: Result<Void, any Error>, isInterrupting: Bool) {
        if isInterrupting {
            self = .park
            return
        }

        switch outcome {
        case .success:
            self = .finish
        case .failure(let error):
            self = .exit(error)
        }
    }
}
