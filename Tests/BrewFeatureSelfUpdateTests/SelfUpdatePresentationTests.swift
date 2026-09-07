//
//  SelfUpdatePresentationTests.swift
//  BrewFeatureSelfUpdateTests
//

import BrewCore
@testable import BrewFeatureSelfUpdate
import Foundation
import Testing

struct SelfUpdatePresentationTests {
    private func presentation(running: String = "1.4.2", latest: String?) -> SelfUpdatePresentation {
        SelfUpdatePresentation(
            status: SelfUpdateStatus(
                runningVersion: running,
                latestVersion: latest,
                homepageURL: nil,
                isUpdateAvailable: latest != nil,
            ),
        )
    }

    @Test func `version summary shows the transition when a latest version is known`() {
        #expect(presentation(latest: "1.5.0").versionSummary == "v1.4.2 → v1.5.0")
    }

    @Test func `version summary shows only the running version when no latest is known`() {
        #expect(presentation(latest: nil).versionSummary == "v1.4.2")
    }

    @Test func `running and latest displays are v-prefixed`() {
        let presentation = presentation(latest: "1.5.0")
        #expect(presentation.runningVersionDisplay == "v1.4.2")
        #expect(presentation.latestVersionDisplay == "v1.5.0")
    }

    @Test func `latest display is nil when no latest version is known`() {
        #expect(presentation(latest: nil).latestVersionDisplay == nil)
    }

    @Test func `upgrade action names the target version when known`() {
        #expect(presentation(latest: "1.5.0").upgradeActionTitle == "Upgrade to v1.5.0")
    }

    @Test func `upgrade action falls back to a generic label without a latest version`() {
        #expect(presentation(latest: nil).upgradeActionTitle == "Upgrade Homebrew")
    }

    @Test func `the app uses the same upgrade verb as packages`() {
        let presentation = presentation(latest: "1.5.0")
        #expect(presentation.upgradeActionTitle.hasPrefix("Upgrade"))
        #expect(presentation.eyebrow == "Upgrade Homebrew app")
    }

    /// The banner eyebrow is rendered uppercased, so it has to read as an instruction in that form too.
    @Test func `the banner eyebrow names the action rather than the app`() {
        #expect(presentation(latest: "1.5.0").eyebrow.uppercased() == "UPGRADE HOMEBREW APP")
    }
}
