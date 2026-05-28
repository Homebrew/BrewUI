//
//  ConsolePanelRoot.swift
//  Brew
//

import BrewCore
import BrewUIComponents
import BrewRepositoryInterfaces
import SwiftUI

/// App-window-owned root for the console feature: reads the shared command-jobs repository from the
/// environment and constructs the per-window ``ConsoleViewModel`` passed down to the panel's subviews.
/// Resize is owned by the parent ``VSplitView`` in ``MainWindowView`` — the panel itself no longer
/// tracks a height, it just renders for whatever size the split view gives it.
public struct ConsolePanelRoot: View {
    @Binding var expanded: Bool
    @Environment(\.commandJobsRepository) private var commandJobsRepository

    public init(expanded: Binding<Bool>) {
        _expanded = expanded
    }

    public var body: some View {
        ConsolePanel(
            expanded: $expanded,
            commandJobsRepository: commandJobsRepository,
        )
    }
}
