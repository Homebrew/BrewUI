//
//  AXIDTests.swift
//  BrewAccessibilityIDTests
//

import BrewAccessibilityID
import Testing

/// These tests pin the wire format of every identifier. A UI test that fails to find an element is
/// an expensive, flaky-looking failure; a diff here is a cheap, obvious one — so identifier drift
/// should break this suite first.
struct AXIDTests {
    @Test func `static identifiers keep their wire format`() {
        let identifiers = [
            AXID.sidebar,
            .installedScreen,
            .installedList,
            .installedSearchField,
            .upgradesScreen,
            .upgradesList,
            .upgradesRefreshButton,
            .discoverScreen,
            .discoverSearchField,
            .discoverList,
            .configScreen,
            .doctorScreen,
            .brewNotFoundState,
            .packageDetail,
            .installButton,
            .uninstallButton,
            .upgradeButton,
            .console,
            .consoleStatus,
            .consoleToggle,
            .consoleOutput,
            .errorState,
            .errorRetryButton,
        ].map(\.rawValue)

        #expect(identifiers == [
            "sidebar",
            "installed.screen",
            "installed.list",
            "installed.search",
            "upgrades.screen",
            "upgrades.list",
            "upgrades.refresh",
            "discover.screen",
            "discover.search",
            "discover.list",
            "config.screen",
            "doctor.screen",
            "brew.not.found",
            "package.detail",
            "detail.install",
            "detail.uninstall",
            "detail.upgrade",
            "console",
            "console.status",
            "console.toggle",
            "console.output",
            "error.state",
            "error.retry",
        ])
    }

    @Test func `every sidebar destination maps to a distinct namespaced identifier`() {
        let identifiers = AXID.SidebarDestination.allCases.map { AXID.sidebarItem($0).rawValue }

        #expect(identifiers == [
            "sidebar.item.installed",
            "sidebar.item.upgrades",
            "sidebar.item.discover",
            "sidebar.item.doctor",
            "sidebar.item.configuration",
        ])
    }

    @Test func `row identifiers embed the package token`() {
        let identifiers = [
            AXID.installedRow(token: "git").rawValue,
            AXID.upgradesRow(token: "wget").rawValue,
            AXID.discoverRow(token: "iterm2").rawValue,
        ]

        #expect(identifiers == ["installed.row.git", "upgrades.row.wget", "discover.row.iterm2"])
    }

    /// The three lists can hold the same package token at once — an outdated installed package
    /// appears in Installed, in Upgrades, and in Discover — so their identifiers must not collide.
    @Test func `rows for the same token stay distinct across lists`() {
        let identifiers = Set([
            AXID.installedRow(token: "git").rawValue,
            AXID.upgradesRow(token: "git").rawValue,
            AXID.discoverRow(token: "git").rawValue,
        ])

        #expect(identifiers.count == 3)
    }

    /// A token containing separator-like characters must not silently alias another element's id.
    @Test func `row identifiers with unusual tokens stay unique`() {
        let identifiers = Set([
            AXID.installedRow(token: "row.git").rawValue,
            AXID.installedRow(token: "git").rawValue,
            AXID.installedRow(token: "").rawValue,
        ])

        #expect(identifiers.count == 3)
    }
}
