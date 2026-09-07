//
//  KeyValueArgument.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 9/6/26.
//

import ArgumentParser

/// A `<key>=<value>` pair, so one repeatable option can carry a setting per key without the caller
/// repeating the whole command for each one.
///
/// ArgumentParser ships no conformance for this shape, but it is the conventional way to attach a
/// value to a named thing on the command line — `--project-type core=library`,
/// `--build-command core=swift build`.
///
/// ## Example
///
/// ```swift
/// struct BuildOptions: ParsableArguments {
///     @Option(name: .customLong("build-command"), parsing: .singleValue, help: "A target's build command, as <target>=<command>.")
///     var build: [KeyValueArgument] = []
///
///     var buildCommands: [String: String] {
///         return build.asDictionary()
///     }
/// }
/// ```
///
/// - Note: The help text is where the `<key>=<value>` shape gets advertised. ArgumentParser renders
///   the option as a bare `--build-command <build-command>` otherwise, and a failable initializer
///   cannot explain what it rejected — `--build-command core` fails with only "The value 'core' is
///   invalid for '--build-command <build-command>'".
public struct KeyValueArgument: Equatable, Hashable, Sendable, ExpressibleByArgument {
    /// The text before the first `=`.
    public let key: String

    /// The text after the first `=`, which may itself contain `=`.
    public let value: String

    /// Splits `argument` on its first `=`.
    ///
    /// Everything after that separator is the value, so a value may contain further `=` characters
    /// — `core=swift test --filter=Foo` yields the whole `swift test --filter=Foo`. Returns `nil`
    /// when the separator is absent or either side of it is empty.
    ///
    /// Surrounding whitespace is kept. Values are typically shell commands, where trimming could
    /// change what runs.
    public init?(argument: String) {
        let parts = argument.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)

        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            return nil
        }

        self.key = String(parts[0])
        self.value = String(parts[1])
    }
}


// MARK: - Collection
public extension Array where Element == KeyValueArgument {
    /// Folds the pairs into a dictionary keyed by ``KeyValueArgument/key``.
    ///
    /// A key given more than once resolves to the last value, matching how a caller would expect a
    /// repeated flag to behave — the later `--project-type core=library` wins.
    func asDictionary() -> [String: String] {
        return reduce(into: [:], { $0[$1.key] = $1.value })
    }
}
