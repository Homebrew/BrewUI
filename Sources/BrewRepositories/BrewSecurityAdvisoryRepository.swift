//
//  BrewSecurityAdvisoryRepository.swift
//  BrewRepositories
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation
import OSLog

private let securityAdvisoryRepositoryLogger = Logger(
    subsystem: "Homebrew.BrewUI",
    category: "BrewSecurityAdvisoryRepository",
)

/// Runs `brew vulns --json` through ``BrewCommandCenter`` so each scan appears in the console, and
/// decodes its findings. A scan is a network round trip per formula batch, so it runs once and its
/// report is reused until it ages out or the installed formulae change.
@Observable
@MainActor
public final class BrewSecurityAdvisoryRepository: SecurityAdvisoryRepository {
    public private(set) var state: LoadState<SecurityAdvisoryReport, any Error> = .loading
    public private(set) var isRefreshing = false
    /// Not set by a failed scan, so a failure is retried on the next visit.
    public private(set) var scannedAt: Date?

    public static let defaultRefreshInterval: TimeInterval = 6 * 3600

    @ObservationIgnored private let commandCenter: any BrewCommandCenter
    @ObservationIgnored private let inventory: any InstalledInventoryObserving
    @ObservationIgnored private let refreshInterval: TimeInterval
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var inFlight: Task<Void, Never>?
    /// The installed formulae the report on screen was scanned against.
    @ObservationIgnored private var scannedInventory: Set<String>?

    public init(
        commandCenter: any BrewCommandCenter,
        inventory: any InstalledInventoryObserving,
        refreshInterval: TimeInterval = BrewSecurityAdvisoryRepository.defaultRefreshInterval,
        now: @escaping @Sendable () -> Date = Date.init,
    ) {
        self.commandCenter = commandCenter
        self.inventory = inventory
        self.refreshInterval = refreshInterval
        self.now = now
    }

    public func load(forceRefresh: Bool) async {
        if let inFlight {
            await inFlight.value
            return
        }
        guard forceRefresh || isStale else {
            return
        }
        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await fetch()
        }
        inFlight = task
        await task.value
        inFlight = nil
    }

    private var isStale: Bool {
        guard case .loaded = state, let scannedAt else {
            return true
        }
        if scannedInventory != currentInventory {
            return true
        }
        return now().timeIntervalSince(scannedAt) >= refreshInterval
    }

    /// Installed formulae and versions, so an install, upgrade or uninstall invalidates the report.
    private var currentInventory: Set<String> {
        let formulae = (inventory.state.value ?? []).filter { $0.kind == .formula }
        return Set(formulae.map { "\($0.name) \($0.installedVersions.joined(separator: ","))" })
    }

    /// The same id on every scan reuses the console pill rather than adding one per visit. The display
    /// command omits `--json`, which only shapes the output for parsing.
    private static let operationID = BrewOperationID(
        maintenanceToken: "vulns",
        displayCommand: "brew vulns",
    )

    private func fetch() async {
        let hasReport = state.isLoaded
        if hasReport {
            isRefreshing = true
        }
        defer { isRefreshing = false }

        let inventoryAtStart = currentInventory
        do {
            let output = try await commandCenter.capture(BrewCommands.vulnsRead(), id: Self.operationID)
            state = try .loaded(Self.report(from: output))
            scannedAt = now()
            scannedInventory = inventoryAtStart
        } catch is CancellationError {
            return
        } catch {
            if hasReport {
                securityAdvisoryRepositoryLogger.error(
                    "brew vulns refresh failed: \(String(describing: error), privacy: .public)",
                )
            } else {
                state = .failed(error)
            }
        }
    }

    /// The exit status is not the verdict: `brew vulns` exits non-zero precisely when it finds an open
    /// advisory or skips a keg, and still prints complete JSON. Only output that does not decode fails.
    static func report(from output: CommandOutput) throws -> SecurityAdvisoryReport {
        let diagnostics = ANSIParser.plainText(output.standardError)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            return try VulnsJSONParser.parse(Data(output.standardOutput.utf8), diagnostics: diagnostics)
        } catch {
            // Homebrew before 7.0 has no `vulns`; brew's own wording is the only signal for that.
            if diagnostics.contains("Unknown command: vulns") {
                throw BrewRepositoryError.unsupportedBrewCommand(command: "brew vulns")
            }
            if output.terminationStatus != 0 {
                throw BrewCommandError.failed(exitCode: output.terminationStatus, stderr: diagnostics)
            }
            securityAdvisoryRepositoryLogger.error(
                "brew vulns --json did not decode: \(String(describing: error), privacy: .public)",
            )
            throw BrewRepositoryError.malformedBrewOutput(command: "brew vulns --json")
        }
    }
}
