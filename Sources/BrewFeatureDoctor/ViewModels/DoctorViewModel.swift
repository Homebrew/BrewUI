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

    // MARK: - Derived state (projected from the repository)

    /// View-friendly mapping of the repository's load state with the failure mapped to user-facing copy.
    /// Drives the body's ``AsyncContentView`` (redacted placeholder on `.loading`, retry on `.failed`).
    var state: LoadState<DoctorReport, String> {
        switch doctorRepository.state {
        case .loading:
            .loading
        case let .loaded(report):
            .loaded(report)
        case let .failed(error):
            .failed(OperationFailure(catching: error).userFacingMessage)
        }
    }

    var presentation: DoctorPresentation {
        switch state {
        case .loading:
            .loading
        case let .loaded(report):
            report.isHealthy ? .healthy : .issues
        case let .failed(message):
            .failed(message)
        }
    }

    /// `true` while a background re-check runs with a prior report on screen (stale-while-revalidate).
    var isRefreshing: Bool {
        doctorRepository.isRefreshing
    }

    var issueItems: [DoctorIssueItem] {
        guard case let .loaded(report) = state else {
            return []
        }
        return report.issues.enumerated().map { DoctorIssueItem(id: $0.offset, issue: $0.element) }
    }

    var issueCountSubtitle: String {
        let count = state.value?.issues.count ?? 0
        if count == 1 {
            return "1 issue found"
        }
        return "\(count) issues found"
    }

    /// Header chrome (Run Again button, re-check spinner) is only meaningful once a report — healthy or
    /// with issues — is on screen. Hidden during the initial load and on failure (the failure surface owns
    /// its own retry affordance via ``AsyncContentView``).
    var showsHeaderControls: Bool {
        switch presentation {
        case .healthy, .issues:
            true
        case .loading, .failed:
            false
        }
    }

    /// Header subtitle copy. Mirrors ``presentation``; while a re-check runs on top of a prior report it
    /// switches to "Re-checking…" so the user knows the visible content is being refreshed.
    var subtitle: String {
        switch presentation {
        case .loading:
            "Running brew doctor…"
        case .healthy:
            isRefreshing ? "Re-checking…" : "No problems found"
        case .issues:
            isRefreshing ? "Re-checking…" : issueCountSubtitle
        case .failed:
            "The check could not be completed"
        }
    }

    /// The selected issue id — read each row in `listRowBackground`, so this stays O(1) and never
    /// iterates the issues array. Auto-selection of the first issue on a fresh load lives in `load()`.
    var activeSelectedIssueID: Int? {
        selectedIssueID
    }

    /// O(1) lookup — the item id is the issue's offset within the loaded report.
    var selectedIssue: DoctorIssueItem? {
        guard let id = selectedIssueID,
              case let .loaded(report) = state,
              report.issues.indices.contains(id)
        else {
            return nil
        }
        return DoctorIssueItem(id: id, issue: report.issues[id])
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
    /// report visible while it refreshes. On a fresh load (no prior selection or a stale one), auto-
    /// selects the first issue so the detail pane has something to show.
    func load() async {
        await doctorRepository.load()
        synchronizeSelectionWithLoadedReport()
    }

    /// Validates ``selectedIssueID`` against the freshly-loaded report. Drops it if the issue is gone
    /// (e.g. a fix resolved it) and defaults to the first issue when nothing is selected.
    private func synchronizeSelectionWithLoadedReport() {
        guard case let .loaded(report) = state else {
            return
        }
        if let selectedIssueID, report.issues.indices.contains(selectedIssueID) {
            return
        }
        selectedIssueID = report.issues.isEmpty ? nil : 0
    }

    /// Submits the issue's suggested `brew` fix as a maintenance operation. Output streams in the bottom
    /// console automatically (the command center projects it like any other op); on success the system is
    /// re-checked so a resolved issue clears. Only single-step, non-admin `brew` command blocks are
    /// runnable; multi-step or `sudo` blocks are copy-only.
    func runFix(for item: DoctorIssueItem) {
        guard let step = item.primaryRunnableStep,
              let arguments = step.arguments
        else {
            return
        }
        let token = step.displayCommand
        guard !runningFixTokens.contains(token) else {
            return
        }

        let operationID = BrewOperationID(maintenanceToken: token, displayCommand: step.displayCommand)
        let command = commandFactory.doctorFixCommand(arguments: arguments)
        fixErrorMessages[token] = nil
        runningFixTokens.insert(token)
        fixTasks[token]?.cancel()
        fixTasks[token] = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await brewCommandCenter.submit(id: operationID, command: command)
            } catch {
                if error is CancellationError {
                    runningFixTokens.remove(token)
                    return
                }
                runningFixTokens.remove(token)
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                if case let .failed(reason) = latestPhase {
                    fixErrorMessages[token] = reason.userFacingMessage
                } else {
                    fixErrorMessages[token] = OperationFailure(catching: error).userFacingMessage
                }
                return
            }
            runningFixTokens.remove(token)
            await load()
        }
    }
}
