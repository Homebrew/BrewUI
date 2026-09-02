//
//  InstalledPackagesTestSupport.swift
//  BrewServicesTestSupport
//
//  Shared boundary fakes for BrewInstalledPackagesRepository slice tests (`CONVENTIONS.md` — Testing).
//

import BrewCLI
import BrewCore
import BrewRepositories
import Foundation

public enum InstalledPackagesTestSupport {
    /// Stable fake path passed to `commandRunner` when using `BrewExecutableLocator(overrideURL:)`.
    public static let fakeBrewExecutableURL = URL(fileURLWithPath: "/fake/brew")

    /// Wired like production slice tests; the default environment is the API path, so no tap refresh runs.
    @MainActor
    public static func repository(
        commandRunner: BrewCommandRunning,
        locator: (any BrewExecutableLocating)? = nil,
        cache: InstalledInventoryCache? = nil,
        commandCenter: any BrewCommandCenter = NoopBrewCommandCenter.forTesting(),
        environment: any HomebrewEnvironmentReading = StubHomebrewEnvironment(installFromAPIDisabled: false),
        now: @escaping @Sendable () -> Date = Date.init,
    ) -> BrewInstalledPackagesRepository {
        let resolvedCache = cache ?? InstalledInventoryCache()
        let resolvedLocator = locator ?? BrewExecutableLocator(overrideURL: fakeBrewExecutableURL)
        return BrewInstalledPackagesRepository(
            commandRunner: commandRunner,
            locator: resolvedLocator,
            cache: resolvedCache,
            commandCenter: commandCenter,
            environment: environment,
            now: now,
        )
    }

    /// Loads (force-refresh) and returns the resulting packages, failing the test if the repository did not reach `.loaded`.
    @MainActor
    public static func loadedPackages(
        from repository: BrewInstalledPackagesRepository,
    ) async -> [InstalledBrewPackage] {
        await repository.load(forceRefresh: true)
        guard case let .loaded(packages) = repository.state else {
            return []
        }
        return packages
    }

    // MARK: Localized copy (must match `InstalledViewModel.userMessage`)

    public static func localizedBrewExecutableNotFoundMessage() -> String {
        String(
            localized: "Could not find Homebrew. Install it or ensure brew is in the default location.",
            comment: "Installed tab error when brew binary missing",
        )
    }

    public static func localizedGenericLoadFailureMessage() -> String {
        String(
            localized: "Something went wrong loading packages.",
            comment: "Installed tab generic error",
        )
    }

    /// Response for `brew info --installed --json=v2`.
    public static func responsesInstalledInfoFailure(
        standardOutput: String = "",
        standardError: String,
        terminationStatus: Int32,
    ) -> [[String]: CommandOutput] {
        [
            ["info", "--installed", "--json=v2"]: CommandOutput(
                standardOutput: standardOutput,
                standardError: standardError,
                terminationStatus: terminationStatus,
            ),
        ]
    }

    /// Success response for `brew info --installed --json=v2`.
    public static func installedInfoJSONResponse(
        standardOutput: String,
        terminationStatus: Int32 = 0,
        standardError: String = "",
    ) -> [[String]: CommandOutput] {
        [
            ["info", "--installed", "--json=v2"]: CommandOutput(
                standardOutput: standardOutput,
                standardError: standardError,
                terminationStatus: terminationStatus,
            ),
        ]
    }
}
