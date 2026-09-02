//
//  BrewInstalledPackagesTapRefreshTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewRepositories
import BrewServicesTestSupport
import Foundation
import Testing

/// With the API off, package data comes from tap clones that only `brew update` refreshes.
struct BrewInstalledPackagesTapRefreshTests {
    private static let emptyInfoJSON = #"{ "formulae": [], "casks": [] }"#

    @Test @MainActor func `taps are updated before the outdated check when the API is disabled`() async {
        let runner = RecordingCommandRunner(infoJSON: Self.emptyInfoJSON)
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            environment: StubHomebrewEnvironment(installFromAPIDisabled: true),
        )

        await repo.load(forceRefresh: true)

        #expect(await runner.invocations == [
            ["update", "--auto-update", "--quiet"],
            ["info", "--installed", "--json=v2"],
        ])
        #expect(repo.state.isLoaded)
    }

    @Test @MainActor func `taps are left alone when brew reads from the API`() async {
        let runner = RecordingCommandRunner(infoJSON: Self.emptyInfoJSON)
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            environment: StubHomebrewEnvironment(installFromAPIDisabled: false),
        )

        await repo.load(forceRefresh: true)

        // brew refreshes the API files on its own TTL, so an update here is pure cost.
        #expect(await runner.invocations == [["info", "--installed", "--json=v2"]])
    }

    @Test @MainActor func `the tap update runs on an interval rather than before every fetch`() async {
        let clock = MutableClock(now: Date(timeIntervalSince1970: 0))
        let runner = RecordingCommandRunner(infoJSON: Self.emptyInfoJSON)
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            environment: StubHomebrewEnvironment(installFromAPIDisabled: true),
            now: clock.dateProvider,
        )

        await repo.load(forceRefresh: true)
        clock.now = Date(timeIntervalSince1970: 120)
        await repo.load(forceRefresh: true)

        #expect(await runner.count(of: ["update", "--auto-update", "--quiet"]) == 1)

        // Past Homebrew's 5-minute interval for this mode.
        clock.now = Date(timeIntervalSince1970: 400)
        await repo.load(forceRefresh: true)

        #expect(await runner.count(of: ["update", "--auto-update", "--quiet"]) == 2)
    }

    @Test @MainActor func `a failed tap update still lets the outdated check answer`() async {
        // The taps keep their previous contents, so a stale answer beats no answer.
        let runner = RecordingCommandRunner(
            infoJSON: Self.emptyInfoJSON,
            updateBehavior: .failure(exitCode: 1, stderr: "fatal: not a git repository"),
        )
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            environment: StubHomebrewEnvironment(installFromAPIDisabled: true),
        )

        await repo.load(forceRefresh: true)

        #expect(repo.state.isLoaded)
        #expect(repo.refreshFailure == nil)
        #expect(await runner.invocations.contains(["info", "--installed", "--json=v2"]))
    }

    @Test @MainActor func `a persistently failing tap update does not stall every fetch`() async {
        let clock = MutableClock(now: Date(timeIntervalSince1970: 0))
        let runner = RecordingCommandRunner(
            infoJSON: Self.emptyInfoJSON,
            updateBehavior: .throwing,
        )
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            environment: StubHomebrewEnvironment(installFromAPIDisabled: true),
            now: clock.dateProvider,
        )

        await repo.load(forceRefresh: true)
        clock.now = Date(timeIntervalSince1970: 60)
        await repo.load(forceRefresh: true)

        // The attempt is timestamped even when it fails, so the interval still applies.
        #expect(await runner.count(of: ["update", "--auto-update", "--quiet"]) == 1)
    }

    @Test @MainActor func `a cache-first load that skips the fetch also skips the tap update`() async {
        let cache = InstalledInventoryCache()
        await cache.replace(
            InstalledInventorySnapshot(fetchedAt: .now, packages: [.fixture(name: "git", kind: .formula)]),
        )
        let runner = RecordingCommandRunner(infoJSON: Self.emptyInfoJSON)
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            cache: cache,
            environment: StubHomebrewEnvironment(installFromAPIDisabled: true),
        )

        await repo.load()

        #expect(await runner.invocations.isEmpty)
    }
}

// MARK: - Doubles

/// Mutable time source, so interval behaviour is asserted without waiting.
@MainActor
private final class MutableClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }

    nonisolated var dateProvider: @Sendable () -> Date {
        // The repository is @MainActor; the synchronous @Sendable closure type can't say so.
        // swiftlint:disable:next assume_isolated
        { MainActor.assumeIsolated { self.now } }
    }
}

/// Records the `brew` argument lists it was asked to run.
private actor RecordingCommandRunner: BrewCommandRunning {
    enum UpdateBehavior {
        case success
        case failure(exitCode: Int32, stderr: String)
        case throwing
    }

    private let infoJSON: String
    private let updateBehavior: UpdateBehavior
    private(set) var invocations: [[String]] = []

    init(infoJSON: String, updateBehavior: UpdateBehavior = .success) {
        self.infoJSON = infoJSON
        self.updateBehavior = updateBehavior
    }

    func count(of arguments: [String]) -> Int {
        invocations.count(where: { $0 == arguments })
    }

    func run(executableURL _: URL, arguments: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        invocations.append(arguments)
        guard arguments.first == "update" else {
            return CommandOutput(standardOutput: infoJSON, standardError: "", terminationStatus: 0)
        }
        switch updateBehavior {
        case .success:
            return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
        case let .failure(exitCode, stderr):
            return CommandOutput(standardOutput: "", standardError: stderr, terminationStatus: exitCode)
        case .throwing:
            throw BrewCommandError.launchFailed(underlying: "could not spawn brew")
        }
    }
}
