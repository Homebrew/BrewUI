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

    /// O(1) membership/info lookups, kept in lock-step with ``state``. Tracked by observation so
    /// row views re-render when an install/uninstall changes a package's presence.
    private var lookup: [HomebrewPackageID: InstalledBrewPackage] = [:]

    @ObservationIgnored private let commandRunner: BrewCommandRunning
    @ObservationIgnored private let locator: any BrewExecutableLocating
    @ObservationIgnored private let cache: InstalledInventoryCache
    @ObservationIgnored private let commandCenter: any BrewCommandCenter
    @ObservationIgnored private var completionObserverTask: Task<Void, Never>?

    public init(
        commandRunner: BrewCommandRunning,
        locator: any BrewExecutableLocating,
        cache: InstalledInventoryCache,
        commandCenter: any BrewCommandCenter,
    ) {
        self.commandRunner = commandRunner
        self.locator = locator
        self.cache = cache
        self.commandCenter = commandCenter
        completionObserverTask = Task { @MainActor [weak self] in
            await self?.observeOperationCompletions()
        }
    }

    isolated deinit {
        completionObserverTask?.cancel()
    }

    /// Production wiring: real subprocess + default `brew` lookup, reconciling off `commandCenter`.
    public static func live(
        cache: InstalledInventoryCache,
        commandCenter: any BrewCommandCenter,
    ) -> BrewInstalledPackagesRepository {
        BrewInstalledPackagesRepository(
            commandRunner: BrewCommandService(),
            locator: BrewExecutableLocator(),
            cache: cache,
            commandCenter: commandCenter,
        )
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

    // MARK: - Reconcile on mutating-operation completion

    /// Reconciles after a mutating `brew` operation completes by forcing a fresh fetch. Uses the
    /// existing command-center phase stream (running → idle) rather than a bespoke callback.
    private func observeOperationCompletions() async {
        var lastPhase: [BrewOperationID: BrewOperationPhase] = [:]
        let stream = await commandCenter.allPhaseChanges()
        for await (id, phase) in stream {
            let previous = lastPhase[id] ?? .idle
            lastPhase[id] = phase
            if case .running = previous, case .idle = phase {
                await load(forceRefresh: true)
            }
        }
    }

    // MARK: - Fetch / state plumbing

    private func fetchAndStore() async {
        do {
            let packages = try await fetchInstalledPackages()
            apply(packages)
        } catch is CancellationError {
            return
        } catch {
            // Keep showing cached data if we have any; only surface an error with nothing to show.
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
        let output = try await runInstalledInfoJSON(executable: brew)
        let payload = try decodeInfoJSON(from: output)
        let packages = payload.installedPackages()
        let snapshot = InstalledInventorySnapshot(fetchedAt: .now, packages: packages)
        await cache.replace(snapshot)
        return packages
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
        let data = Data(standardOutput.utf8)
        do {
            return try JSONDecoder().decode(BrewInfoJSON.self, from: data)
        } catch {
            throw BrewCommandError.launchFailed(
                underlying: String(
                    localized: "Failed to decode Homebrew JSON output.",
                    comment: "Installed tab JSON decode failure",
                ),
            )
        }
    }
}

// MARK: - InstalledInventoryReading

@MainActor
public extension BrewInstalledPackagesRepository {
    func installedPackageIDs() async -> Set<InstalledBrewPackage.ID> {
        Set(lookup.keys)
    }
}

// MARK: - Preview / placeholder factories

@MainActor
public extension BrewInstalledPackagesRepository {
    /// Inert instance for the environment default and unscoped subtrees (no brew, no command center bookkeeping).
    static func placeholder() -> BrewInstalledPackagesRepository {
        let context = BrewCommandExecutionContext.noopForTestingAndPreviews()
        return BrewInstalledPackagesRepository(
            commandRunner: context.commandRunner,
            locator: context.locator,
            cache: InstalledInventoryCache(),
            commandCenter: NoopBrewCommandCenter.preview(),
        )
    }

    /// Preloaded, already-`.loaded` repository for SwiftUI previews and preview fakes.
    static func previewLoaded(_ packages: [InstalledBrewPackage]) -> BrewInstalledPackagesRepository {
        let repository = placeholder()
        repository.apply(packages)
        return repository
    }
}
