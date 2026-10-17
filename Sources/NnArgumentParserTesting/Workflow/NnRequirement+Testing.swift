//
//  NnRequirement+Testing.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/17/26.
//

import NnArgumentParser

public extension NnRequirement {
    var knownValue: Value? {
        guard case .known(let value) = self else {
            return nil
        }

        return value
    }

    var unknownInfo: Info? {
        guard case .unknown(let info) = self else {
            return nil
        }

        return info
    }
}
