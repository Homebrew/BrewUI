//
//  ConsoleBody.swift
//  Brew
//

import BrewUIComponents
import SwiftUI

/// Output area of the expanded console.
struct ConsoleBody: View {
    let viewModel: ConsoleViewModel

    var body: some View {
        switch viewModel.bodyContent {
        case .noActivity:
            ContentUnavailableView(
                String(localized: "No activity", bundle: #bundle, comment: "Console empty state title"),
                systemImage: "terminal",
                description: Text("Run a brew command to see output here.", bundle: #bundle, comment: "Console empty state body"),
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.brewSurfaceElevated)
        case let .output(jobID, lines, standardErrorIsNormalOutput):
            ConsoleTextView(
                lines: lines,
                jobID: jobID,
                standardErrorIsNormalOutput: standardErrorIsNormalOutput,
            )
            .background(Color.brewSurfaceElevated)
        }
    }
}
