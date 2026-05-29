//
//  DoctorIssueItem.swift
//  BrewFeatureDoctor
//

import BrewCore
import Foundation

/// Presentation mapping for a single ``DoctorIssue`` in the list/detail surface.
///
/// `id` is the issue's index within the report so SwiftUI can track row selection across re-renders.
/// The fix token (the display command) doubles as the `.maintenance` operation id token, so the view
/// model can match an in-flight fix back to the row that started it.
struct DoctorIssueItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let details: String
    let affectedItems: [String]
    let suggestedFix: DoctorSuggestedFix?

    init(id: Int, issue: DoctorIssue) {
        self.id = id
        title = issue.title
        details = issue.details
        affectedItems = issue.affectedItems
        suggestedFix = issue.suggestedFix
    }

    var hasFix: Bool {
        suggestedFix != nil
    }

    var fixDisplayCommand: String? {
        suggestedFix?.displayCommand
    }

    /// Stable token tracking an in-flight fix — matches the `.maintenance` operation id token.
    var fixToken: String? {
        suggestedFix?.displayCommand
    }
}
