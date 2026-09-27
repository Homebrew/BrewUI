//
//  CrashReport.swift
//  Brew
//

import Foundation

/// One crash report macOS left behind, read on the launch after the crash.
/// `text` is shown to the user verbatim and pasted into a GitHub issue.
public struct CrashReport: Sendable, Equatable, Identifiable {
    /// The report's file name, unique per crash; also its presentation identity.
    public let id: String
    public let capturedAt: Date
    public let text: String

    public init(id: String, capturedAt: Date, text: String) {
        self.id = id
        self.capturedAt = capturedAt
        self.text = text
    }

    /// The first non-empty, non-separator line, used for the issue title.
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
