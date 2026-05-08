//
//  InstalledViewModel.swift
//  Brew
//

import Foundation
import Observation
import OSLog

struct InstalledPackagesContent: Equatable {
    var packages: [BrewPackage]

    var shouldShowFormulaeSection: Bool {
        !formulaPackages.isEmpty
    }

    var shouldShowCasksSection: Bool {
        !caskPackages.isEmpty
    }

    var formulaPackages: [BrewPackage] {
        packages.filter { $0.kind == .formula }
    }

    var caskPackages: [BrewPackage] {
        packages.filter { $0.kind == .cask }
    }
}

enum InstalledLoadState: Equatable {
    case loading
    case loaded(InstalledPackagesContent)
    case error(String)

    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }
}

private let installedPackagesRefreshLogger = Logger(
    subsystem: "Homebrew.BrewUI",
    category: "InstalledViewModel",
)

@Observable
@MainActor
final class InstalledViewModel {
    private let repository: InstalledPackagesRepository
    private let brewCommandCenter: any BrewCommandCenter
    private var observerTask: Task<Void, Never>?

    private var loadedContent: InstalledPackagesContent?
    private var preSearchSelectedPackageID: BrewPackage.ID?
    private var searchPreviewSelectedPackageID: BrewPackage.ID?
    private var didCommitSelectionDuringSearch = false
    private(set) var state: InstalledLoadState = .loading
    var searchQuery: String = "" {
        didSet {
            applyLoadedStateForCurrentQuery()
            updateSelectionForSearchQueryChange(from: oldValue, to: searchQuery)
            isSearchSelected = true
        }
    }

    private(set) var selectedPackageID: BrewPackage.ID?
    var isSearchSelected: Bool = false

    var activeSelectedPackageID: BrewPackage.ID? {
        searchPreviewSelectedPackageID ?? selectedPackageID
    }

    var totalPackageCount: Int {
        allRows.count
    }

    /// Initial fetch with no rows yet — show blocking spinner (unit-tested via `init(testing…)`).
    var shouldShowInitialLoadingIndicator: Bool {
        if case .loading = state {
            return true
        }
        return false
    }

    var packageCountSubtitle: String {
        if shouldShowInitialLoadingIndicator {
            return String(localized: "Loading packages…", comment: "Installed tab subtitle while fetching")
        }
        if totalPackageCount == 1 {
            return "1 package"
        }
        return "\(totalPackageCount) packages"
    }

    var selectedPackage: BrewPackage? {
        allRows.first(where: { $0.id == activeSelectedPackageID })
    }

    /// Loads from Homebrew via the repository (`ARCHITECTURE.md`: View → ViewModel → Repository → Service).
    init(repository: InstalledPackagesRepository, brewCommandCenter: any BrewCommandCenter) {
        self.repository = repository
        self.brewCommandCenter = brewCommandCenter
        observerTask = Task { @MainActor [weak self] in
            await self?.observeOperationCompletions()
        }
    }

    isolated deinit {
        observerTask?.cancel()
    }

    func load() async {
        loadedContent = nil
        state = .loading
        do {
            let snapshot = try await repository.loadInstalledPackages()
            loadedContent = Self.packagesContent(from: snapshot)
            applyLoadedStateForCurrentQuery()
        } catch {
            state = .error(Self.userMessage(for: error))
            selectedPackageID = nil
        }
    }

    /// Reloads installed packages without clearing the list UI (no `.loading` state).
    func refresh() async {
        guard state.isLoaded else {
            await load()
            return
        }
        do {
            let snapshot = try await repository.loadInstalledPackages()
            loadedContent = Self.packagesContent(from: snapshot)
            applyLoadedStateForCurrentQuery()
        } catch {
            installedPackagesRefreshLogger.error(
                "Refresh installed packages failed: \(error.localizedDescription, privacy: .public)",
            )
        }
    }

