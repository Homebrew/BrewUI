//
//  UpgradesScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The outdated slice of the Installed inventory, with its own row identity so an assertion cannot be
/// satisfied by the Installed row for the same package.
@MainActor
struct UpgradesScreen: Screen {
    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .upgradesScreen)
    }

    var list: BrewUIList {
        BrewUIList(app, .upgradesList, rowID: { AXID.upgradesRow(token: $0) })
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

    func openDetail(
        for token: String,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> PackageDetailScreen {
        list.row(token).tap(file: file, line: line)
        return PackageDetailScreen(app: app).waitUntilLoaded(file: file, line: line)
    }
}
