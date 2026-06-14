//
//  PaneCommands.swift
//  Brew
//

import BrewUIComponents
import SwiftUI

/// View-menu commands that dispatch into whichever feature pane is currently active. The pane
/// publishes its closures via `focusedSceneValue(\.activePaneActions, …)`; nil closures keep the
/// menu items disabled so `⌘C` in a text field is never stolen.
struct PaneCommands: Commands {
    @FocusedValue(\.activePaneActions) private var actions: PaneActions?

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Find") { actions?.focusSearch?() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(actions?.focusSearch == nil)
            Button("Refresh") { actions?.refresh?() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(actions?.refresh == nil)
        }
    }
}
