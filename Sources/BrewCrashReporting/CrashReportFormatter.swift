//
//  CrashReportFormatter.swift
//  Brew
//

import Foundation

/// Builds the human-readable text of a crash report.
///
/// Two entry points, matching the two capture paths:
/// - ``signalReportHeader(environment:date:)`` produces the fixed header string
///   that a signal handler writes ahead of a raw `backtrace_symbols_fd` dump.
///   It must be fully materialised *before* the crash (at install time) because
///   building strings inside a signal handler is not async-signal-safe.
/// - ``makeReportText(kind:detail:callStack:environment:date:)`` builds a
///   complete report for the uncaught-exception path, where Foundation is safe
///   to use.
public enum CrashReportFormatter {
    /// The header written before a signal handler's raw stack dump. The call
    /// stack itself is appended by `backtrace_symbols_fd`, so this ends with a
    /// `Call stack:` marker and trailing newline.
    public static func signalReportHeader(
        environment: CrashReportEnvironment,
        date: Date,
    ) -> String {
        """
        Homebrew.app crash report
        =========================
        \(environmentLines(environment: environment, date: date))
        Type: Fatal signal

        Call stack:
        """ + "\n"
    }

    /// A complete report for the uncaught-exception path.
    public static func makeReportText(
        kind: String,
        detail: String?,
        callStack: [String],
        environment: CrashReportEnvironment,
        date: Date,
    ) -> String {
        var lines = """
        Homebrew.app crash report
        =========================
        \(environmentLines(environment: environment, date: date))
        Type: \(kind)
        """

        if let detail, !detail.isEmpty {
            lines += "\nReason: \(detail)"
        }

        lines += "\n\nCall stack:\n"
        lines += callStack.joined(separator: "\n")
        return lines
    }

    private static func environmentLines(
        environment: CrashReportEnvironment,
        date: Date,
    ) -> String {
        // `ISO8601Format()` is a `Sendable` value-type formatter — stable,
        // sortable, and readable in a GitHub issue.
        """
        Date: \(date.ISO8601Format())
        App version: \(environment.appVersion) (\(environment.buildNumber))
        macOS: \(environment.osVersion)
        """
    }
}
