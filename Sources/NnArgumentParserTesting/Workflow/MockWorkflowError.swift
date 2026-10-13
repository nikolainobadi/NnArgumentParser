//
//  MockWorkflowError.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/12/26.
//

// Thrown by the workflow mocks when created with throwError true, for exercising error paths.
public enum MockWorkflowError: Error, Equatable {
    case stageFailed
}
