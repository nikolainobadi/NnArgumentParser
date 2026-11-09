//
//  NnTrackedInspector.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 11/3/26.
//

// MARK: - Inspector
public struct NnTrackedInspector<Base: NnInspector> {
    private let base: Base
    private let track: (() async throws -> Base.Facts) async throws -> Base.Facts

    public init(base: Base, track: @escaping (() async throws -> Base.Facts) async throws -> Base.Facts) {
        self.base = base
        self.track = track
    }
}


// MARK: - NnInspector
extension NnTrackedInspector: NnInspector {
    public func inspect() async throws -> Base.Facts {
        return try await track {
            return try await base.inspect()
        }
    }
}
