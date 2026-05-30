//
//  DoctorViewModel.swift
//  BrewFeatureDoctor
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

/// Coarse view-facing projection of the repository's diagnostics state so the view binds to one decision
/// per state instead of re-deriving it from the report (`CONVENTIONS.md` — passive views).
enum DoctorPresentation: Equatable {
    case loading
    case healthy
    case issues
    case failed(String)
}

@Observable
@MainActor
final class DoctorViewModel {
    @ObservationIgnored private let doctorRepository: any DoctorRepository
    @ObservationIgnored private let brewCommandCenter: any BrewCommandCenter
    @ObservationIgnored private let commandFactory: any BrewMutatingCommandFactory
    @ObservationIgnored private var fixTasks: [String: Task<Void, Never>] = [:]

    private var selectedIssueID: Int?
    /// Fix tokens currently running — drives per-row progress and blocks duplicate submits.
    private(set) var runningFixTokens: Set<String> = []
    /// Inline fix errors keyed by fix token.
    private(set) var fixErrorMessages: [String: String] = [:]

    init(
        doctorRepository: any DoctorRepository,
        brewCommandCenter: any BrewCommandCenter,
        commandFactory: any BrewMutatingCommandFactory,
    ) {
        self.doctorRepository = doctorRepository
        self.brewCommandCenter = brewCommandCenter
        self.commandFactory = commandFactory
    }

    isolated deinit {
        for task in fixTasks.values {
            task.cancel()
        }
    }

    // MARK: - Derived state (projected from the repository)

    var presentation: DoctorPresentation {
        switch doctorRepository.state {
        case .loading:
            .loading
        case let .failed(error):
            .failed(Self.userMessage(for: error))
        case let .loaded(report):
            report.isHealthy ? .healthy : .issues
        }
    }

    /// `true` while a background re-check runs with a prior report on screen (stale-while-revalidate).
    var isRefreshing: Bool {
        doctorRepository.isRefreshing
    }

    var issueItems: [DoctorIssueItem] {
        guard case let .loaded(report) = doctorRepository.state else {
            return []
        }
        return report.issues.enumerated().map { DoctorIssueItem(id: $0.offset, issue: $0.element) }
    }

    var issueCountSubtitle: String {
        let count = issueItems.count
        if count == 1 {
            return "1 issue found"
        }
        return "\(count) issues found"
    }

    var activeSelectedIssueID: Int? {
        let items = issueItems
        if let selectedIssueID, items.contains(where: { $0.id == selectedIssueID }) {
            return selectedIssueID
        }
        return items.first?.id
    }

    var selectedIssue: DoctorIssueItem? {
        issueItems.first { $0.id == activeSelectedIssueID }
    }

    func setSelection(_ id: Int?) {
        selectedIssueID = id
    }

    func isFixRunning(_ item: DoctorIssueItem) -> Bool {
        guard let token = item.fixToken else {
            return false
        }
        return runningFixTokens.contains(token)
    }

    func fixError(_ item: DoctorIssueItem) -> String? {
        guard let token = item.fixToken else {
            return nil
        }
        return fixErrorMessages[token]
    }

    // MARK: - Intents

    /// Runs `brew doctor` via the repository. Called on tab arrival and from "Run Again"; keeps any prior
    /// report visible while it refreshes.
    func load() async {
        await doctorRepository.load()
    }

    /// Submits the issue's suggested `brew` fix as a maintenance operation. Output streams in the bottom
    /// console automatically (the command center projects it like any other op); on success the system is
    /// re-checked so a resolved issue clears. Only single-step, non-admin `brew` sequences are runnable;
    /// multi-step or `sudo` sequences are copy-only.
    func runFix(for item: DoctorIssueItem) {
        guard let sequence = item.primaryRunnableSequence,
              let step = sequence.steps.first,
              let arguments = step.arguments
        else {
            return
        }
        let token = sequence.copyAllText
        guard !runningFixTokens.contains(token) else {
            return
        }

        let operationID = BrewOperationID(maintenanceToken: token, displayCommand: step.displayCommand)
        let command = commandFactory.doctorFixCommand(arguments: arguments)
        fixErrorMessages[token] = nil
        runningFixTokens.insert(token)
        fixTasks[token]?.cancel()
        fixTasks[token] = Task { @MainActor [self] in
            do {
                try await brewCommandCenter.submit(id: operationID, command: command)
            } catch {
                runningFixTokens.remove(token)
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                if case let .failed(reason) = latestPhase {
                    fixErrorMessages[token] = reason.userFacingMessage
                } else {
                    fixErrorMessages[token] = Self.userMessage(for: error)
                }
                return
            }
            runningFixTokens.remove(token)
            await doctorRepository.load()
        }
    }

    private static func userMessage(for error: any Error) -> String {
        switch error {
        case BrewLookupError.executableNotFound:
            String(
                localized: "Could not find Homebrew. Install it or ensure brew is in the default location.",
                comment: "Doctor error when brew binary missing",
            )
        case let BrewCommandError.failed(_, stderr):
            errorMessage(fromStderr: stderr)
        case let BrewCommandError.launchFailed(underlying):
            underlying
        default:
            String(localized: "Something went wrong running brew doctor.", comment: "Doctor generic error")
        }
    }

    private static func errorMessage(fromStderr stderr: String) -> String {
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return String(localized: "Homebrew command failed.", comment: "Doctor generic brew failure")
    }
}
