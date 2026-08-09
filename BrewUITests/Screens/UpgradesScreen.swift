//
//  UpgradesScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The Upgrades tab: the outdated slice of the same inventory the Installed tab renders. Its rows
/// carry their own identity so an assertion can't be satisfied by the Installed list of the same
/// package.
@MainActor
struct UpgradesScreen: Screen {
    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .upgradesScreen)
    }

    var list: BrewUIList {
        BrewUIList(app, .upgradesList, rowID: { AXID.upgradesRow(token: $0) })
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
