//
//  ConsoleCommands.swift
//  Brew
//

import BrewCore
import BrewDesignSystem
import BrewRepositories
import SwiftUI

/// View menu commands for the command console. Currently a single `⌘\`` toggle matching Xcode / VS Code / Terminal.
public struct ConsoleCommands: Commands {
    @FocusedBinding(\.consoleExpanded) private var expanded: Bool?

    public init() {}

    public var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button(expanded == true ? "Hide Console" : "Show Console") {
                expanded?.toggle()
            }
            .keyboardShortcut("`", modifiers: .command)
            .disabled(expanded == nil)
        }
    }
}
