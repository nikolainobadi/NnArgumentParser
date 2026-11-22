//
//  NnCheckGroup.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 11/22/26.
//

// MARK: - Check Group
public struct NnCheckGroup<each Check: NnRunnableCheck> {
    private let checks: (repeat each Check)

    public init(_ checks: repeat each Check) {
        self.checks = (repeat each checks)
    }
}

// MARK: - NnRunnableCheck
extension NnCheckGroup: NnRunnableCheck {
    public func run() async throws {
        for check in repeat each checks {
            try await check.run()
        }
    }
}
