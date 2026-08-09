//
//  ConsolePanel.swift
//  Brew
//

import BrewAccessibilityID
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Bottom-of-window console. Collapsed → status strip only. Expanded → toolbar + output body.
/// The pane height (and the drag affordance to resize it) is owned by the parent ``VSplitView`` in
/// ``MainWindowView``; this view just renders the chrome and content for whatever size it's given.
struct ConsolePanel: View {
    @Binding var expanded: Bool
    @State var viewModel: ConsoleViewModel
    @AppStorage("autoExpandConsole") private var autoExpandConsole = true

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
        .accessibilityElement(children: .contain)
        .axid(.console)
        .onAppear { viewModel.autoExpandEnabled = autoExpandConsole }
        .onChange(of: autoExpandConsole) { _, enabled in viewModel.autoExpandEnabled = enabled }
        .onChange(of: viewModel.shouldAutoExpandConsole) { _, shouldExpand in
            // Rising edge only: open the collapsed panel when a command starts. We never force-collapse,
            // so a user who manually collapses mid-run isn't fought — the next command re-raises it.
            if shouldExpand { expanded = true }
        }
    }
}
