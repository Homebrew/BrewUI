//
//  CommandJob+Presentation.swift
//  BrewFeatureConsole
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation

extension CommandJob {
    /// Status-dot state for this job: running until terminal, then success/failure by exit code.
    /// Single source of truth for the dot — both the status bar and the toolbar pill bind to it.
    var dotState: ConsoleStatusPresentation.DotState {
        if !isTerminal {
            return .running
        }
        return succeeded ? .succeeded : .failed
    }

    /// Plain-text dump of the output buffer for clipboard / save use. `stderr` lines get a `[stderr] ` prefix
    /// so a reader can disambiguate without losing the timeline.
    func formattedOutputForExport() -> String {
        output.map { line in
            switch line.stream {
            case .stdout:
                line.text
            case .stderr:
                "[stderr] \(line.text)"
            }
        }
        .joined(separator: "\n")
    }

    /// Suggested filename when saving this job's output to disk.
    /// Pattern: `brewui-<sanitized-command>-<yyyy-MM-dd-HHmmss>.log`.
    func suggestedExportFilename(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: now)
        let sanitized = command
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return "brewui-\(sanitized)-\(timestamp).log"
    }
}
