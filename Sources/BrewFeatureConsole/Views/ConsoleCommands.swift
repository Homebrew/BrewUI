//
//  ConsoleCommands.swift
//  Brew
//

import SwiftUI

/// View menu commands for the command console. Currently a single `⌘\`` toggle matching Xcode / VS Code / Terminal.
public struct ConsoleCommands: Commands {
    @FocusedBinding(\.consoleExpanded) private var expanded: Bool?
    /// App-wide preference (not per-window), so it lives here directly rather than as a focused value.
    @AppStorage("autoExpandConsole") private var autoExpandConsole = true

    public init() {}

    public var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button(expanded == true
                ? String(localized: "Hide Console", bundle: #bundle, comment: "View menu: collapse the console panel (⌘`)")
                : String(localized: "Show Console", bundle: #bundle, comment: "View menu: expand the console panel (⌘`)"))
            {
                expanded?.toggle()
            }
            .keyboardShortcut("`", modifiers: .command)
            .disabled(expanded == nil)

            Toggle(String(localized: "Expand Console Panel Automatically", bundle: #bundle, comment: "View menu: open the console when a command starts"), isOn: $autoExpandConsole)
        }
    }
}
