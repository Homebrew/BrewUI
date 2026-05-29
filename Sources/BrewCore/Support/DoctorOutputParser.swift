//
//  DoctorOutputParser.swift
//  BrewCore
//

import Foundation

/// Pure text→domain parser for `brew doctor` output. No dependencies, no isolation — unit-tested directly.
///
/// `brew doctor` prints a fixed preamble, then a sequence of warning blocks. Each block starts with a
/// `Warning:` line; the lines beneath it are the explanation, any concrete items the warning names
/// (single-token lines such as kegs or paths), and sometimes a runnable command. A block runs until the
/// next `Warning:` line (blank lines inside a block are part of it). A healthy system prints no warnings.
public enum DoctorOutputParser {
    public static func parse(_ output: String) -> DoctorReport {
        let lines = output.components(separatedBy: "\n")
        var blocks: [[String]] = []
        var current: [String]?

        for line in lines {
            if line.hasPrefix("Warning:") {
                if let current {
                    blocks.append(current)
                }
                current = [line]
            } else if current != nil {
                current?.append(line)
            }
        }
        if let current {
            blocks.append(current)
        }

        return DoctorReport(issues: blocks.compactMap(makeIssue))
    }

    private static func makeIssue(from block: [String]) -> DoctorIssue? {
        guard let header = block.first else {
            return nil
        }
        let title = String(header.dropFirst("Warning:".count)).trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else {
            return nil
        }

        let body = Array(block.dropFirst())
        var affectedItems: [String] = []
        var detailLines: [String] = []
        for line in body {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                continue
            }
            if isItem(trimmed) {
                affectedItems.append(trimmed)
            } else {
                detailLines.append(trimmed)
            }
        }

        return DoctorIssue(
            title: title,
            details: detailLines.joined(separator: " "),
            affectedItems: affectedItems,
            suggestedFix: suggestedFix(detailLines: detailLines, affectedItems: affectedItems),
        )
    }

    /// A body line names a concrete item when it is a single whitespace-free token (a keg name, a path).
    /// Explanatory prose and suggested shell commands contain spaces, so they fall through to details.
    private static func isItem(_ trimmed: String) -> Bool {
        !trimmed.contains(where: \.isWhitespace)
    }

    /// Extracts a runnable `brew` fix, preferring a standalone `brew …` command line, then a backticked
    /// `` `brew …` `` reference embedded in prose. A verb-only command (e.g. `brew link`) is completed with
    /// the warning's affected items so the fix actually targets them.
    private static func suggestedFix(detailLines: [String], affectedItems: [String]) -> DoctorSuggestedFix? {
        guard let arguments = brewArguments(in: detailLines) else {
            return nil
        }
        let completed = arguments.count == 1 && !affectedItems.isEmpty
            ? arguments + affectedItems
            : arguments
        return DoctorSuggestedFix(
            arguments: completed,
            displayCommand: "brew " + completed.joined(separator: " "),
        )
    }

    /// Returns the `brew` argument vector (excluding the `brew` program word), or `nil` if none is present.
    private static func brewArguments(in detailLines: [String]) -> [String]? {
        for line in detailLines {
            if line == "brew" || line.hasPrefix("brew ") {
                return tokens(after: line)
            }
        }
        for line in detailLines {
            let segments = line.components(separatedBy: "`")
            // Backticked spans sit at odd indices once split on the backtick delimiter.
            var index = 1
            while index < segments.count {
                let candidate = segments[index].trimmingCharacters(in: .whitespaces)
                if candidate == "brew" || candidate.hasPrefix("brew ") {
                    return tokens(after: candidate)
                }
                index += 2
            }
        }
        return nil
    }

    /// Splits a `brew …` command into its arguments, dropping the leading `brew`. Returns `nil` for a bare
    /// `brew` with no actionable arguments.
    private static func tokens(after command: String) -> [String]? {
        var arguments = command.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !arguments.isEmpty else {
            return nil
        }
        arguments.removeFirst()
        return arguments.isEmpty ? nil : arguments
    }
}
