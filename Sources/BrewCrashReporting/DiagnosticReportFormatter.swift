//
//  DiagnosticReportFormatter.swift
//  Brew
//

import Foundation

/// Same header shape as the reports the app used to write itself, so ``CrashReport/summary`` still applies.
enum DiagnosticReportFormatter {
    /// The dialog lays the whole text out at once, so a backtrace is cut rather than shown in full.
    static let maximumFrames = 64

    static func makeReportText(_ report: DiagnosticReport) -> String {
        var lines = [
            "Homebrew.app crash report",
            "=========================",
            "Date: \(report.capturedAt.ISO8601Format())",
            "App version: \(report.appVersion) (\(report.buildNumber))",
            "macOS: \(report.osVersion)",
            "Exception: \(report.exceptionSummary)",
        ]
        if let reason = report.terminationReason {
            lines.append("Termination: \(reason)")
        }
        if !report.applicationSpecificInformation.isEmpty {
            lines.append("")
            lines.append("Application Specific Information:")
            lines += report.applicationSpecificInformation
        }
        if !report.lastExceptionBacktrace.isEmpty {
            lines.append("")
            lines.append("Last Exception Backtrace:")
            lines += formatted(report.lastExceptionBacktrace)
        }
        lines.append("")
        lines.append("\(report.crashedThreadLabel) crashed:")
        lines += formatted(report.crashedThreadFrames)
        return lines.joined(separator: "\n")
    }

    private static func formatted(_ frames: [DiagnosticReport.Frame]) -> [String] {
        var lines = frames.prefix(maximumFrames).enumerated().map { index, frame in
            var location: String
            if let symbol = frame.symbol {
                location = symbol
                if let offset = frame.symbolOffset {
                    location += " + \(offset)"
                }
            } else {
                location = "0x" + String(frame.imageOffset, radix: 16)
            }
            if let file = frame.sourceFile, let line = frame.sourceLine {
                location += " (\(file):\(line))"
            }
            return "\(index)\t\(frame.imageName)\t\(location)"
        }
        if frames.count > maximumFrames {
            lines.append("… \(frames.count - maximumFrames) more frames …")
        }
        return lines
    }
}
