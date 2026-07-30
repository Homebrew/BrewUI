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
        let hasReport = if case .loaded = state { true } else { false }
        if hasReport {
            isRefreshing = true
        }
        defer { isRefreshing = false }

        let output: CommandOutput
        do {
            // `.doctorRead` shows as a coloured console pill, so its output carries ANSI codes; `combinedOutput`
            // strips them before parsing. A non-zero exit (warnings) is not a failure.
            output = try await commandCenter.run(BrewCommands.doctorRead(), id: Self.operationID)
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
    }

    /// Combines stdout + stderr (stdout first) into the single text ``DoctorOutputParser`` expects, stripping
    /// ANSI colour — the doctor pill is colourised for display, but the colour-blind parser needs plain text.
    private static func combinedOutput(of output: CommandOutput) -> String {
        let combined: String
        if output.standardError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            combined = output.standardOutput
        } else if output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            combined = output.standardError
        } else {
            combined = output.standardOutput + "\n" + output.standardError
        }
        return ANSIParser.plainText(combined)
    }
}
