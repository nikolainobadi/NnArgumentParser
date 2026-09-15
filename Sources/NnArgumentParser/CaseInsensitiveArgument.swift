//
//  CaseInsensitiveArgument.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 9/6/26.
//

import ArgumentParser

/// An `ExpressibleByArgument` enum whose values parse regardless of letter case.
///
/// ArgumentParser already gives any `CaseIterable & RawRepresentable` enum both `allValueStrings`
/// and an `init?(argument:)` for free, but that initializer is **case-sensitive** — `--scope Staged`
/// fails where `--scope staged` succeeds. Conforming to this protocol replaces only the
/// initializer; everything else stays as ArgumentParser provides it.
///
/// ## Example
///
/// ```swift
/// enum DiscardScope: String, CaseIterable, CaseInsensitiveArgument {
///     case staged, unstaged, both
/// }
///
/// // --scope staged, --scope Staged and --scope STAGED all parse to the same case.
/// ```
///
/// For an enum declared in another module, conform retroactively:
///
/// ```swift
/// extension OptionalComponent: @retroactive CaseInsensitiveArgument { }
/// ```
///
/// - Important: Only *parsing* becomes case-insensitive. `--help`, shell completion,
///   `init?(rawValue:)` and any synthesized `Codable` conformance all still use the exact
///   `rawValue`. A tool that accepts `--format JSON` will still reject `"JSON"` read from a config
///   file, and its help will advertise only `json`.
/// - Note: The enum must already be `CaseIterable`. Adding that conformance retroactively to a type
///   from another package means hand-writing `allCases`, which silently goes stale when that package
///   adds a case — the failure this protocol exists to prevent.
public protocol CaseInsensitiveArgument: ExpressibleByArgument, CaseIterable, RawRepresentable
where RawValue == String { }


// MARK: - Parsing
public extension CaseInsensitiveArgument {
    /// Matches `argument` against each case's `rawValue`, preferring an exact match.
    ///
    /// The exact-match pass runs first so that an enum whose raw values differ only by letter case
    /// keeps every case reachable. Without it, both `"run"` and `"RUN"` would resolve to whichever
    /// case `allCases` happens to yield first, leaving the other unreachable with no diagnostic.
    init?(argument: String) {
        if let exact = Self(rawValue: argument) {
            self = exact
            return
        }

        guard let match = Self.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(argument) == .orderedSame }) else {
            return nil
        }

        self = match
    }
}
