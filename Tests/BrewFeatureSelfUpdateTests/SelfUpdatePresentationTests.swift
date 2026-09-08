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
        #expect(presentation(latest: nil).upgradeActionTitle == "Upgrade the Homebrew app")
    }

    /// The app updates itself here, not `brew`, and the two are separate things in this app.
    @Test func `the banner title names the app rather than Homebrew itself`() {
        let title = presentation(latest: "1.5.0").bannerTitle
        #expect(title == "A new version of the Homebrew app is available")
        #expect(title.contains("Homebrew app"))
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

/// One alert carries both outcomes, so the copy has to differ by outcome rather than by which modifier
/// happens to be attached.
struct SelfUpdateOutcomePresentationTests {
    private func copy(_ outcome: SelfUpdateOutcome) -> SelfUpdateOutcomePresentation {
        SelfUpdateOutcomePresentation(outcome: outcome)
    }

    @Test func `a successful upgrade is reported as done`() {
        #expect(copy(.succeeded).title == "The Homebrew app is up to date")
        #expect(copy(.succeeded).message.contains("upgraded to the latest version"))
    }

    /// A failed upgrade relaunches an app that looks exactly like an ordinary start, so the copy has to
    /// say the version did not move.
    @Test func `a failed upgrade says the app is still on the previous version`() {
        #expect(copy(.failed).title == "The Homebrew app wasn’t upgraded")
        #expect(copy(.failed).message.contains("still the previous version"))
    }

    @Test func `the two outcomes never read the same`() {
        #expect(copy(.succeeded).title != copy(.failed).title)
        #expect(copy(.succeeded).message != copy(.failed).message)
    }

    /// The banner is where a retry lives, so the failure alert points at it rather than dead-ending.
    @Test func `the failure copy points back at the banner`() {
        #expect(copy(.failed).message.contains("banner"))
    }
}
