//
//  BrewInstalledPackagesRepository.swift
//  Brew
//

import BrewCLI
import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation
import OSLog

private let installedRepositoryLogger = Logger(
    subsystem: "Homebrew.BrewUI",
    category: "BrewInstalledPackagesRepository",
)

/// App-scoped single source of truth for installed/outdated package state.
///
/// Long-lived `@Observable` injected into the SwiftUI environment so any surface (Installed list,
/// Discover badges, detail panes) renders from one cache, one fetch, one observable. Views read
/// ``state`` or the synchronous lookups and re-render automatically when the inventory changes.
@Observable
@MainActor
public final class BrewInstalledPackagesRepository: InstalledPackagesRepository {
    /// Drives blocking/loaded/error chrome. Carries the underlying `Error` on failure — presentation
    /// layers (view models) map it to user-facing copy. `failed` only when there is no data to show.
    public private(set) var state: LoadState<[InstalledBrewPackage], any Error> = .loading

    public private(set) var refreshFailure: (any Error)?

    /// O(1) membership/info lookups, kept in lock-step with ``state``. Tracked by observation so
    /// row views re-render when an install/uninstall changes a package's presence.
    private var lookup: [HomebrewPackageID: InstalledBrewPackage] = [:]

    @ObservationIgnored private let commandRunner: BrewCommandRunning
    @ObservationIgnored private let locator: any BrewExecutableLocating
    @ObservationIgnored private let cache: InstalledInventoryCache
    @ObservationIgnored private let environment: any HomebrewEnvironmentReading
    @ObservationIgnored private let now: @Sendable () -> Date
    /// Newest fetch in flight; fetches chain onto it so two refreshes cannot apply out of order.
    @ObservationIgnored private var fetchTask: Task<Void, Never>?

    /// Every mutating operation forces a fetch, so the tap refresh runs on an interval instead.
    @ObservationIgnored private var lastTapUpdateAttempt: Date?

    /// Homebrew's own `HOMEBREW_AUTO_UPDATE_SECS` default for the no-API path.
    private static let tapRefreshInterval: TimeInterval = 300

    public init(
        commandRunner: BrewCommandRunning,
        locator: any BrewExecutableLocating,
        cache: InstalledInventoryCache,
        environment: any HomebrewEnvironmentReading,
        now: @escaping @Sendable () -> Date = Date.init,
    ) {
        self.commandRunner = commandRunner
        self.locator = locator
        self.cache = cache
        self.environment = environment
        self.now = now
    }

    /// Takes the context rather than building its own runner, so the composition root points every
    /// brew invocation at one place: production's isolated zsh runner, or a UI test's fake executable.
    public convenience init(
        executionContext: BrewCommandExecutionContext,
        cache: InstalledInventoryCache,
    ) {
        self.init(
            commandRunner: executionContext.commandRunner,
            locator: executionContext.locator,
            cache: cache,
            environment: BrewConfigEnvironmentReader(executionContext: executionContext),
        )
    }

    /// Production wiring: the shared zsh execution policy.
    public static func live(cache: InstalledInventoryCache) -> BrewInstalledPackagesRepository {
        BrewInstalledPackagesRepository(executionContext: .live(), cache: cache)
    }

    // MARK: - Synchronous lookups (row rendering)

    public func isInstalled(_ id: HomebrewPackageID) -> Bool {
        lookup[id] != nil
    }

    public func info(for id: HomebrewPackageID) -> InstalledBrewPackage? {
        lookup[id]
    }

    // MARK: - Lifecycle

    /// Cache-first by default: fresh cache paints instantly with no refetch; stale cache paints immediately
    /// and then reconciles with a fresh fetch; an empty cache fetches. `forceRefresh` always fetches.
    /// (Call `load()` — the no-arg convenience — via ``InstalledInventoryObserving``.)
    public func load(forceRefresh: Bool) async {
        guard !forceRefresh else {
            await fetchAndStore()
            return
        }

        switch await cache.cachedPackages() {
        case let .fresh(packages):
            apply(packages)
        case let .stale(packages):
            apply(packages)
            await fetchAndStore()
        case .empty:
            await fetchAndStore()
        }
    }

