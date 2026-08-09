//
//  DiscoverScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The Discover tab: trending packages from the analytics endpoints, and catalogue search.
@MainActor
struct DiscoverScreen: Screen {
    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .discoverScreen)
    }

    var list: BrewUIList {
        BrewUIList(app, .discoverList, rowID: { AXID.discoverRow(token: $0) })
    }

    var searchField: BrewUISearchField {
        BrewUISearchField(app)
    }

    /// The view debounces for 250 ms, so callers wait on the resulting row rather than on a sleep.
    @discardableResult
    func search(for query: String, file: StaticString = #filePath, line: UInt = #line) -> Self {
        searchField.type(query, file: file, line: line)
        return self
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
