//
//  ToolsCommands.swift
//  Homebrew
//

import BrewAccessibilityID
import BrewUIComponents
import SwiftUI

/// The Tools menu: occasional Homebrew maintenance that does not need a tab of its own.
struct ToolsCommands: Commands {
    @FocusedValue(\.showCleanup) private var showCleanup

    var body: some Commands {
        CommandMenu(String(localized: "Tools", bundle: #bundle, comment: "Menu bar: occasional Homebrew maintenance commands")) {
            Button(String(localized: "Clean Up…", bundle: #bundle, comment: "Tools menu: preview and run brew cleanup")) { showCleanup?() }
                .disabled(showCleanup == nil)
                .axid(.toolsCleanupMenuItem)
        }
    }
}

/// Opens the Clean Up sheet on the focused main window.
struct ShowCleanupAction {
    let isPresented: Binding<Bool>

    func callAsFunction() {
        isPresented.wrappedValue = true
    }
}

extension FocusedValues {
    @Entry var showCleanup: ShowCleanupAction?
}
