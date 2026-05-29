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

/// App-scoped observable that runs `brew doctor` read-only and parses its output into a ``DoctorReport``.
///
/// Long-lived so the report survives leaving and returning to the Doctor tab. `load()` refreshes in the
/// background: once a report is on screen it stays put (`isRefreshing` flips on) until the new one arrives,
/// rather than blanking to a spinner. Concurrent `load()` calls coalesce onto one in-flight run.
///
/// `brew doctor` exits non-zero when it finds warnings — that is the normal "issues found" path, not a
/// failure, so the exit code is ignored and both streams are parsed. A thrown error means `brew` could not
/// be located or the subprocess failed to launch.
@Observable
@MainActor
public final class BrewDoctorRepository: DoctorRepository {
    public private(set) var state: LoadState<DoctorReport, any Error> = .loading
    public private(set) var isRefreshing = false

    @ObservationIgnored private let commandRunner: BrewCommandRunning
    @ObservationIgnored private let locator: any BrewExecutableLocating
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    public init(commandRunner: BrewCommandRunning, locator: any BrewExecutableLocating) {
        self.commandRunner = commandRunner
        self.locator = locator
    }

    /// Production wiring: real subprocess + default `brew` lookup.
    public static func live() -> BrewDoctorRepository {
        BrewDoctorRepository(commandRunner: BrewCommandService(), locator: BrewExecutableLocator())
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

    /// Stale-while-revalidate: an existing report stays on screen (with ``isRefreshing`` set) while the
    /// re-check runs; only the very first load shows `.loading`. A failed refresh keeps the prior report.
    private func fetch() async {
        let hasReport = if case .loaded = state { true } else { false }
        if hasReport {
            isRefreshing = true
        }
        defer { isRefreshing = false }

        do {
            let report = try await runDoctor()
            state = .loaded(report)
        } catch is CancellationError {
            // Left the tab mid-refresh; keep whatever is on screen.
        } catch {
            if hasReport {
                doctorRepositoryLogger.error(
                    "brew doctor refresh failed: \(error.localizedDescription, privacy: .public)",
                )
            } else {
                state = .failed(error)
            }
        }
    }

    private func runDoctor() async throws -> DoctorReport {
        let brew = try locator.findBrewExecutable()
        let output = try await commandRunner.run(executableURL: brew, arguments: ["doctor"])
        return DoctorOutputParser.parse(combinedOutput(of: output))
    }

    private func combinedOutput(of output: CommandOutput) -> String {
        let standardError = output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !standardError.isEmpty else {
            return output.standardOutput
        }
        let standardOutput = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !standardOutput.isEmpty else {
            return output.standardError
        }
        return output.standardOutput + "\n" + output.standardError
    }
}
