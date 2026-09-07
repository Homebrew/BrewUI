//
//  SelfUpdateStatusTests.swift
//  BrewTests
//

import BrewCore
import Foundation
import Testing

struct SelfUpdateStatusTests {
    @Test func `identity uses the homebrew-app cask token`() {
        #expect(SelfUpdateIdentity.caskToken == "homebrew-app")
        #expect(SelfUpdateIdentity.bundleIdentifier == "sh.brew.app")
    }

    @Test func `display command targets the app cask and is derived from the token`() {
        #expect(SelfUpdateIdentity.displayCommand == "brew upgrade --cask homebrew-app")
        #expect(SelfUpdateIdentity.displayCommand.contains(SelfUpdateIdentity.caskToken))
    }

    @Test func `upToDate has no update, no latest version, and keeps the homepage`() {
        let status = SelfUpdateStatus.upToDate(runningVersion: "1.4.2")
        #expect(status.isUpdateAvailable == false)
        #expect(status.latestVersion == nil)
        #expect(status.runningVersion == "1.4.2")
        #expect(status.homepageURL == SelfUpdateIdentity.homepageURL)
    }

    @Test func `available status carries both version strings and the flag`() {
        let status = SelfUpdateStatus(
            runningVersion: "1.4.2",
            latestVersion: "1.5.0",
            homepageURL: SelfUpdateIdentity.homepageURL,
            isUpdateAvailable: true,
        )
        #expect(status.isUpdateAvailable)
        #expect(status.runningVersion == "1.4.2")
        #expect(status.latestVersion == "1.5.0")
    }

    @Test func `equatable distinguishes the update flag`() {
        let base = SelfUpdateStatus(runningVersion: "1.4.2", latestVersion: "1.5.0", homepageURL: nil, isUpdateAvailable: true)
        let flipped = SelfUpdateStatus(runningVersion: "1.4.2", latestVersion: "1.5.0", homepageURL: nil, isUpdateAvailable: false)
        #expect(base != flipped)
        #expect(base == SelfUpdateStatus(runningVersion: "1.4.2", latestVersion: "1.5.0", homepageURL: nil, isUpdateAvailable: true))
    }

    @Test func `upgradeApp is a distinct operation kind`() {
        #expect(BrewOperationKind.upgradeApp.rawValue == "upgradeApp")
        #expect(BrewOperationKind.upgradeApp != .upgradeCask)
    }
}
