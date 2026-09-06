//
//  BrewDoctorRepository.swift
//  BrewRepositories
//

import BrewCLI
import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation
import OSLog

private let doctorRepositoryLogger = Logger(
    subsystem: "Homebrew.BrewUI",
    category: "BrewDoctorRepository",
)

/// App-scoped observable that runs `brew doctor` through ``BrewCommandCenter``, which is what puts the
/// run in the bottom console, and parses its output.
///
/// Long-lived, so the report survives leaving and returning to the Doctor tab. Refreshes are
/// stale-while-revalidate; arrival re-runs only once the report has aged past ``refreshInterval``.
@Observable
@MainActor
public final class BrewDoctorRepository: DoctorRepository {
    public private(set) var state: LoadState<DoctorReport, any Error> = .loading
    public private(set) var isRefreshing = false

    /// How long a report is treated as current on tab arrival.
    public static let defaultRefreshInterval: TimeInterval = 3600

    @ObservationIgnored private let commandCenter: any BrewCommandCenter
    @ObservationIgnored private let refreshInterval: TimeInterval
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    /// When the last run produced a report. Not set by a failed run, so a failure is retried on the next
    /// arrival rather than sat on for an hour.
    @ObservationIgnored private var reportedAt: Date?

    public init(
        commandCenter: any BrewCommandCenter,
        refreshInterval: TimeInterval = BrewDoctorRepository.defaultRefreshInterval,
        now: @escaping @Sendable () -> Date = Date.init,
    ) {
        self.commandCenter = commandCenter
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

    /// `true` when there is no report yet, or the one on screen has aged past ``refreshInterval``.
    private var isStale: Bool {
        guard case .loaded = state, let reportedAt else {
            return true
        }
        return now().timeIntervalSince(reportedAt) >= refreshInterval
    }

    /// Stable id for the doctor pill in the bottom console — using the same id on every load reuses the
    /// existing ``CommandJob`` (its phase updates rather than spawning a new pill on each tab arrival).
    private static let operationID = BrewOperationID(
        maintenanceToken: "doctor",
        displayCommand: "brew doctor",
    )

    private func fetch() async {
        let hasReport = if case .loaded = state { true } else { false }
        if hasReport {
            isRefreshing = true
        }
        defer { isRefreshing = false }

        let output: CommandOutput
        do {
            // `.doctorRead` output is shown in the console in colour, so it carries ANSI codes; `combinedOutput`
            // strips them before parsing. A non-zero exit (warnings) is not a failure.
            output = try await commandCenter.capture(BrewCommands.doctorRead(), id: Self.operationID)
        } catch is CancellationError {
            return
        } catch {
            if hasReport {
                doctorRepositoryLogger.error(
                    "brew doctor refresh failed: \(error.localizedDescription, privacy: .public)",
                )
            } else {
                state = .failed(error)
            }
            return
        }
        state = .loaded(DoctorOutputParser.parse(Self.combinedOutput(of: output)))
        reportedAt = now()
    }

    /// Combines stdout + stderr (stdout first) into the single text ``DoctorOutputParser`` expects, stripping
    /// ANSI colour — doctor output is colourised for display, but the colour-blind parser needs plain text.
    private static func combinedOutput(of output: CommandOutput) -> String {
        let combined: String = if output.standardError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            output.standardOutput
        } else if output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            output.standardError
        } else {
            output.standardOutput + "\n" + output.standardError
        }
        return ANSIParser.plainText(combined)
    }
}
