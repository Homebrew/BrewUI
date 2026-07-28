//
//  CrashReportFormatter.swift
//  Brew
//

import Foundation

/// Builds the human-readable text of a crash report.
enum CrashReportFormatter {
    /// The header a signal handler writes before its raw `backtrace_symbols_fd`
    /// dump, so it ends with a `Call stack:` marker and newline. Must be built
    /// before the crash — string building is not async-signal-safe.
    static func signalReportHeader(
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

    static func makeReportText(
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
        """
        Date: \(date.ISO8601Format())
        App version: \(environment.appVersion) (\(environment.buildNumber))
        macOS: \(environment.osVersion)
        """
    }
}
