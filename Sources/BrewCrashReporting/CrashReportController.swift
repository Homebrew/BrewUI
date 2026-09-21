//
//  CrashReportController.swift
//  Brew
//

import Foundation
import Observation

/// Drives the "you crashed last time" UI: surfaces the crash reports macOS wrote since the user
/// last acknowledged one, exposes the one currently shown, and handles the user's response.
@MainActor
@Observable
public final class CrashReportController {
    public private(set) var pendingReports: [CrashReport] = []

    private let directory: DiagnosticReportDirectory
    private let defaults: UserDefaults
    private let acknowledgedKey: String

    public init(
        directory: DiagnosticReportDirectory = DiagnosticReportDirectory(),
        defaults: UserDefaults = .standard,
        defaultsKeyPrefix: String = "CrashReports",
    ) {
        self.directory = directory
        self.defaults = defaults
        acknowledgedKey = "\(defaultsKeyPrefix).acknowledgedThrough"
    }

    public var currentReport: CrashReport? {
        pendingReports.first
    }

    public func loadPendingReports() async {
        let directory = directory
        let acknowledgedThrough = acknowledgedThrough
        pendingReports = await Task.detached(priority: .utility) {
            directory.reports(capturedAfter: acknowledgedThrough).map { fileName, report in
                CrashReport(
                    id: fileName,
                    capturedAt: report.capturedAt,
                    text: DiagnosticReportFormatter.makeReportText(report),
                )
            }
        }.value
    }

    public func issueURL(for report: CrashReport) -> URL {
        CrashReportIssue.url(for: report)
    }

    /// Acknowledges `report` and advances to the next pending one. The file stays on disk: it is
    /// macOS's log, and the issue asks the user to attach it when the body was truncated.
    public func discard(_ report: CrashReport) {
        if report.capturedAt > acknowledgedThrough {
            defaults.set(report.capturedAt.timeIntervalSince1970, forKey: acknowledgedKey)
        }
        pendingReports.removeAll { $0.id == report.id }
    }

    private var acknowledgedThrough: Date {
        guard defaults.object(forKey: acknowledgedKey) != nil else {
            return .distantPast
        }
        return Date(timeIntervalSince1970: defaults.double(forKey: acknowledgedKey))
    }
}
