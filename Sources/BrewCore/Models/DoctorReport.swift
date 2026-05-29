//
//  DoctorReport.swift
//  BrewCore
//

import Foundation

/// Outcome of a `brew doctor` run, parsed into structured issues.
///
/// Actor-neutral domain value (no presentation). A report with no issues means a healthy system —
/// `brew doctor` printed "Your system is ready to brew." rather than any warnings.
public struct DoctorReport: Equatable, Sendable {
    public var issues: [DoctorIssue]

    public init(issues: [DoctorIssue]) {
        self.issues = issues
    }

    /// `true` when `brew doctor` surfaced no warnings.
    public var isHealthy: Bool {
        issues.isEmpty
    }
}

/// One `brew doctor` warning: its summary, explanation, the concrete items it names, and — when the
/// warning embeds a runnable `brew` command — a suggested fix.
public struct DoctorIssue: Equatable, Sendable {
    /// The `Warning:` summary line, without the `Warning:` prefix.
    public var title: String
    /// The explanatory prose Homebrew prints under the summary (item lists removed).
    public var details: String
    /// Concrete things the warning names (e.g. unlinked kegs, offending paths) — single-token body lines.
    public var affectedItems: [String]
    /// A runnable `brew` fix parsed from the warning, or `nil` when no `brew` command could be extracted
    /// (e.g. warnings that only suggest `sudo chown` or manual steps).
    public var suggestedFix: DoctorSuggestedFix?

    public init(
        title: String,
        details: String,
        affectedItems: [String],
        suggestedFix: DoctorSuggestedFix?,
    ) {
        self.title = title
        self.details = details
        self.affectedItems = affectedItems
        self.suggestedFix = suggestedFix
    }
}

/// A `brew` command a `brew doctor` warning suggests running, ready to hand to the command center.
public struct DoctorSuggestedFix: Equatable, Sendable {
    /// Argument vector passed to `brew` (excludes the `brew` program itself), e.g. `["link", "openssl@3"]`.
    public var arguments: [String]
    /// User-facing command string for display/copy, e.g. `"brew link openssl@3"`.
    public var displayCommand: String

    public init(arguments: [String], displayCommand: String) {
        self.arguments = arguments
        self.displayCommand = displayCommand
    }
}
