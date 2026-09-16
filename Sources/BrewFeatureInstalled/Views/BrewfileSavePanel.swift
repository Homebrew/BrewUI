//
//  BrewfileSavePanel.swift
//  BrewFeatureInstalled
//

import AppKit
import Foundation

/// View-layer AppKit bridge for choosing a Brewfile destination and revealing it in Finder.
/// Never writes the file; `brew bundle dump` owns that.
enum BrewfileSavePanel {
    @MainActor
    static func chooseDestination() -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Brewfile"
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.message = String(
            localized: "Homebrew will write the Brewfile to this location.",
            comment: "Save panel message for Brewfile export",
        )
        panel.prompt = String(
            localized: "Choose",
            comment: "Save panel confirm button for Brewfile export destination",
        )
        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url
    }

    @MainActor
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
