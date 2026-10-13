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
/// through `brew update-if-needed` so brew's own auto-update settings apply.
struct BrewInstalledPackagesTapRefreshTests {
    private static let emptyInfoJSON = #"{ "formulae": [], "casks": [] }"#
    private static let update = ["update", "--quiet"]
    private static let updateIfNeeded = ["update-if-needed"]
    private static let info = ["info", "--installed", "--json=v2"]

    @Test @MainActor func `a user refresh runs a full brew update every time`() async {
        let runner = RecordingCommandRunner(infoJSON: Self.emptyInfoJSON)
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
        )

        await repo.load(forceRefresh: true)
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

        #expect(await runner.invocations == [Self.updateIfNeeded, Self.info])
    }

    @Test @MainActor func `the reconcile after an operation lets brew decide whether to update`() async {
        let runner = RecordingCommandRunner(infoJSON: Self.emptyInfoJSON)
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
        )

        await repo.reconcile()

        #expect(await runner.invocations == [Self.updateIfNeeded, Self.info])
        #expect(repo.state.isLoaded)
    }

    @Test @MainActor func `every automatic fetch leaves the update interval to brew`() async {
        let cache = InstalledInventoryCache()
        let runner = RecordingCommandRunner(infoJSON: Self.emptyInfoJSON)
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            cache: cache,
        )

        await Self.automaticFetch(repo, cache: cache)
        await Self.automaticFetch(repo, cache: cache)

        #expect(await runner.count(of: Self.updateIfNeeded) == 2)
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

/// Records the `brew` argument lists it was asked to run.
private actor RecordingCommandRunner: BrewCommandRunning {
    enum UpdateBehavior {
        case success
        case failure(exitCode: Int32, stderr: String)
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
        guard arguments.first == "update-if-needed" || arguments.first == "update" else {
            return CommandOutput(standardOutput: infoJSON, standardError: "", terminationStatus: 0)
        }
        switch updateBehavior {
        case .success:
            return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
        case let .failure(exitCode, stderr):
            return CommandOutput(standardOutput: "", standardError: stderr, terminationStatus: exitCode)
        }
    }
}
