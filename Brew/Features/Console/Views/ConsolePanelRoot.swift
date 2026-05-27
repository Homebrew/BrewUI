//
//  ConsolePanelRoot.swift
//  Brew
//

import SwiftUI

/// App-window-owned root for the console feature: reads the shared command-jobs repository from the
/// environment and constructs the per-window ``ConsoleViewModel`` passed down to the panel's subviews.
struct ConsolePanelRoot: View {
    @Binding var expanded: Bool
    @Binding var height: Double
    @Environment(\.commandJobsRepository) private var commandJobsRepository

    var body: some View {
        ConsolePanel(
            expanded: $expanded,
            height: $height,
            commandJobsRepository: commandJobsRepository,
        )
    }
}