    private func observeOperationCompletions() async {
        var lastPhase: [BrewOperationID: BrewOperationPhase] = [:]
        let stream = await brewCommandCenter.allPhaseChanges()
        for await (id, phase) in stream {
            let previous = lastPhase[id] ?? .idle
            lastPhase[id] = phase
            if case .running = previous, case .idle = phase {
                await refresh()
            }
        }
    }

    func toggleSelection(for packageID: BrewPackage.ID) {
        if isSearchActive {
            didCommitSelectionDuringSearch = true
            searchPreviewSelectedPackageID = nil
        }
        if selectedPackageID == packageID {
            selectedPackageID = nil
        } else {
            selectedPackageID = packageID
        }
    }

    func clearSelection() {
        selectedPackageID = nil
        searchPreviewSelectedPackageID = nil
    }

    private var isSearchActive: Bool {
        !Self.normalizedSearchQuery(searchQuery).isEmpty
    }

    private var allRows: [BrewPackage] {
        guard case let .loaded(content) = state else {
            return []
        }
        return content.packages
    }

    private func applyLoadedStateForCurrentQuery() {
        guard let loadedContent else {
            return
        }
        state = .loaded(Self.filteredContent(loadedContent, query: searchQuery))
    }

    private func updateSelectionForSearchQueryChange(from oldQuery: String, to newQuery: String) {
        let oldNormalizedQuery = Self.normalizedSearchQuery(oldQuery)
        let newNormalizedQuery = Self.normalizedSearchQuery(newQuery)
        let wasSearchActive = !oldNormalizedQuery.isEmpty
        let isSearchActive = !newNormalizedQuery.isEmpty

        if !wasSearchActive, isSearchActive {
            preSearchSelectedPackageID = selectedPackageID
            didCommitSelectionDuringSearch = false
            searchPreviewSelectedPackageID = firstVisibleRowID()
            return
        }

        if wasSearchActive, isSearchActive {
            if !didCommitSelectionDuringSearch {
                searchPreviewSelectedPackageID = firstVisibleRowID()
            }
            return
        }

        if wasSearchActive, !isSearchActive {
            if !didCommitSelectionDuringSearch {
                selectedPackageID = preSearchSelectedPackageID
            }
            preSearchSelectedPackageID = nil
            searchPreviewSelectedPackageID = nil
            didCommitSelectionDuringSearch = false
        }
    }

    private func firstVisibleRowID() -> BrewPackage.ID? {
        allRows.first?.id
    }

    private static func filteredContent(
        _ content: InstalledPackagesContent,
        query: String,
    ) -> InstalledPackagesContent {
        let normalizedQuery = normalizedSearchQuery(query)
        guard !normalizedQuery.isEmpty else {
            return content
        }

        let filteredFormulaRows = content.formulaPackages.filter {
            $0.name.localizedCaseInsensitiveContains(normalizedQuery)
        }
        let filteredCaskRows = content.caskPackages.filter {
            $0.name.localizedCaseInsensitiveContains(normalizedQuery)
        }
        return InstalledPackagesContent(
            packages: filteredFormulaRows + filteredCaskRows,
        )
    }

    private static func normalizedSearchQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func packagesContent(from snapshot: [BrewPackage]) -> InstalledPackagesContent {
        InstalledPackagesContent(packages: snapshot)
    }

    private static func userMessage(for error: Error) -> String {
        switch error {
        case BrewLookupError.executableNotFound:
            return String(
                localized: "Could not find Homebrew. Install it or ensure brew is in the default location.",
                comment: "Installed tab error when brew binary missing",
            )
        case let BrewCommandError.failed(_, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            return String(localized: "Homebrew command failed.", comment: "Installed tab error generic brew failure")
        case let BrewCommandError.launchFailed(underlying):
            return underlying
        default:
            return String(localized: "Something went wrong loading packages.", comment: "Installed tab generic error")
        }
    }
}
