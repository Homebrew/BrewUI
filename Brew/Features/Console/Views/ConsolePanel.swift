//
//  ConsolePanel.swift
//  Brew
//

import SwiftUI

/// Bottom-of-window console. Collapsed → status strip only. Expanded → resize handle + toolbar + output body.
struct ConsolePanel: View {
    @Binding var expanded: Bool
    @Binding var height: Double
    @State var viewModel: ConsoleViewModel

    init(expanded: Binding<Bool>, height: Binding<Double>, commandJobsRepository: any CommandJobsObserving) {
        _expanded = expanded
        _height = height
        _viewModel = State(initialValue: .init(repository: commandJobsRepository))
    }

    var body: some View {
        VStack(spacing: 0) {
            if expanded {
                ConsoleResizeHandle(height: $height)
                ConsoleToolbar(expanded: $expanded, viewModel: viewModel)
                Divider().opacity(0.4)
                ConsoleBody(viewModel: viewModel)
            } else {
                ConsoleStatusBar(expanded: $expanded, viewModel: viewModel)
            }
        }
        .frame(height: expanded ? height : BrewLayout.consoleCollapsedHeight)
        .background(Color.brewSurface)
        .animation(.brewFast, value: expanded)
    }
}
