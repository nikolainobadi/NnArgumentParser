//
//  NnRootCommand+RunOutcome.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/25/26.
//

import ArgumentParser

extension NnRootCommand {
    /// The outcome observers are told for `result`, using this command's own error message and exit code.
    ///
    /// An error whose exit code is `ExitCode.success`, such as `CleanExit`, counts as success.
    package static func runOutcome(for result: Result<Void, any Error>) -> NnRunOutcome {
        switch result {
        case .success:
            return .succeeded
        case .failure(let error):
            let code = exitCode(for: error)

            if code == .success {
                return .succeeded
            }

            return .failed(message: message(for: error), exitCode: code.rawValue)
        }
    }
}
