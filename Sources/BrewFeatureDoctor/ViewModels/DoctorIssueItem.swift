//
//  DoctorIssueItem.swift
//  BrewFeatureDoctor
//

import BrewCore
import Foundation

/// Presentation mapping for a single ``DoctorIssue`` in the list/detail surface.
///
/// `id` is a stable FNV-1a hash of the issue's `title` and `rawBody`, so SwiftUI selection tracks the
/// same issue across reloads even when its position in `report.issues` shifts after a fix resolves a
/// different issue. Deterministic across launches (unlike `Swift.Hasher`, which is seeded per run).
/// The runnable-fix token (the single brew step's `displayCommand`) doubles as the `.maintenance`
/// operation id token, so the view model can match an in-flight fix back to the row that started it.
struct DoctorIssueItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let severity: DoctorSeverity
    let blocks: [DoctorBlock]
    let rawBody: String

    init(issue: DoctorIssue) {
        id = Self.contentID(for: issue)
        title = issue.title
        severity = issue.severity
        blocks = issue.blocks
        rawBody = issue.rawBody
    }

    /// Stable FNV-1a 64-bit hash of `title` + `rawBody`, truncated to platform `Int`. Exposed so the
    /// view model can probe membership without rebuilding items.
    static func contentID(for issue: DoctorIssue) -> Int {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        let prime: UInt64 = 0x100_0000_01B3
        for byte in "\(issue.title)\n\(issue.rawBody)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return Int(bitPattern: UInt(hash))
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

    /// Label for voiceover mode — combines title with Fix available
    var accessibilityLabel: String {
        hasRunnableFix ? "\(title), Fix available" : title
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
        let items = report.issues.map { DoctorIssueItem(issue: $0) }
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
