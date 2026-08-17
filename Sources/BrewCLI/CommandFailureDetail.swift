//
//  CommandFailureDetail.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Picks the text that explains a non-zero exit. A terminal-backed run merges the streams, leaving
/// ``CommandOutput/standardError`` empty and the transcript as the only account of what went wrong.
enum CommandFailureDetail {
    /// It goes into an error banner, not a log pane, and brew prints its errors last.
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