    // MARK: - Fetch / state plumbing

    /// Waits for any fetch already in flight, then fetches. Joining it instead would answer a reconcile
    /// with a snapshot taken before `brew` exited.
    private func fetchAndStore() async {
        let previous = fetchTask
        let task = Task { @MainActor [weak self] in
            await previous?.value
            await self?.performFetch()
        }
        fetchTask = task
        await task.value
        if fetchTask == task {
            fetchTask = nil
        }
    }

    private func performFetch() async {
        do {
            let packages = try await fetchInstalledPackages()
            // Only a completed fetch clears this; repainting a cached snapshot answers nothing.
            refreshFailure = nil
            apply(packages)
        } catch is CancellationError {
            return
        } catch {
            // Keep showing cached data if we have any; only surface an error with nothing to show.
            refreshFailure = error
            if case .loaded = state {
                installedRepositoryLogger.error(
                    "Installed inventory revalidation failed: \(error.localizedDescription, privacy: .public)",
                )
            } else {
                state = .failed(error)
                lookup = [:]
            }
        }
    }

    private func apply(_ packages: [InstalledBrewPackage]) {
        state = .loaded(packages)
        lookup = Dictionary(packages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func fetchInstalledPackages() async throws -> [InstalledBrewPackage] {
        let brew = try locator.findBrewExecutable()
        await updateTapsIfNeeded(executable: brew)
        let output = try await runInstalledInfoJSON(executable: brew)
        let payload = try decodeInfoJSON(from: output)
        let packages = payload.installedPackages()
        let snapshot = InstalledInventorySnapshot(fetchedAt: .now, packages: packages)
        await cache.replace(snapshot)
        return packages
    }

    /// `brew info` is not auto-updated by brew, and with the API off its data comes from tap clones —
    /// so without this the outdated check answers from the user's last manual `brew update`, forever.
    private func updateTapsIfNeeded(executable: URL) async {
        guard await environment.isInstallFromAPIDisabled() else {
            return
        }
        if let lastTapUpdateAttempt, now().timeIntervalSince(lastTapUpdateAttempt) < Self.tapRefreshInterval {
            return
        }
        lastTapUpdateAttempt = now()
        do {
            let output = try await commandRunner.run(
                executableURL: executable,
                arguments: ["update", "--auto-update", "--quiet"],
            )
            guard output.terminationStatus == 0 else {
                throw BrewCommandError.failed(exitCode: output.terminationStatus, stderr: output.standardError)
            }
        } catch {
            // Not fatal: the info fetch below decides whether the check produced an answer.
            installedRepositoryLogger.error(
                "Tap refresh before the outdated check failed: \(error.localizedDescription, privacy: .public)",
            )
        }
    }

    private func runInstalledInfoJSON(executable: URL) async throws -> String {
        let arguments = ["info", "--installed", "--json=v2"]
        let output = try await commandRunner.run(executableURL: executable, arguments: arguments)
        guard output.terminationStatus == 0 else {
            throw BrewCommandError.failed(exitCode: output.terminationStatus, stderr: output.standardError)
        }
        return output.standardOutput
    }

    private func decodeInfoJSON(from standardOutput: String) throws -> BrewInfoJSON {
        let command = "brew info --installed --json=v2"
        let data = Data(standardOutput.utf8)
        do {
            return try JSONDecoder().decode(BrewInfoJSON.self, from: data)
        } catch {
            installedRepositoryLogger.error("Failed to decode \(command, privacy: .public): \(error)")
            throw BrewRepositoryError.malformedBrewOutput(command: command)
        }
    }
}

// MARK: - BrewOperationReconciling

extension BrewInstalledPackagesRepository: BrewOperationReconciling {
    /// Refetches the inventory before the command center publishes the terminal phase. Survives
    /// cancellation of the submitting task, since ``fetchAndStore()`` works in an unstructured task.
    public func reconcile() async {
        await load(forceRefresh: true)
    }
}

// MARK: - InstalledInventoryReading

@MainActor
public extension BrewInstalledPackagesRepository {
    func installedPackageIDs() async -> Set<InstalledBrewPackage.ID> {
        Set(lookup.keys)
    }
}
