//
//  DoctorIssueItem.swift
//  BrewFeatureDoctor
//

import BrewCore
import Foundation

/// Presentation mapping for a single ``DoctorIssue`` in the list/detail surface.
///
/// `id` is the issue's index within the report so SwiftUI can track row selection across re-renders.
/// The runnable-fix token (the single brew step's `displayCommand`) doubles as the `.maintenance`
/// operation id token, so the view model can match an in-flight fix back to the row that started it.
struct DoctorIssueItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let severity: DoctorSeverity
    let blocks: [DoctorBlock]
    let rawBody: String

    init(id: Int, issue: DoctorIssue) {
        self.id = id
        title = issue.title
        severity = issue.severity
        blocks = issue.blocks
        rawBody = issue.rawBody
    }

    /// First runnable command block (single non-admin `brew` step).
    var primaryRunnableBlock: DoctorBlock? {
        blocks.first(where: \.isRunnable)
    }

    /// The single brew step that backs ``primaryRunnableBlock``, when one exists.
    var primaryRunnableStep: DoctorFixStep? {
        primaryRunnableBlock?.runnableStep
    }

    /// `true` when ``primaryRunnableBlock`` is non-nil — drives the Run Fix affordance.
    var hasRunnableFix: Bool {
        primaryRunnableBlock != nil
    }

    /// Stable token tracking an in-flight fix — matches the `.maintenance` operation id token.
    var fixToken: String? {
        primaryRunnableStep?.displayCommand
    }
}

/// One severity-keyed bucket of issues for the list, ordered most-severe first.
struct DoctorIssueGroup: Identifiable, Equatable {
    let severity: DoctorSeverity
    let items: [DoctorIssueItem]

    var id: DoctorSeverity {
        severity
    }

    /// Buckets the report's issues by severity in descending-severity order; empty buckets are skipped
    /// so the list never shows an empty header. Used by the view model and by the view's
    /// `AsyncContentView` loaded closure (so the redacted placeholder report buckets the same way).
    static func grouped(from report: DoctorReport) -> [DoctorIssueGroup] {
        let items = report.issues.enumerated().map { DoctorIssueItem(id: $0.offset, issue: $0.element) }
        var bySeverity: [DoctorSeverity: [DoctorIssueItem]] = [:]
        for item in items {
            bySeverity[item.severity, default: []].append(item)
        }
        let order: [DoctorSeverity] = [.unsupported, .danger, .caution]
        return order.compactMap { severity in
            guard let items = bySeverity[severity], !items.isEmpty else {
                return nil
            }
            return DoctorIssueGroup(severity: severity, items: items)
        }
    }
}
