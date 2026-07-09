//
//  CrashReport.swift
//  Brew
//

import Foundation

/// A single persisted crash report, read back from disk on the launch *after*
/// the crash occurred.
///
/// The `text` is the full, human-readable report exactly as written at crash
/// time — it is what gets shown to the user and pasted into a GitHub issue, so
/// it is stored verbatim rather than as a `Codable` model. Deliberately not
/// `Codable`: the on-disk artifact is plain text, not an encoded value type.
public struct CrashReport: Sendable, Equatable, Identifiable {
    /// The report's file name (unique per crash); doubles as a stable identity
    /// for SwiftUI list/sheet presentation.
    public let id: String
    /// When the crash was captured, derived from the file name timestamp.
    public let capturedAt: Date
    /// The full report body (header + call stack).
    public let text: String

    public init(id: String, capturedAt: Date, text: String) {
        self.id = id
        self.capturedAt = capturedAt
        self.text = text
    }

    /// A one-line summary — the first non-empty, non-separator line of the
    /// report — used for the GitHub issue title and any compact UI.
    public var summary: String {
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.allSatisfy({ $0 == "=" || $0 == "-" }) {
                continue
            }
            return trimmed
        }
        return "Unexpected crash"
    }
}
