//
//  InstalledScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The Installed tab: the inventory `brew info --installed --json=v2` produced, plus its detail pane.
@MainActor
struct InstalledScreen: Screen {
    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .installedScreen)
    }

    var list: BrewUIList {
        BrewUIList(app, .installedList, rowID: { AXID.installedRow(token: $0) })
    }

    var searchField: BrewUISearchField {
        BrewUISearchField(app)
    }

    @discardableResult
    func assertHasPackage(
        _ token: String,
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        list.row(token).waitToExist(timeout: timeout, file: file, line: line)
        return self
    }

    @discardableResult
    func assertDoesNotHavePackage(
        _ token: String,
        timeout: TimeInterval = BrewUITestTimeout.disappearance,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        list.row(token).assertDoesNotExist(timeout: timeout, file: file, line: line)
        return self
    }

    @discardableResult
    func assertRowCount(_ expected: Int, file: StaticString = #filePath, line: UInt = #line) -> Self {
        list.assertCount(expected, file: file, line: line)
        return self
    }

    /// Filtering stays on this screen; only the visible rows change.
    @discardableResult
    func search(for query: String, file: StaticString = #filePath, line: UInt = #line) -> Self {
        searchField.type(query, file: file, line: line)
        return self
    }

    @discardableResult
    func clearSearch(file: StaticString = #filePath, line: UInt = #line) -> Self {
        searchField.clear(file: file, line: line)
        return self
    }

    func openDetail(
        for token: String,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> PackageDetailScreen {
        list.row(token).tap(file: file, line: line)
        return PackageDetailScreen(app: app).waitUntilLoaded(file: file, line: line)
    }

    var exportBrewfileButton: BrewUIButton {
        BrewUIButton(app, .installedExportBrewfileButton)
    }

    var exportSheet: BrewUIElement {
        BrewUIElement(app, .brewfileExportSheet)
    }

    var exportChooseLocationButton: BrewUIButton {
        BrewUIButton(app, .brewfileExportChooseLocationButton, in: exportSheet.element)
    }

    var exportSubmitButton: BrewUIButton {
        BrewUIButton(app, .brewfileExportSubmitButton, in: exportSheet.element)
    }

    @discardableResult
    func openExportBrewfileSheet(
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        exportBrewfileButton
            .assertIsEnabled(timeout: BrewUITestTimeout.launch, file: file, line: line)
            .tap(file: file, line: line)
        exportSheet.waitToExist(file: file, line: line)
        return self
    }

    @discardableResult
    func assertExportSheetExplainsDump(
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        exportSheet.waitToExist(file: file, line: line)
        let predicate = NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@",
            "installed on request",
            "installed on request",
        )
        let match = exportSheet.element.descendants(matching: .staticText).matching(predicate).firstMatch
        guard match.waitForExistence(timeout: BrewUITestTimeout.default) else {
            XCTFail(
                """
                Expected the Brewfile export sheet to explain installed-on-request dump behavior.
                \(BrewUITestDiagnostics.report(for: app))
                """,
                file: file,
                line: line,
            )
            return self
        }
        return self
    }

    @discardableResult
    func assertExportSubmitIsDisabled(
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        exportSubmitButton.assertIsDisabled(file: file, line: line)
        return self
    }
}
