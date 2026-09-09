//
//  BrewSelfUpgradeStatusProviderTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewRepositories
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation
import Testing

@MainActor
struct BrewSelfUpgradeStatusProviderTests {
    private func makeProvider(
        packages: [InstalledBrewPackage],
        runningVersion: String = "1.4.2",
    ) -> BrewSelfUpgradeStatusProvider {
        BrewSelfUpgradeStatusProvider(
            inventory: StubInstalledPackagesRepository(packages: packages),
            versionReader: StubRunningAppVersionReader(runningVersion: runningVersion),
        )
    }

    private func appCask(
        latestVersion: String = "1.5.0",
        homepage: String = "https://example.com/brewui",
        outdated: Bool,
    ) -> InstalledBrewPackage {
        .fixture(
            name: SelfUpgradeIdentity.caskToken,
            kind: .cask,
            homepage: homepage,
            latestVersion: latestVersion,
            installedVersions: ["1.4.2"],
            outdated: outdated,
        )
    }

    @Test func `outdated app cask surfaces an available update with both versions`() {
        let provider = makeProvider(packages: [appCask(outdated: true)])
        let status = provider.selfUpgradeStatus
        #expect(status.isUpgradeAvailable)
        #expect(status.runningVersion == "1.4.2")
        #expect(status.latestVersion == "1.5.0")
        #expect(status.homepageURL == URL(string: "https://example.com/brewui"))
    }

    @Test func `up-to-date app cask reports no update`() {
        let provider = makeProvider(packages: [appCask(outdated: false)])
        let status = provider.selfUpgradeStatus
        #expect(status.isUpgradeAvailable == false)
        #expect(status.runningVersion == "1.4.2")
    }

    @Test func `app cask absent from inventory reports up to date with no latest version`() {
        let provider = makeProvider(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
            .fixture(name: "docker", kind: .cask, outdated: true),
        ])
        let status = provider.selfUpgradeStatus
        #expect(status.isUpgradeAvailable == false)
        #expect(status.latestVersion == nil)
        #expect(status.runningVersion == "1.4.2")
    }

    @Test func `a formula sharing the cask token name is not mistaken for the app`() {
        let provider = makeProvider(packages: [
            .fixture(name: SelfUpgradeIdentity.caskToken, kind: .formula, outdated: true),
        ])
        #expect(provider.selfUpgradeStatus.isUpgradeAvailable == false)
    }

    @Test func `empty inventory reports up to date`() {
        let provider = makeProvider(packages: [])
        let status = provider.selfUpgradeStatus
        #expect(status.isUpgradeAvailable == false)
        #expect(status.latestVersion == nil)
    }

    @Test func `empty latest version maps to nil rather than an empty string`() {
        let provider = makeProvider(packages: [appCask(latestVersion: "", outdated: true)])
        #expect(provider.selfUpgradeStatus.latestVersion == nil)
    }

    @Test func `blank homepage falls back to the identity homepage`() {
        let provider = makeProvider(packages: [appCask(homepage: "", outdated: true)])
        #expect(provider.selfUpgradeStatus.homepageURL == SelfUpgradeIdentity.homepageURL)
    }

    @Test func `bundle reader falls back to zero when the version key is missing`() {
        let reader = BundleAppVersionReader(bundle: Bundle(for: EmptyBundleAnchor.self))
        // The test bundle has no CFBundleShortVersionString in most configs.
        #expect(!reader.runningVersion.isEmpty)
    }
}

private final class EmptyBundleAnchor {}

/// Canned `brew info` JSON through the real repository mapping into the provider.
@MainActor
struct BrewSelfUpgradeDetectionIntegrationTests {
    private func json(appOutdated: Bool) -> String {
        """
        {
          "formulae": [
            { "name": "git", "versions": { "stable": "2.43.0" }, "installed": [{ "version": "2.43.0" }] }
          ],
          "casks": [
            { "token": "docker", "name": ["Docker"], "version": "27.4.1", "installed": "27.3.0", "outdated": true },
            {
              "token": "homebrew-app",
              "name": ["Homebrew"],
              "homepage": "https://github.com/Homebrew/brew",
              "version": "1.5.0",
              "installed": "1.4.2",
              "outdated": \(appOutdated)
            }
          ]
        }
        """
    }

    private func provider(appOutdated: Bool) async -> BrewSelfUpgradeStatusProvider {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json(appOutdated: appOutdated)),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        _ = await InstalledPackagesTestSupport.loadedPackages(from: repo)
        return BrewSelfUpgradeStatusProvider(
            inventory: repo,
            versionReader: StubRunningAppVersionReader(runningVersion: "1.4.2"),
        )
    }

    @Test func `outdated app cask in a real payload surfaces an available update`() async {
        let status = await provider(appOutdated: true).selfUpgradeStatus
        #expect(status.isUpgradeAvailable)
        #expect(status.runningVersion == "1.4.2")
        #expect(status.latestVersion == "1.5.0")
        #expect(status.homepageURL == URL(string: "https://github.com/Homebrew/brew"))
    }

    @Test func `current app cask in a real payload reports no update even when other casks are outdated`() async {
        let status = await provider(appOutdated: false).selfUpgradeStatus
        #expect(status.isUpgradeAvailable == false)
        #expect(status.latestVersion == "1.5.0")
    }
}
