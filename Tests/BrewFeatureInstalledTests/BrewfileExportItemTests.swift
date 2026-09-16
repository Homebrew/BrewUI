//
//  BrewfileExportItemTests.swift
//  BrewFeatureInstalledTests
//

import BrewCore
@testable import BrewFeatureInstalled
import Foundation
import Testing

struct BrewfileExportItemTests {
    @Test func `display command uses an unquoted path when the path is shell-safe`() {
        let item = BrewfileExportItem(destinationURL: URL(filePath: "/tmp/Brewfile"))
        #expect(
            item.displayCommand ==
                "brew bundle dump --file=/tmp/Brewfile --force --formula --cask --tap",
        )
    }

    @Test func `display command single-quotes a path with spaces`() {
        let item = BrewfileExportItem(destinationURL: URL(filePath: "/tmp/My Brewfile"))
        #expect(
            item.displayCommand ==
                "brew bundle dump --file='/tmp/My Brewfile' --force --formula --cask --tap",
        )
    }

    @Test func `display command escapes embedded single quotes`() {
        let item = BrewfileExportItem(destinationURL: URL(filePath: "/tmp/foo's Brewfile"))
        #expect(
            item.displayCommand ==
                "brew bundle dump --file='/tmp/foo'\\''s Brewfile' --force --formula --cask --tap",
        )
    }

    @Test func `empty path is quoted`() {
        #expect(BrewfileExportItem.shellQuote("") == "''")
    }

    @Test func `destination path is the standardized file path`() {
        let nested = BrewfileExportItem(destinationURL: URL(filePath: "/tmp/export/../Brewfile"))
        let direct = BrewfileExportItem(destinationURL: URL(filePath: "/tmp/Brewfile"))
        #expect(nested.destinationPath == direct.destinationPath)
        #expect(nested.destinationURL.path == direct.destinationURL.path)
    }

    @Test func `maintenance identity is derived from the standardized path`() {
        let nested = BrewfileExportItem(destinationURL: URL(filePath: "/tmp/export/../Brewfile"))
        let direct = BrewfileExportItem(destinationURL: URL(filePath: "/tmp/Brewfile"))
        #expect(nested.operationID == direct.operationID)
        #expect(
            nested.operationID ==
                BrewOperationID(
                    maintenanceToken: "bundle-dump:\(direct.destinationPath)",
                    displayCommand: direct.displayCommand,
                ),
        )
    }

    @Test func `operation display command matches the copyable command`() {
        let item = BrewfileExportItem(destinationURL: URL(filePath: "/tmp/My Brewfile"))
        guard case let .maintenance(_, displayCommand) = item.operationID else {
            Issue.record("expected a maintenance operation id")
            return
        }
        #expect(displayCommand == item.displayCommand)
    }

    @Test func `titles and summary are stable`() {
        let item = BrewfileExportItem(destinationURL: URL(filePath: "/tmp/Brewfile"))
        #expect(BrewfileExportItem.chooseLocationButtonTitle == "Choose Location…")
        #expect(BrewfileExportItem.exportButtonTitle == "Export")
        #expect(item.showInFinderButtonTitle == "Show in Finder")
        #expect(item.successTitle == "Brewfile exported")
        #expect(item.successMessage == "Saved to /tmp/Brewfile")
        #expect(item.commandSummary == "Writes formulae, casks, and taps using brew bundle dump.")
        #expect(BrewfileExportItem.headerButtonTitle == "Export Brewfile…")
        #expect(BrewfileExportItem.sheetTitle == "Export Brewfile")
    }

    @Test func `explainer covers installed-on-request behavior and excludes import`() {
        #expect(BrewfileExportItem.explainer.contains("installed on request"))
        #expect(BrewfileExportItem.explainer.contains("does not import"))
    }
}
