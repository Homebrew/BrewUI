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

/// App-scoped observable that runs `brew doctor` through ``BrewCommandCenter`` and parses its output.
///
/// Routing through the center is what makes the run appear in the bottom console (as a pill the user can
/// open to watch live output) alongside install / upgrade / fix ops — same plumbing, no parallel channel.
/// The actual parsed report is captured by the ``DoctorReadCommand`` instance, which the repo reads after
/// submit completes.
///
/// Long-lived so the report survives leaving and returning to the Doctor tab. `load()` is
/// **stale-while-revalidate**: an existing report stays on screen (`isRefreshing` flips on) while the
/// re-check runs; only the very first load shows `.loading`. Concurrent `load()` calls coalesce onto one
/// in-flight `Task`, and re-submitting the same operation id reuses the existing console pill rather
/// than spawning a new one.
@Observable
@MainActor
public final class BrewDoctorRepository: DoctorRepository {
    public private(set) var state: LoadState<DoctorReport, any Error> = .loading
    public private(set) var isRefreshing = false

    @ObservationIgnored private let commandCenter: any BrewCommandCenter
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    public init(commandCenter: any BrewCommandCenter) {
        self.commandCenter = commandCenter
    }

    public func load() async {
        if let inFlight {
            await inFlight.value
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

    /// Stable id for the doctor pill in the bottom console — using the same id on every load reuses the
    /// existing ``CommandJob`` (its phase updates rather than spawning a new pill on each tab arrival).
    private static let operationID = BrewOperationID(
        maintenanceToken: "doctor",
        displayCommand: "brew doctor",
    )

    private func fetch() async {
        #if DEBUG
            // Local debug-only fixture override. Reads a saved brew doctor transcript instead of running
            // `brew doctor` against the live system — handy for iterating on the parser / detail UI
            // without a real failing environment. Skipped under xctest so the repository tests still
            // exercise their mock runner. Do not commit uncommented.
            let runningInLiveApp = Bundle.main.bundlePath.hasSuffix(".app")
            if runningInLiveApp,
               let fixture = try? String(
                   contentsOfFile: "/Users/Shared/sv-graeme/BrewUI/.ai/plans/brew-doctor-console.txt",
                   encoding: .utf8,
               ) {
                state = .loaded(DoctorOutputParser.parse(fixture))
                return
            }
        #endif
        let hasReport = if case .loaded = state { true } else { false }
        if hasReport {
            isRefreshing = true
        }
        defer { isRefreshing = false }

        let command = DoctorReadCommand()
        do {
            try await commandCenter.submit(id: Self.operationID, command: command)
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
        let combined = await command.capturedOutput
        state = .loaded(DoctorOutputParser.parse(combined))
    }
}
