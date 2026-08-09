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
}
