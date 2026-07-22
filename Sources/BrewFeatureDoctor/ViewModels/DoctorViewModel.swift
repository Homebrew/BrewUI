//
//  DoctorViewModel.swift
//  BrewFeatureDoctor
//

import AppKit
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

    /// The selected issue id — read each row in `listRowBackground`, so this stays O(1) and never
    /// iterates the issues array. Auto-selection of the first issue on a fresh load lives in `load()`.
    private(set) var selectedIssueID: Int?
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

    /// Drives the issues list's `@FocusState`. The list only owns keyboard focus once a report has
    /// loaded — loading and failure states have no rows to focus.
    var shouldFocusList: Bool {
        state.isLoaded
    }

    var rawDoctorOutput: String? {
        guard case let .loaded(report) = state, !report.rawOutput.isEmpty else {
            return nil
        }
        return report.rawOutput
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
            isRefreshing ? "Re-checking…" : "Warnings found"
        case .failed:
            "The check could not be completed"
        }
    }

    /// Linear scan over `report.issues` keyed by the content id. `brew doctor` reports a handful of
    /// issues at most and this only runs when the detail pane re-renders.
    var selectedIssue: DoctorIssueItem? {
        guard let id = selectedIssueID, case let .loaded(report) = state else {
            return nil
        }
        return report.issues.lazy.map(DoctorIssueItem.init(issue:)).first { $0.id == id }
    }

    func setSelection(_ id: Int?) {
        selectedIssueID = id
    }

    /// Issue ids in the order their rows render — grouped by descending severity, matching
    /// `DoctorIssueGroup.grouped(from:)` — so keyboard navigation steps through the list as shown.
    var orderedIssueIDs: [Int] {
        guard case let .loaded(report) = state else {
            return []
        }
        return DoctorIssueGroup.grouped(from: report).flatMap { $0.items.map(\.id) }
    }

    func selectNext() {
        guard let currentID = selectedIssueID else {
            if let first = orderedIssueIDs.first { setSelection(first) }
            return
        }
        if let nextID = orderedIssueIDs.item(after: currentID) {
            setSelection(nextID)
        }
    }

    func selectPrevious() {
        guard let currentID = selectedIssueID else {
            if let last = orderedIssueIDs.last { setSelection(last) }
            return
        }
        if let previousID = orderedIssueIDs.item(before: currentID) {
            setSelection(previousID)
        }
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

    func copyDoctorOutput() {
        guard let output = rawDoctorOutput else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }

    /// Runs `brew doctor` via the repository. Called on tab arrival and from "Run Again"; keeps any prior
    /// report visible while it refreshes. On a fresh load (no prior selection or a stale one), auto-
    /// selects the first issue so the detail pane has something to show.
    func load() async {
        await doctorRepository.load()
        synchronizeSelectionWithLoadedReport()
    }

    /// Validates ``selectedIssueID`` against the freshly-loaded report by content id, so selection
    /// follows the same issue across reloads even when a different issue has been resolved and the
    /// surviving issues have shifted position. Drops the selection if the issue is gone and defaults
    /// to the first issue when nothing is selected.
    private func synchronizeSelectionWithLoadedReport() {
        guard case let .loaded(report) = state else {
            return
        }
        let ids = Set(report.issues.lazy.map(DoctorIssueItem.contentID(for:)))
        if let selectedIssueID, ids.contains(selectedIssueID) {
            return
        }
        selectedIssueID = report.issues.first.map(DoctorIssueItem.contentID(for:))
    }

    /// Submits the issue's suggested `brew` fix as a maintenance operation. Output streams in the bottom
    /// console automatically (the command center projects it like any other op); on success the system is
    /// re-checked so a resolved issue clears. Only single-step, non-admin `brew` command blocks are
    /// runnable; multi-step or `sudo` blocks are copy-only.
    func runFix(for item: DoctorIssueItem) {
        guard let step = item.primaryRunnableStep,
              let token = item.fixToken,
              let arguments = step.arguments
        else {
            return
        }
        guard !runningFixTokens.contains(token) else {
            return
        }

        let operationID = BrewOperationID(maintenanceToken: token, displayCommand: token)
        let command = commandFactory.doctorFixCommand(arguments: arguments)
        fixErrorMessages[token] = nil
        runningFixTokens.insert(token)
        fixTasks[token]?.cancel()
        fixTasks[token] = Task { @MainActor [weak self] in
            guard let self else { return }
            // Re-running the same token cancels and replaces the slot before this
            // task can clear it; the cancelled task observes Task.isCancelled and
            // leaves the newer task's entry intact.
            defer {
                if !Task.isCancelled {
                    fixTasks[token] = nil
                }
            }
            do {
                try await brewCommandCenter.submit(id: operationID, command: command)
            } catch {
                if error is CancellationError {
                    runningFixTokens.remove(token)
                    return
                }
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                let message: String = if case let .failed(reason) = latestPhase {
                    reason.userFacingMessage
                } else {
                    OperationFailure(catching: error).userFacingMessage
                }
                fixErrorMessages[token] = message
                runningFixTokens.remove(token)
                return
            }
            runningFixTokens.remove(token)
            await load()
        }
    }
}

extension Array where Element: Equatable {
    func item(after value: Element) -> Element? {
        guard let index = firstIndex(of: value), index + 1 < count else {
            return nil
        }
        return self[index + 1]
    }

    func item(before value: Element) -> Element? {
        guard let index = firstIndex(of: value), index - 1 >= 0 else {
            return nil
        }
        return self[index - 1]
    }
}
