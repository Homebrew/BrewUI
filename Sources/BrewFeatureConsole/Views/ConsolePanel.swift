//
//  ConsolePanel.swift
//  Brew
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Bottom-of-window console. Collapsed → status strip only. Expanded → toolbar + output body.
/// The pane height (and the drag affordance to resize it) is owned by the parent ``VSplitView`` in
/// ``MainWindowView``; this view just renders the chrome and content for whatever size it's given.
struct ConsolePanel: View {
    @Binding var expanded: Bool
    @State var viewModel: ConsoleViewModel

    init(expanded: Binding<Bool>, commandJobsRepository: any CommandJobsObserving) {
        _expanded = expanded
        _viewModel = State(initialValue: .init(repository: commandJobsRepository))
    }

    var body: some View {
        VStack(spacing: 0) {
            if expanded {
                ConsoleToolbar(expanded: $expanded, viewModel: viewModel)
                Divider().opacity(0.4)
                ConsoleBody(viewModel: viewModel)
            } else {
                ConsoleStatusBar(expanded: $expanded, viewModel: viewModel)
            }
        }
        .background(Color.brewSurface)
    }
}
