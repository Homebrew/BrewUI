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

/// App-scoped observable that runs `brew doctor` and turns it into a ``DoctorReport``.
///
/// Two runs in parallel: `--json` for the findings, and a plain run through ``BrewCommandCenter`` for the
/// console transcript, since `--json` suppresses the prose. A brew that rejects the switch falls back to
/// parsing the transcript. Refreshes are stale-while-revalidate; arrival re-runs only once the report has
/// aged past ``refreshInterval``.
@Observable
@MainActor
public final class BrewDoctorRepository: DoctorRepository {
    public private(set) var state: LoadState<DoctorReport, any Error> = .loading
    public private(set) var isRefreshing = false

    public static let defaultRefreshInterval: TimeInterval = 3600

    @ObservationIgnored private let commandCenter: any BrewCommandCenter
    @ObservationIgnored private let commandRunner: any BrewCommandRunning
    @ObservationIgnored private let locator: any BrewExecutableLocating
    @ObservationIgnored private let refreshInterval: TimeInterval
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    /// Not set by a failed run, so a failure is retried on the next arrival rather than sat on for an hour.
    public private(set) var reportedAt: Date?

    /// A run that failed to start says nothing about the switch, so it leaves this alone.
    @ObservationIgnored private var supportsStructuredOutput = true

    public init(
        commandCenter: any BrewCommandCenter,
        commandRunner: any BrewCommandRunning,
        locator: any BrewExecutableLocating,
        refreshInterval: TimeInterval = BrewDoctorRepository.defaultRefreshInterval,
        now: @escaping @Sendable () -> Date = Date.init,
    ) {
        self.commandCenter = commandCenter
        self.commandRunner = commandRunner
        self.locator = locator
        self.refreshInterval = refreshInterval
        self.now = now
    }

    public convenience init(
        commandCenter: any BrewCommandCenter,
        executionContext: BrewCommandExecutionContext,
    ) {
        self.init(
            commandCenter: commandCenter,
            commandRunner: executionContext.commandRunner,
            locator: executionContext.locator,
        )
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

        async let structured = fetchStructuredIssues()
        async let transcript = captureTranscript()
        let issues = await structured
        let capture = await transcript

        switch capture {
        case let .success(output):
            let rawOutput = Self.combinedOutput(of: output)
            state = .loaded(DoctorReport(
                issues: issues ?? DoctorOutputParser.parse(rawOutput).issues,
                rawOutput: rawOutput,
            ))
            reportedAt = now()
        case .failure(is CancellationError):
            return
        case let .failure(error):
            // The structured run is the report; losing the transcript costs the raw view, not the report.
            if let issues {
                state = .loaded(DoctorReport(issues: issues, rawOutput: ""))
                reportedAt = now()
                return
            }
            if hasReport {
                doctorRepositoryLogger.error(
                    "brew doctor refresh failed: \(error.localizedDescription, privacy: .public)",
                )
            } else {
                state = .failed(error)
            }
        }
    }

    /// Routed through the center so the run lands in the console.
    private func captureTranscript() async -> Result<CommandOutput, any Error> {
        do {
            return try await .success(commandCenter.capture(BrewCommands.doctorRead(), id: Self.operationID))
        } catch {
            return .failure(error)
        }
    }

    /// Deliberately not routed through the command center, whose work runs serially: this would queue
    /// behind the transcript run instead of alongside it.
    private func fetchStructuredIssues() async -> [DoctorIssue]? {
        guard supportsStructuredOutput else {
            return nil
        }
        let output: CommandOutput
        do {
            let brew = try locator.findBrewExecutable()
            output = try await commandRunner.run(executableURL: brew, arguments: Self.structuredArguments)
        } catch {
            // Says nothing about `--json` — the transcript run reports the real failure.
            return nil
        }
        do {
            // The exit status is ignored: `brew doctor` exits non-zero precisely when it has findings.
            return try DoctorJSONParser.parse(Data(output.standardOutput.utf8))
        } catch {
            supportsStructuredOutput = false
            doctorRepositoryLogger.notice(
                "brew doctor --json produced no readable findings; using the text output instead",
            )
            return nil
        }
    }

    private static let structuredArguments = ["doctor", "--json"]

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
