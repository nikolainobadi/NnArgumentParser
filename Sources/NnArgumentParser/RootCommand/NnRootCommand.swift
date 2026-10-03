//
//  NnRootCommand.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 2/17/26.
//

import Foundation
import ArgumentParser

/// A protocol for root commands that support dependency injection via a context factory.
///
/// Conforming types provide a `Factory` type that creates dependencies needed by subcommands.
/// The factory is stored in thread-local storage, enabling test-time injection without
/// global mutable state.
///
/// ## Example
///
/// ```swift
/// struct MyCommand: NnRootCommand {
///     typealias Factory = MyFactory
///     static var defaultFactory: Factory { MyFactory() }
/// }
/// ```
public protocol NnRootCommand: ParsableCommand {
    /// The type responsible for creating dependencies used by this command and its subcommands.
    associatedtype Factory

    /// The default factory instance used when no test factory is injected.
    static var defaultFactory: Factory { get }
}

// MARK: - Helpers
extension NnRootCommand {
    /// The current context factory for this command type.
    ///
    /// This property uses thread-local storage to enable dependency injection during testing.
    /// In production, it returns ``defaultFactory``. In tests, you can set a custom factory
    /// that will be used for the current thread only.
    ///
    /// - Note: Each thread maintains its own factory instance, making concurrent test
    ///   execution safe.
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
