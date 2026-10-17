//
//  NnBlockingTolerantExecutor.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Dispatch

/// Runs workflow jobs on a concurrent dispatch queue instead of the cooperative pool, so a stage
/// that blocks — a synchronous shell call inside a task group — ties up a replaceable dispatch
/// thread rather than one of the pool's core-count threads.
final class NnBlockingTolerantExecutor: TaskExecutor, @unchecked Sendable {
    static let shared = NnBlockingTolerantExecutor()

    private let queue = DispatchQueue(label: "NnArgumentParser.workflow", attributes: .concurrent)

    func enqueue(_ job: consuming ExecutorJob) {
        let unownedJob = UnownedJob(job)
        let executor = asUnownedTaskExecutor()

        queue.async {
            unownedJob.runSynchronously(on: executor)
        }
    }
}
