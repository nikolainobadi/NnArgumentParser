//
//  NnOutputWriter.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

/// Receives command output from ``NnOutput/write(_:)`` when a run registers it.
///
/// Register one to route output through an app-provided sink, such as a log, a TUI, or a
/// progress display that must coordinate each write with its own redraws.
///
/// - Important: `write(_:)` must deliver `text` before it returns, preserve call order, and be
///   safe to call from several tasks at once. Callers rely on this for ordered output and for
///   nothing being lost when the process exits.
public protocol NnOutputWriter: Sendable {
    /// Writes `text` exactly as passed to ``NnOutput/write(_:)``, without a trailing newline;
    /// the writer terminates the line, as `print` does.
    func write(_ text: String)
}
