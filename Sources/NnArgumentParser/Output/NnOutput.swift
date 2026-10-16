//
//  NnOutput.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Foundation

/// Writes a command's output: to stdout in production, and to the run's own buffer under `testRun`.
///
/// Use this instead of `print` so `testRun` can capture output per run without redirecting the
/// process's stdout, which lets command tests run in parallel.
public enum NnOutput {
    public static func write(_ text: String) {
        guard let buffer = NnStateScope.box?[NnOutputBuffer.storageKey] as? NnOutputBuffer else {
            print(text)
            return
        }

        buffer.append(text + "\n")
    }
}

/// Collects ``NnOutput`` writes for one run.
package final class NnOutputBuffer: @unchecked Sendable {
    package static let storageKey = "NnArgumentParser.NnOutput.buffer"

    private let lock = NSLock()
    private var text = ""

    package init() { }

    package var contents: String {
        return lock.withLock { text }
    }

    func append(_ newText: String) {
        lock.withLock { text += newText }
    }
}
