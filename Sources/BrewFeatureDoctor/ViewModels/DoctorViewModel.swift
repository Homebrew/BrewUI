//
//  DoctorViewModel.swift
//  BrewFeatureDoctor
//

import AppKit
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

/// Coarse view-facing projection of the repository's diagnostics state so the view binds to one decision
/// per state instead of re-deriving it from the report (`AGENTS.md` — passive views).
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
    @ObservationIgnored private let aiEngine: (any AIEngineProtocol)?
    @ObservationIgnored private var fixTasks: [String: Task<Void, Never>] = [:]

    /// The selected issue id — read each row in `listRowBackground`, so this stays O(1) and never
    /// iterates the issues array. Auto-selection of the first issue on a fresh load lives in `load()`.
    private(set) var selectedIssueID: Int?
    /// Fix tokens currently running — drives per-row progress and blocks duplicate submits.
    private(set) var runningFixTokens: Set<String> = []
    /// Inline fix errors keyed by fix token.
    private(set) var fixErrorMessages: [String: String] = [:]
    /// AI diagnostic analysis keyed by issue content id.
    private(set) var aiAnalysisByIssueID: [Int: AIAnalysisResult] = [:]
    /// Issue IDs whose AI analysis task is currently executing.
    private(set) var analyzingIssueIDs: Set<DoctorIssueItem.ID> = []

    /// Whether any AI analysis task is currently executing.
    var isAnalyzingAI: Bool {
        !analyzingIssueIDs.isEmpty
    }

    func isAnalyzingAI(for item: DoctorIssueItem) -> Bool {
        analyzingIssueIDs.contains(item.id)
    }

    init(
        doctorRepository: any DoctorRepository,
        brewCommandCenter: any BrewCommandCenter,
        commandFactory: any BrewMutatingCommandFactory,
        aiEngine: (any AIEngineProtocol)? = nil,
    ) {
        self.doctorRepository = doctorRepository
        self.brewCommandCenter = brewCommandCenter
        self.commandFactory = commandFactory
        self.aiEngine = aiEngine
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
            .failed(BrewErrorCopy.message(for: OperationFailure(catching: error)))
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
    var subtitle: LocalizedStringResource {
        let rechecking = LocalizedStringResource("Re-checking…", bundle: #bundle, comment: "Doctor subtitle while a re-check runs")
        switch presentation {
        case .loading:
            return LocalizedStringResource("Running brew doctor…", bundle: #bundle, comment: "Doctor subtitle during the first check")
        case .healthy:
            return isRefreshing ? rechecking : LocalizedStringResource("No problems found", bundle: #bundle, comment: "Doctor subtitle, healthy")
        case .issues:
            return isRefreshing ? rechecking : LocalizedStringResource("Warnings found", bundle: #bundle, comment: "Doctor subtitle, issues listed")
        case .failed:
            return LocalizedStringResource("The check could not be completed", bundle: #bundle, comment: "Doctor subtitle when brew doctor failed to run")
        }
    }

    var lastCheckedAt: Date? {
        guard case .loaded = state else {
            return nil
        }
        return doctorRepository.reportedAt
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

    func load(forceRefresh: Bool) async {
        await doctorRepository.load(forceRefresh: forceRefresh)
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
                try await brewCommandCenter.perform(command, id: operationID)
            } catch {
                if error is CancellationError {
                    runningFixTokens.remove(token)
                    return
                }
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                let message: String = if case let .failed(reason) = latestPhase {
                    BrewErrorCopy.message(for: reason)
                } else {
                    BrewErrorCopy.message(for: OperationFailure(catching: error))
                }
                fixErrorMessages[token] = message
                runningFixTokens.remove(token)
                return
            }
            runningFixTokens.remove(token)
            await load(forceRefresh: true)
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

// MARK: - AI Diagnostics

extension DoctorViewModel {
    func aiAnalysis(for item: DoctorIssueItem) -> AIAnalysisResult? {
        aiAnalysisByIssueID[item.id]
    }

    func analyzeWithAI(for item: DoctorIssueItem) async {
        guard let aiEngine else { return }
        analyzingIssueIDs.insert(item.id)
        defer { analyzingIssueIDs.remove(item.id) }

        let raw = formatIssueOutput(for: item)
        var result = await aiEngine.analyzeDoctorIssue(title: item.title, rawOutput: raw)

        if let runnable = item.primaryRunnableStep?.displayCommand, !runnable.isEmpty {
            if !result.suggestedCommands.contains(runnable) {
                var commands = result.suggestedCommands.filter { !$0.contains("<") }
                commands.insert(runnable, at: 0)
                result = AIAnalysisResult(
                    summary: result.summary,
                    rootCause: result.rootCause,
                    suggestedCommands: commands,
                    modelName: result.modelName,
                )
            }
        }

        aiAnalysisByIssueID[item.id] = result
    }

    private func formatIssueOutput(for item: DoctorIssueItem) -> String {
        item.blocks.compactMap { block -> String? in
            switch block.content {
            case let .prose(lines): lines.joined(separator: "\n")
            case let .command(steps): steps.map(\.displayCommand).joined(separator: "\n")
            case let .data(items): items.joined(separator: "\n")
            case let .link(links): links.map(\.url.absoluteString).joined(separator: "\n")
            }
        }.joined(separator: "\n")
    }

    func isAICommandRunning(_ command: String) -> Bool {
        runningFixTokens.contains(command)
    }

    func aiCommandError(_ command: String) -> String? {
        fixErrorMessages[command]
    }

    private func isSafeAICommand(_ parts: [String], raw: String, for item: DoctorIssueItem?) -> Bool {
        guard parts.first == "brew" else { return false }
        guard !raw.contains(";"), !raw.contains("&&"), !raw.contains("|"),
              !raw.contains(">"), !raw.contains("<"), !raw.contains("sudo")
        else { return false }

        let sub = parts.count > 1 ? parts[1] : ""
        let isDestructive = ["uninstall", "zap", "rm"].contains(sub)
        let destructiveFlags: Set = ["--overwrite", "--force", "-f", "--zap"]
        let hasDestructiveFlag = parts.contains(where: {
            destructiveFlags.contains($0) || $0.hasPrefix("--overwrite=") || $0.hasPrefix("--force=")
        })
        guard !isDestructive, !hasDestructiveFlag else { return false }

        if sub == "link" {
            let formulaTargets = parts.dropFirst(2).filter { !$0.hasPrefix("-") }
            guard !formulaTargets.isEmpty,
                  formulaTargets.allSatisfy({ !$0.contains("/") && !$0.contains("\\") && !$0.contains("..") })
            else { return false }
        }

        if let item {
            let allowedSafeFixVerbs = ["cleanup", "doctor", "link", "prune", "update"]
            let matchesRunnable = item.primaryRunnableStep?.displayCommand == raw
            let isSafeVerb = allowedSafeFixVerbs.contains(sub)
            guard matchesRunnable || isSafeVerb else { return false }
        }
        return true
    }

    func isAICommandExecutable(_ command: String, for item: DoctorIssueItem? = nil) -> Bool {
        let parts = command.split(separator: " ").map(String.init)
        return isSafeAICommand(parts, raw: command, for: item)
    }

    func runAICommand(_ command: String, for item: DoctorIssueItem? = nil) {
        let parts = command.split(separator: " ").map(String.init)
        guard isSafeAICommand(parts, raw: command, for: item) else { return }

        let args = Array(parts.dropFirst()).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
        guard !args.isEmpty else { return }

        let token = command
        guard !runningFixTokens.contains(token) else { return }

        let operationID = BrewOperationID(maintenanceToken: token, displayCommand: command)
        let brewCommand = commandFactory.doctorFixCommand(arguments: args)
        fixErrorMessages[token] = nil
        runningFixTokens.insert(token)
        fixTasks[token]?.cancel()
        fixTasks[token] = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if !Task.isCancelled {
                    fixTasks[token] = nil
                }
            }
            await executeAICommand(brewCommand, operationID: operationID, token: token)
        }
    }

    private func executeAICommand(_ brewCommand: BrewCommand, operationID: BrewOperationID, token: String) async {
        do {
            try await brewCommandCenter.perform(brewCommand, id: operationID)
        } catch {
            if error is CancellationError {
                runningFixTokens.remove(token)
                return
            }
            let latestPhase = await brewCommandCenter.phase(for: operationID)
            let message: String = if case let .failed(reason) = latestPhase {
                BrewErrorCopy.message(for: reason)
            } else {
                BrewErrorCopy.message(for: OperationFailure(catching: error))
            }
            fixErrorMessages[token] = message
            runningFixTokens.remove(token)
            return
        }
        runningFixTokens.remove(token)
        await load(forceRefresh: true)
    }
}
