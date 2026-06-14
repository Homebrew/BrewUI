//
//  SidebarCommands.swift
//  Brew
//

import SwiftUI

/// View-menu commands for switching the sidebar selection. Mirrors Mail / Messages / Music: `⌘1`–`⌘4`
/// jump straight to the matching pane.
struct SidebarCommands: Commands {
    @FocusedBinding(\.selectedSidebarItem) private var selection: SidebarItem?

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            Button("Installed") { selection = .installed }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(selection == nil)
            Button("Discover") { selection = .discover }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(selection == nil)
            Button("Doctor") { selection = .doctor }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(selection == nil)
            Button("Configuration") { selection = .configuration }
                .keyboardShortcut("4", modifiers: .command)
                .disabled(selection == nil)
            Divider()
        }
    }
}
