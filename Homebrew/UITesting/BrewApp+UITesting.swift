//
//  BrewApp+UITesting.swift
//  Homebrew
//

import BrewCLI
import BrewCore
import BrewFeatureSelfUpgrade
import BrewNetworking
import BrewSelfUpgradeContract
import BrewUITestContract
import Foundation

/// The `-uiTesting` seams of the composition root. Every member falls through to the live wiring when
/// the process was not launched by the UI-test runner, so `BrewApp.init` reads the same either way.
extension BrewApp {
    /// Cleared at launch, so a previous run's ETag or refresh timestamp cannot decide this run's fetches.
    static let uiTestingDefaultsPrefix = "UITesting."

    /// Everything the runner asked of this process before the composition root reads anything.
    /// Fatal on failure by design: continuing without fixtures would surface later as a product bug.
    static func prepareUITestingProcess(
        uiTesting: BrewUITestingLaunchConfiguration?,
    ) -> BrewUITestingFixtureInstaller.Installation? {
        guard let uiTesting else {
            return nil
        }
        if uiTesting.resetsWindowState {
            clearAutosavedWindowState()
        }
        do {
            return try BrewUITestingFixtureInstaller.install(
                payload: uiTesting.payload,
                scenario: uiTesting.scenario,
            )
        } catch {
            fatalError("UI-test fixtures could not be installed: \(error)")
        }
    }

    /// Network seam. Under `-uiTesting` with a scenario, requests are served in-process by
    /// ``BrewUITestingStubURLProtocol`` on a private ephemeral session; otherwise this is `live()`.
    static func makeAPIClient(uiTesting: BrewUITestingLaunchConfiguration?) -> any BrewAPIClient {
        guard let uiTesting, uiTesting.scenario != nil else {
            return URLSessionBrewAPIClient.live()
        }
        return URLSessionBrewAPIClient.stubbed(protocolClasses: [BrewUITestingStubURLProtocol.self])
    }

    /// Catalogue cache seam. Under `-uiTesting` the bytes land in the run's container, so fixtures
    /// cannot outlive the run or overwrite a real install's cache.
    static func makeCatalogueCache(
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> CatalogueCache {
        guard let fixtures else {
            return CatalogueCache()
        }
        clearUITestingDefaults()
        return CatalogueCache(
            cacheDirectoryURL: fixtures.containerURL.appendingPathComponent(
                "CatalogueCache",
                isDirectory: true,
            ),
            defaultsKeyPrefix: defaultsKeyPrefix(base: "CatalogueCache", fixtures: fixtures),
        )
    }

    /// Analytics cache seam. Same isolation rationale as ``makeCatalogueCache(fixtures:)``.
    static func makeDiscoverAnalyticsCache(
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> DiscoverAnalyticsCache {
        guard let fixtures else {
            return DiscoverAnalyticsCache()
        }
        return DiscoverAnalyticsCache(
            cacheDirectoryURL: fixtures.containerURL.appendingPathComponent(
                "DiscoverAnalytics",
                isDirectory: true,
            ),
            defaultsKeyPrefix: defaultsKeyPrefix(base: "DiscoverAnalytics", fixtures: fixtures),
        )
    }

    static func defaultsKeyPrefix(
        base: String,
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> String {
        fixtures == nil ? base : uiTestingDefaultsPrefix + base
    }

    /// Carried forward, or the relaunched process comes up pointed at the real Homebrew mid-test.
    static func relaunchArguments(uiTesting: BrewUITestingLaunchConfiguration?) -> [String] {
        guard uiTesting != nil else {
            return []
        }
        return [BrewUITestingEnvironmentKey.launchArgument, "YES"]
    }

    /// `fixturesRoot` is omitted: the relaunched app reinstalls the fixture tree into its own temp directory.
    static func relaunchEnvironment(uiTesting: BrewUITestingLaunchConfiguration?) -> [String: String] {
        guard let uiTesting else {
            return [:]
        }
        var environment: [String: String] = [:]
        environment[BrewUITestingEnvironmentKey.scenario] = uiTesting.scenario
        environment[BrewUITestingEnvironmentKey.payload] = uiTesting.payload
        return environment
    }

    static func upgradeEnvironment(
        fixtures: BrewUITestingFixtureInstaller.Installation?,
        uiTesting: BrewUITestingLaunchConfiguration?,
    ) -> [String: String] {
        guard let fixtures, let scenario = uiTesting?.scenario else {
            return [:]
        }
        return [
            BrewUITestingEnvironmentKey.fixturesRoot: fixtures.rootURL.path,
            BrewUITestingEnvironmentKey.scenario: scenario,
        ]
    }

    /// Under `-uiTesting` the transcript stays in the run's container, clear of a real install's log.
    static func selfUpgradeLogFileURL(
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> URL {
        guard let fixtures else {
            return SelfUpgradeHandoffDefaults.productionLogFileURL()
        }
        return fixtures.containerURL.appendingPathComponent("self-upgrade.log")
    }

    /// AppKit reads both at window creation, and a new window with no saved frame is sized to fit the
    /// split view's restored columns — so the second key matters as much as the first.
    static func clearAutosavedWindowState() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys
            where key.hasPrefix("NSWindow Frame ") || key.hasPrefix("NSSplitView Subview Frames ")
        {
            defaults.removeObject(forKey: key)
        }
    }

    static func clearUITestingDefaults() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(uiTestingDefaultsPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Shell seam. A UI-test launch that installed no fake resolves nothing, rather than falling back
    /// to the machine's real Homebrew.
    static func executionContext(
        uiTesting: BrewUITestingLaunchConfiguration?,
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> BrewCommandExecutionContext {
        guard uiTesting != nil else {
            return .live()
        }
        return .uiTesting(brewURL: fixtures?.fakeBrewURL)
    }
}
