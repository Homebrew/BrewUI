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

    /// Blocks split into logical groups: a new group starts whenever a `.prose` block appears after a
    /// non-prose block. Almost every check is one group; `check_git_status` is the notable exception
    /// (one group per dirty repo).
    var groups: [[DoctorBlock]] {
        groupBlocks(blocks)
    }

    /// `true` when the issue has multiple subject groups — the detail pane falls back to raw output
    /// for those (escape hatch) so each fix stays bound to its own paths.
    var requiresRawEscapeHatch: Bool {
        groups.count > 1
    }
}

/// One sectioned bucket of issues for the list.
struct DoctorIssueGroup: Identifiable, Equatable {
    let section: DoctorSection
    let items: [DoctorIssueItem]

    var id: DoctorSection {
        section
    }
}

/// Walk the issue's blocks in order; start a new group whenever a `.prose` block follows a non-prose
/// block. Single-group issues render in document order; multi-group issues fall back to raw output.
func groupBlocks(_ blocks: [DoctorBlock]) -> [[DoctorBlock]] {
    var groups: [[DoctorBlock]] = []
    var current: [DoctorBlock] = []
    for (index, block) in blocks.enumerated() {
        if block.type == .prose, index > 0, blocks[index - 1].type != .prose {
            if !current.isEmpty {
                groups.append(current)
            }
            current = [block]
        } else {
            current.append(block)
        }
    }
    if !current.isEmpty {
        groups.append(current)
    }
    return groups
}
