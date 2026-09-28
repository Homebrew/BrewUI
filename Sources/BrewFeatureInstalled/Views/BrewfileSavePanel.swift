//
//  BrewfileSavePanel.swift
//  BrewFeatureInstalled
//

import AppKit

/// Asks for where `brew bundle dump` should write the Brewfile.
///
/// The panel is an AppKit bridge kept in the view layer so the view model stays free of AppKit. It only
/// picks a destination: `brew` writes the file, which keeps Homebrew the source of truth for a
/// Brewfile's contents.
enum BrewfileSavePanel {
    /// Returns the chosen destination, or `nil` when the user cancels.
    @MainActor
    static func chooseDestination() -> URL? {
        let panel = NSSavePanel()
        panel.title = String(
            localized: "Save Brewfile…",
            bundle: #bundle,
            comment: "Installed header: save the installed environment as a Brewfile",
        )
        panel.nameFieldStringValue = "Brewfile"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}
