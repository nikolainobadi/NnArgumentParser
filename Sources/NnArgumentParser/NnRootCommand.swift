//
//  NnRootCommand.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 2/17/26.
//

import Foundation
import ArgumentParser

public protocol NnRootCommand: ParsableCommand {
    associatedtype Factory
    static var defaultFactory: Factory { get }
}

extension NnRootCommand {
    public static var contextFactory: Factory {
        get {
            let key = "\(Self.self).contextFactory"
            return Thread.current.threadDictionary[key] as? Factory ?? defaultFactory
        }
        set {
            let key = "\(Self.self).contextFactory"
            Thread.current.threadDictionary[key] = newValue
        }
    }
}
