//
//  ConsoleCommands.swift
//  Brew
//

import BrewUIComponents
import SwiftUI

/// View menu commands for the command console. Currently a single `⌘\`` toggle matching Xcode / VS Code / Terminal.
public struct ConsoleCommands: Commands {
    @FocusedBinding(\.consoleExpanded) private var expanded: Bool?
    /// App-wide preference (not per-window), so it lives here directly rather than as a focused value.
    @AppStorage("autoExpandConsole") private var autoExpandConsole = true

    private let localization: AppLocalization

    public init(localization: AppLocalization = AppLocalization()) {
        self.localization = localization
    }

    public var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button(localization.string(expanded == true ? "Hide Console" : "Show Console")) {
                expanded?.toggle()
            }
            .keyboardShortcut("`", modifiers: .command)
            .disabled(expanded == nil)

            Toggle(localization.string("Expand Console Panel Automatically"), isOn: $autoExpandConsole)
        }
    }
}
