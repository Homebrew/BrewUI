//
//  ConsolePanel.swift
//  Brew
//

import SwiftUI

/// Bottom-of-window console. Collapsed → status strip only. Expanded → resize handle + toolbar + output body.
struct ConsolePanel: View {
    @Binding var expanded: Bool
    @Binding var height: Double

    var body: some View {
        VStack(spacing: 0) {
            if expanded {
                ConsoleResizeHandle(height: $height)
                ConsoleToolbar(expanded: $expanded)
                Divider().opacity(0.4)
                ConsoleBody()
            } else {
                ConsoleStatusBar(expanded: $expanded)
            }
        }
        .frame(height: expanded ? height : BrewLayout.consoleCollapsedHeight)
        .background(Color.brewTerminal)
        .animation(.brewFast, value: expanded)
    }
}
