//
//  DoctorIssueItem.swift
//  BrewFeatureDoctor
//

import BrewCore
import Foundation

/// Presentation mapping for a single ``DoctorIssue`` in the list/detail surface.
///
/// `id` is the issue's index within the report so SwiftUI can track row selection across re-renders.
/// The runnable-fix token (the block's `copyAllText`) doubles as the `.maintenance` operation id
/// token, so the view model can match an in-flight fix back to the row that started it.
struct DoctorIssueItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let severity: DoctorSeverity
    let section: DoctorSection
    let blocks: [DoctorBlock]
    let inlineChips: [DoctorBacktickChip]
    let rawBody: String

    init(id: Int, issue: DoctorIssue) {
        self.id = id
        title = issue.title
        severity = issue.severity
        section = issue.section
        blocks = issue.blocks
        inlineChips = issue.inlineChips
        rawBody = issue.rawBody
    }

    /// First runnable command block (single non-admin `brew` step).
    var primaryRunnableBlock: DoctorBlock? {
        blocks.first(where: \.isRunnable)
    }

    /// `true` when ``primaryRunnableBlock`` is non-nil — drives the Run Fix affordance.
    var hasRunnableFix: Bool {
        primaryRunnableBlock != nil
    }

    /// Stable token tracking an in-flight fix — matches the `.maintenance` operation id token.
    var fixToken: String? {
        primaryRunnableBlock?.copyAllText
    }
}

/// One sectioned bucket of issues for the list.
struct DoctorIssueGroup: Identifiable, Equatable {
    let section: DoctorSection
    let items: [DoctorIssueItem]

    var id: DoctorSection {
        section
    }

    /// Buckets the report's issues into curated sections in `DoctorSection` enum order; empty sections
    /// are skipped so the list never shows an empty header. Used by the view model and by the view's
    /// `AsyncContentView` loaded closure (so the redacted placeholder report buckets the same way).
    static func grouped(from report: DoctorReport) -> [DoctorIssueGroup] {
        let items = report.issues.enumerated().map { DoctorIssueItem(id: $0.offset, issue: $0.element) }
        var byScreen: [DoctorSection: [DoctorIssueItem]] = [:]
        for item in items {
            byScreen[item.section, default: []].append(item)
        }
        return DoctorSection.allCases.compactMap { section in
            guard let items = byScreen[section], !items.isEmpty else {
                return nil
            }
            return DoctorIssueGroup(section: section, items: items)
        }
    }
}
