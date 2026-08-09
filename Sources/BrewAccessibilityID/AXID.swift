//
//  AXID.swift
//  BrewAccessibilityID
//

import Foundation

/// Stable identifiers for UI-testable elements. The app attaches them with `.axid(_:)` and tests
/// construct the same case, so identity can only drift if this file changes — a compile error on
/// both sides rather than a missing element at runtime.
///
/// Row cases carry the package's Homebrew name/token (what `HomebrewPackageID.name` yields), so rows
/// are addressable without matching on label or index.
public enum AXID: Hashable, Sendable {
    // Navigation
    case sidebar
    case sidebarItem(SidebarDestination)

    // Installed / Upgrades
    case installedScreen
    case installedList
    case installedRow(token: String)
    case installedSearchField
    case upgradesScreen
    case upgradesList
    case upgradesRow(token: String)

    // Discover
    case discoverScreen
    case discoverSearchField
    case discoverList
    case discoverRow(token: String)

    // Config / Doctor
    case configScreen
    case doctorScreen
    case brewNotFoundState

    // Detail / Console
    case packageDetail
    case installButton
    case uninstallButton
    case upgradeButton
    case console
    case consoleStatus
    case consoleToggle
    case consoleOutput

    /// Shared failure chrome. Every loadable surface renders the same view, so scope a query to a
    /// screen root to say which one failed.
    case errorState
    case errorRetryButton

    /// Mirrors the app's `SidebarItem`, so the test target can name a destination without linking it.
    public enum SidebarDestination: String, CaseIterable, Sendable {
        case installed, upgrades, discover, doctor, configuration
    }

    /// The string handed to `accessibilityIdentifier` and read back by `XCUIElement`.
    public var rawValue: String {
        switch self {
        case .sidebar: "sidebar"
        case let .sidebarItem(destination): "sidebar.item.\(destination.rawValue)"
        case .installedScreen: "installed.screen"
        case .installedList: "installed.list"
        case let .installedRow(token): "installed.row.\(token)"
        case .installedSearchField: "installed.search"
        case .upgradesScreen: "upgrades.screen"
        case .upgradesList: "upgrades.list"
        case let .upgradesRow(token): "upgrades.row.\(token)"
        case .discoverScreen: "discover.screen"
        case .discoverSearchField: "discover.search"
        case .discoverList: "discover.list"
        case let .discoverRow(token): "discover.row.\(token)"
        case .configScreen: "config.screen"
        case .doctorScreen: "doctor.screen"
        case .brewNotFoundState: "brew.not.found"
        case .packageDetail: "package.detail"
        case .installButton: "detail.install"
        case .uninstallButton: "detail.uninstall"
        case .upgradeButton: "detail.upgrade"
        case .console: "console"
        case .consoleStatus: "console.status"
        case .consoleToggle: "console.toggle"
        case .consoleOutput: "console.output"
        case .errorState: "error.state"
        case .errorRetryButton: "error.retry"
        }
    }
}
