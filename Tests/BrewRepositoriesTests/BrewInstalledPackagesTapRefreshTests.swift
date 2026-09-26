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

/// `brew info` never auto-updates, so brew is updated first: fully when the user asks, otherwise
/// through `brew outdated` so brew's own auto-update settings apply.
struct BrewInstalledPackagesTapRefreshTests {
    private static let emptyInfoJSON = #"{ "formulae": [], "casks": [] }"#
    private static let update = ["update", "--quiet"]
    private static let outdated = ["outdated", "--quiet"]
    private static let info = ["info", "--installed", "--json=v2"]

    @Test @MainActor func `a user refresh runs a full brew update every time`() async {
        let clock = MutableClock(now: Date(timeIntervalSince1970: 0))
        let runner = RecordingCommandRunner(infoJSON: Self.emptyInfoJSON)
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            now: clock.dateProvider,
        )

        await repo.load(forceRefresh: true)
        clock.now = Date(timeIntervalSince1970: 60)
        await repo.load(forceRefresh: true)

        #expect(await runner.invocations == [Self.update, Self.info, Self.update, Self.info])
        #expect(repo.state.isLoaded)
    }

    @Test @MainActor func `a first load lets brew decide whether to update`() async {
        let runner = RecordingCommandRunner(infoJSON: Self.emptyInfoJSON)
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
        )

        await repo.load()

        #expect(await runner.invocations == [Self.outdated, Self.info])
    }

    @Test @MainActor func `the reconcile after an operation lets brew decide whether to update`() async {
        let commandCenter = ControllableJobsCommandCenter()
        let runner = RecordingCommandRunner(infoJSON: Self.emptyInfoJSON)
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            commandCenter: commandCenter,
        )
        await waitUntil { await commandCenter.hasPhaseSubscriber() }

        let opID = BrewOperationID(kind: .formula, name: "git")
        await commandCenter.emitPhase(id: opID, phase: .running(.upgradeFormula))
        await commandCenter.emitPhase(id: opID, phase: .idle)
        await waitUntil { await runner.invocations.contains(Self.info) }

        #expect(await runner.invocations == [Self.outdated, Self.info])
        #expect(repo.state.isLoaded)
    }

    @Test @MainActor func `automatic update checks run on an interval rather than before every fetch`() async {
        let clock = MutableClock(now: Date(timeIntervalSince1970: 0))
        let cache = InstalledInventoryCache()
        let runner = RecordingCommandRunner(infoJSON: Self.emptyInfoJSON)
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            cache: cache,
            now: clock.dateProvider,
        )

        await Self.automaticFetch(repo, cache: cache)
        clock.now = Date(timeIntervalSince1970: 120)
        await Self.automaticFetch(repo, cache: cache)

        #expect(await runner.count(of: Self.outdated) == 1)

        // Past Homebrew's 5-minute interval for this mode.
        clock.now = Date(timeIntervalSince1970: 400)
        await Self.automaticFetch(repo, cache: cache)

        #expect(await runner.count(of: Self.outdated) == 2)
    }

    @Test @MainActor func `a user refresh restarts the automatic interval`() async {
        let clock = MutableClock(now: Date(timeIntervalSince1970: 0))
        let cache = InstalledInventoryCache()
        let runner = RecordingCommandRunner(infoJSON: Self.emptyInfoJSON)
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            cache: cache,
            now: clock.dateProvider,
        )

        await repo.load(forceRefresh: true)
        clock.now = Date(timeIntervalSince1970: 60)
        await Self.automaticFetch(repo, cache: cache)

        #expect(await runner.count(of: Self.outdated) == 0)
    }

    @Test @MainActor func `a failed tap update still lets the outdated check answer`() async {
        // The taps keep their previous contents, so a stale answer beats no answer.
        let runner = RecordingCommandRunner(
            infoJSON: Self.emptyInfoJSON,
            updateBehavior: .failure(exitCode: 1, stderr: "fatal: not a git repository"),
        )
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
        )

        await repo.load(forceRefresh: true)

        #expect(repo.state.isLoaded)
        #expect(repo.refreshFailure == nil)
        #expect(await runner.invocations.contains(["info", "--installed", "--json=v2"]))
    }

    @Test @MainActor func `a persistently failing tap update does not stall every automatic fetch`() async {
        let clock = MutableClock(now: Date(timeIntervalSince1970: 0))
        let cache = InstalledInventoryCache()
        let runner = RecordingCommandRunner(
            infoJSON: Self.emptyInfoJSON,
            updateBehavior: .throwing,
        )
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            cache: cache,
            now: clock.dateProvider,
        )

        await Self.automaticFetch(repo, cache: cache)
        clock.now = Date(timeIntervalSince1970: 60)
        await Self.automaticFetch(repo, cache: cache)

        // The attempt is timestamped even when it fails, so the interval still applies.
        #expect(await runner.count(of: Self.outdated) == 1)
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
        )

        await repo.load()

        #expect(await runner.invocations.isEmpty)
    }

    /// A stale cache is what launch and tab loads find, so `load()` refetches without the user asking.
    @MainActor
    private static func automaticFetch(_ repo: BrewInstalledPackagesRepository, cache: InstalledInventoryCache) async {
        await cache.replace(InstalledInventorySnapshot(fetchedAt: .distantPast, packages: []))
        await repo.load()
    }
}

// MARK: - Doubles

/// Yields until `condition` holds, bounded so a regression fails an expectation instead of hanging.
@MainActor
private func waitUntil(_ condition: () async -> Bool) async {
    for _ in 0 ..< 500 {
        if await condition() {
            return
        }
        await Task.yield()
    }
}

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
        guard arguments.first == "outdated" || arguments.first == "update" else {
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
