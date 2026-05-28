//
//  ConsoleCommands.swift
//  Brew
//

import SwiftUI

/// View menu commands for the command console. Currently a single `⌘\`` toggle matching Xcode / VS Code / Terminal.
struct ConsoleCommands: Commands {
    @FocusedBinding(\.consoleExpanded) private var expanded: Bool?

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button(expanded == true ? "Hide Console" : "Show Console") {
                expanded?.toggle()
            }
            .keyboardShortcut("`", modifiers: .command)
            .disabled(expanded == nil)
        }
    }
}
