//
//  Sidebar.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// Primary navigation. Each destination returns its screen already waited for, so navigating and
/// asserting it loaded are one call.
@MainActor
struct Sidebar: Screen {
    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .sidebar)
    }

    @discardableResult
    func goToInstalled(file: StaticString = #filePath, line: UInt = #line) -> InstalledScreen {
        item(.installed).tap(file: file, line: line)
        return InstalledScreen(app: app).waitUntilLoaded(file: file, line: line)
    }

    @discardableResult
    func goToUpgrades(file: StaticString = #filePath, line: UInt = #line) -> UpgradesScreen {
        item(.upgrades).tap(file: file, line: line)
        return UpgradesScreen(app: app).waitUntilLoaded(file: file, line: line)
    }

    @discardableResult
    func goToDiscover(file: StaticString = #filePath, line: UInt = #line) -> DiscoverScreen {
        item(.discover).tap(file: file, line: line)
        return DiscoverScreen(app: app).waitUntilLoaded(file: file, line: line)
    }

    @discardableResult
    func goToDoctor(file: StaticString = #filePath, line: UInt = #line) -> DoctorScreen {
        item(.doctor).tap(file: file, line: line)
        return DoctorScreen(app: app).waitUntilLoaded(file: file, line: line)
    }

    @discardableResult
    func goToConfiguration(file: StaticString = #filePath, line: UInt = #line) -> ConfigScreen {
        item(.configuration).tap(file: file, line: line)
        return ConfigScreen(app: app).waitUntilLoaded(file: file, line: line)
    }

    private func item(_ destination: AXID.SidebarDestination) -> BrewUIButton {
        BrewUIButton(app, .sidebarItem(destination))
    }
}
