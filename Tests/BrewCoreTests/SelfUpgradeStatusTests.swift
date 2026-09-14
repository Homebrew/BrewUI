//
//  SelfUpgradeStatusTests.swift
//  BrewTests
//

import BrewCore
import Foundation
import Testing

struct SelfUpgradeStatusTests {
    @Test func `identity uses the homebrew-app cask token`() {
        #expect(SelfUpgradeIdentity.caskToken == "homebrew-app")
        #expect(SelfUpgradeIdentity.bundleIdentifier == "sh.brew.app")
    }

    @Test func `display command targets the app cask and is derived from the token`() {
        #expect(SelfUpgradeIdentity.displayCommand == "brew upgrade --cask homebrew-app")
        #expect(SelfUpgradeIdentity.displayCommand.contains(SelfUpgradeIdentity.caskToken))
    }

    @Test func `upToDate has no update, no latest version, and keeps the homepage`() {
        let status = SelfUpgradeStatus.upToDate(runningVersion: "1.4.2")
        #expect(status.isUpgradeAvailable == false)
        #expect(status.latestVersion == nil)
        #expect(status.runningVersion == "1.4.2")
        #expect(status.homepageURL == SelfUpgradeIdentity.homepageURL)
    }

    @Test func `available status carries both version strings and the flag`() {
        let status = SelfUpgradeStatus(
            runningVersion: "1.4.2",
            latestVersion: "1.5.0",
            homepageURL: SelfUpgradeIdentity.homepageURL,
            isUpgradeAvailable: true,
        )
        #expect(status.isUpgradeAvailable)
        #expect(status.runningVersion == "1.4.2")
        #expect(status.latestVersion == "1.5.0")
    }

    @Test func `equatable distinguishes the update flag`() {
        let base = SelfUpgradeStatus(runningVersion: "1.4.2", latestVersion: "1.5.0", homepageURL: nil, isUpgradeAvailable: true)
        let flipped = SelfUpgradeStatus(runningVersion: "1.4.2", latestVersion: "1.5.0", homepageURL: nil, isUpgradeAvailable: false)
        #expect(base != flipped)
        #expect(base == SelfUpgradeStatus(runningVersion: "1.4.2", latestVersion: "1.5.0", homepageURL: nil, isUpgradeAvailable: true))
    }

    @Test func `upgradeApp is a distinct operation kind`() {
        #expect(BrewOperationKind.upgradeApp.rawValue == "upgradeApp")
        #expect(BrewOperationKind.upgradeApp != .upgradeCask)
    }
}
