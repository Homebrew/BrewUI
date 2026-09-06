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
                "No activity",
                systemImage: "terminal",
                description: Text("Run a brew command to see output here."),
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
