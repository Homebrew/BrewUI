//
//  CommandFailureDetail.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Picks the text that explains a non-zero exit.
///
/// A pipe-backed run keeps the streams apart, so stderr is the answer. A terminal-backed run merges them
/// into one device, leaving ``CommandOutput/standardError`` empty and the transcript as the only account
/// of what went wrong — without this, every failed install would reach the user as a bare exit code.
enum CommandFailureDetail {
    /// Brew's own errors are the last thing it prints, and this text goes into an error banner rather
    /// than a log pane, so the transcript is trimmed to its tail.
    static let maxTranscriptLines = 20

    static func detail(from output: CommandOutput) -> String {
        guard output.standardError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return output.standardError
        }
        return tail(of: output.standardOutput, lines: maxTranscriptLines)
    }

    static func tail(of text: String, lines limit: Int) -> String {
        let all = text.split(separator: "\n", omittingEmptySubsequences: false)
        // A trailing newline leaves an empty final element that would otherwise use up one of the slots.
        let meaningful = all.last?.isEmpty == true ? all.dropLast() : all[...]
        return meaningful.suffix(limit).joined(separator: "\n")
    }
}
