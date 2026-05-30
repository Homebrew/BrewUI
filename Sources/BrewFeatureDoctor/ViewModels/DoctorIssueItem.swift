//
//  DoctorIssueItem.swift
//  BrewFeatureDoctor
//

import BrewCore
import Foundation

/// Presentation mapping for a single ``DoctorIssue`` in the list/detail surface.
///
/// `id` is the issue's index within the report so SwiftUI can track row selection across re-renders.
/// The runnable-fix token (the sequence's `copyAllText`) doubles as the `.maintenance` operation id token,
/// so the view model can match an in-flight fix back to the row that started it.
struct DoctorIssueItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let severity: DoctorSeverity
    let details: String
    let affectedItems: [String]
    let inlineChips: [DoctorBacktickChip]
    let fixSequences: [DoctorFixSequence]
    let links: [DoctorLink]
    let rawBody: String

    init(id: Int, issue: DoctorIssue) {
        self.id = id
        title = issue.title
        severity = issue.severity
        details = issue.details
        affectedItems = issue.affectedItems
        inlineChips = issue.inlineChips
        fixSequences = issue.fixSequences
        links = issue.links
        rawBody = issue.rawBody
    }

    /// The first single-step, non-admin `brew` sequence we can submit through the command center.
    var primaryRunnableSequence: DoctorFixSequence? {
        fixSequences.first(where: \.isRunnable)
    }

    /// `true` when ``primaryRunnableSequence`` is non-nil — drives the Run Fix affordance.
    var hasRunnableFix: Bool {
        primaryRunnableSequence != nil
    }

    /// Stable token tracking an in-flight fix — matches the `.maintenance` operation id token.
    var fixToken: String? {
        primaryRunnableSequence?.copyAllText
    }
}
