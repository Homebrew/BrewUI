//
//  ConsolePanel.swift
//  Brew
//

import SwiftUI

/// Bottom-of-window console: collapsed status strip in this slice; expanded body lands in a later slice.
/// Height is constant for now — slice 4 adds the resize handle and expanded body conditional.
struct ConsolePanel: View {
    @Binding var expanded: Bool

    var body: some View {
        ConsoleStatusBar(expanded: $expanded)
            .frame(height: BrewLayout.consoleCollapsedHeight)
            .background(Color.brewTerminal)
    }
}
