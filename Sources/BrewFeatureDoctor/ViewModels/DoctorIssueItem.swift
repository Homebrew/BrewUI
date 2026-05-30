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

    // MARK: - Detail rendering

    /// Detail-pane render groups. Almost every check produces one group (all prose merged into one
    /// "What this means" at the top, with the subject blocks listed below). A new group starts only
    /// when a paragraph begins with leading prose **and** the current group already has subject
    /// blocks — the `check_git_status` shape, where each dirty repo is its own subject.
    var presentationGroups: [DoctorPresentationGroup] {
        var groups: [DoctorPresentationGroup] = []
        var currentProse: [String] = []
        var currentSubjects: [DoctorBlock] = []

        for paragraph in paragraphsOf(blocks) {
            let leadsWithProse = paragraph.first?.type == .prose
            if leadsWithProse, !currentSubjects.isEmpty {
                groups.append(DoctorPresentationGroup(
                    id: groups.count,
                    proseLines: currentProse,
                    subjectBlocks: currentSubjects,
                ))
                currentProse = []
                currentSubjects = []
            }
            for block in paragraph {
                if case let .prose(lines) = block.content {
                    currentProse.append(contentsOf: lines)
                } else {
                    currentSubjects.append(block)
                }
            }
        }
        if !currentProse.isEmpty || !currentSubjects.isEmpty {
            groups.append(DoctorPresentationGroup(
                id: groups.count,
                proseLines: currentProse,
                subjectBlocks: currentSubjects,
            ))
        }
        return groups
    }
}

/// One "What this means" + subject blocks render group.
struct DoctorPresentationGroup: Identifiable, Equatable {
    let id: Int
    let proseLines: [String]
    /// `.command` / `.data` / `.link` blocks in document order. `.prose` blocks have been folded into
    /// ``proseLines`` already.
    let subjectBlocks: [DoctorBlock]
}

/// One sectioned bucket of issues for the list.
struct DoctorIssueGroup: Identifiable, Equatable {
    let section: DoctorSection
    let items: [DoctorIssueItem]

    var id: DoctorSection {
        section
    }
}

/// Groups consecutive blocks by their `paragraphIndex`, preserving document order within each
/// paragraph.
private func paragraphsOf(_ blocks: [DoctorBlock]) -> [[DoctorBlock]] {
    var result: [[DoctorBlock]] = []
    var lastIndex = -1
    for block in blocks {
        if block.paragraphIndex != lastIndex {
            result.append([block])
            lastIndex = block.paragraphIndex
        } else {
            result[result.count - 1].append(block)
        }
    }
    return result
}
