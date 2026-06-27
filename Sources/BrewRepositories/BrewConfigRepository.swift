//
//  BrewConfigRepository.swift
//  BrewRepositories
//

import BrewCLI
import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation
import OSLog

private let configRepositoryLogger = Logger(
    subsystem: "Homebrew.BrewUI",
    category: "BrewConfigRepository",
)

/// Live `ConfigRepository`: app-scoped `@Observable` that runs `brew config`, parses it, and also surfaces
/// the `HOMEBREW_*` rows reported by `brew config` itself. Cache-first by default — repeated `load()` calls
/// return immediately when state is already `.loaded`. `forceRefresh: true` keeps the existing snapshot
/// visible while a new fetch runs, only replacing on success.
@Observable
@MainActor
public final class BrewConfigRepository: ConfigRepository {
    /// Drives the loading / loaded / failed chrome for any consumer. Stays `.loaded` across silent
    /// revalidations so the UI never flashes back to a loading state on background → foreground.
    public private(set) var state: LoadState<BrewConfigSnapshot, any Error> = .loading

    /// Freshness flag set by ``invalidate()``. When `true`, the next `load()` refetches even though
    /// `state` is `.loaded`. Cleared on a successful refetch.
    @ObservationIgnored private var isStale: Bool = false

    @ObservationIgnored private let commandRunner: any BrewCommandRunning
    @ObservationIgnored private let locator: any BrewExecutableLocating
    public init(
        commandRunner: any BrewCommandRunning,
        locator: any BrewExecutableLocating,
    ) {
        self.commandRunner = commandRunner
        self.locator = locator
    }

    /// Production wiring: brew is spawned through the user's login + interactive shell
    /// (``LoginShellBrewCommandRunner``) so `brew config` reflects the same environment as Terminal.
    public static func live() -> BrewConfigRepository {
        BrewConfigRepository(
            commandRunner: LoginShellBrewCommandRunner(),
            locator: BrewExecutableLocator(),
        )
    }

    public func load(forceRefresh: Bool) async {
        let needsFetch = forceRefresh || isStale || state.value == nil
        guard needsFetch else {
            return
        }
        let hadCached = state.value != nil
        if !hadCached {
            state = .loading
        }
        do {
            let snapshot = try await fetch()
            state = .loaded(snapshot)
            isStale = false
        } catch is CancellationError {
            return
        } catch {
            // Keep showing cached data when refreshing fails; only surface an error if we had nothing.
            if hadCached {
                configRepositoryLogger.error(
                    "brew config revalidation failed: \(error.localizedDescription, privacy: .public)",
                )
            } else {
                state = .failed(error)
            }
        }
    }

    public func invalidate() {
        isStale = true
    }

    private func fetch() async throws -> BrewConfigSnapshot {
        let brew = try locator.findBrewExecutable()
        let output = try await commandRunner.run(executableURL: brew, arguments: ["config"])
        guard output.terminationStatus == 0 else {
            throw BrewCommandError.failed(exitCode: output.terminationStatus, stderr: output.standardError)
        }
        let parsed = BrewConfigParser.parse(output.standardOutput)
        return BrewConfigSnapshot(
            entries: parsed.entries,
            environment: reportedHomebrewEnvironmentEntries(in: parsed.entries),
        )
    }

    private func reportedHomebrewEnvironmentEntries(in entries: [BrewConfigEntry]) -> [BrewConfigEntry] {
        entries.filter { $0.key.hasPrefix("HOMEBREW_") }
    }
}
