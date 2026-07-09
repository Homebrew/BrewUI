//
//  CrashReportController.swift
//  Brew
//

import Foundation
import Observation

/// Drives the "you crashed last time" UI. Loads any reports left behind by a
/// previous launch, exposes the one currently being shown, and handles the
/// user's response (file an issue, or discard).
///
/// UI-facing state, so it is `@MainActor`; the actual disk work is hopped off
/// the main actor.
@MainActor
@Observable
public final class CrashReportController {
    /// Reports awaiting the user's attention, oldest first.
    public private(set) var pendingReports: [CrashReport] = []

    private let store: CrashReportStore

    public init(store: CrashReportStore) {
        self.store = store
    }

    /// The report to surface right now, or `nil` when there is nothing to show.
    public var currentReport: CrashReport? {
        pendingReports.first
    }

    /// Loads persisted reports from disk. Called once on launch.
    public func loadPendingReports() async {
        let store = store
        pendingReports = await Task.detached(priority: .utility) {
            store.pendingReports()
        }.value
    }

    /// A pre-filled GitHub issue URL for `report`. Opening it is the caller's
    /// responsibility (via `openURL`), so nothing is transmitted automatically.
    public func issueURL(for report: CrashReport) -> URL {
        CrashReportIssue.url(for: report)
    }

    /// Removes `report` from disk and drops it from the queue, advancing to the
    /// next pending report (if any).
    public func discard(_ report: CrashReport) {
        store.remove(report)
        pendingReports.removeAll { $0.id == report.id }
    }
}
