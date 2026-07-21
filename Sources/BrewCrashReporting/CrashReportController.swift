//
//  CrashReportController.swift
//  Brew
//

import Foundation
import Observation

/// Drives the "you crashed last time" UI: loads reports left by a previous
/// launch, exposes the one currently shown, and handles the user's response.
@MainActor
@Observable
public final class CrashReportController {
    public private(set) var pendingReports: [CrashReport] = []

    private let store: CrashReportStore

    public init(store: CrashReportStore) {
        self.store = store
    }

    public var currentReport: CrashReport? {
        pendingReports.first
    }

    /// Loads persisted reports off the main actor. Called once on launch.
    public func loadPendingReports() async {
        let store = store
        pendingReports = await Task.detached(priority: .utility) {
            store.pendingReports()
        }.value
    }

    public func issueURL(for report: CrashReport) -> URL {
        CrashReportIssue.url(for: report)
    }

    /// Removes `report` from disk and the queue, advancing to the next pending one.
    public func discard(_ report: CrashReport) {
        store.remove(report)
        pendingReports.removeAll { $0.id == report.id }
    }
}
