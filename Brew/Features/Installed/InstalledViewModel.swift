//
//  InstalledViewModel.swift
//  Brew
//

import Foundation
import Observation

struct InstalledPackagesContent: Equatable {
    var formulaRows: [InstalledPackageRow]
    var caskRows: [InstalledPackageRow]

    var shouldShowFormulaeSection: Bool {
        !formulaRows.isEmpty
    }

    var shouldShowCasksSection: Bool {
        !caskRows.isEmpty
    }
}

enum InstalledLoadState: Equatable {
    case loading
    case loaded(InstalledPackagesContent)
    case error(String)
}

@Observable
@MainActor
final class InstalledViewModel {
    private let repository: InstalledPackagesRepository
    private let detailsRepository: any PackageDetailsRepository

    private var loadedContent: InstalledPackagesContent?
    private var preSearchSelectedPackageID: InstalledPackageRow.ID?
    private var searchPreviewSelectedPackageID: InstalledPackageRow.ID?
    private var didCommitSelectionDuringSearch = false
    private(set) var state: InstalledLoadState = .loading
    var searchQuery: String = "" {
        didSet {
            let previousActiveSelectionID = activeSelectedPackageID
            applyLoadedStateForCurrentQuery()
            updateSelectionForSearchQueryChange(from: oldValue, to: searchQuery)
            if previousActiveSelectionID != activeSelectedPackageID {
                startDetailsLoadForCurrentSelection()
            }
            isSearchSelected = true
        }
    }

    private(set) var selectedPackageID: InstalledPackageRow.ID?
    private(set) var detailsViewModel: InstalledDetailsViewModel?
    var isSearchSelected: Bool = false

    var activeSelectedPackageID: InstalledPackageRow.ID? {
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

    var selectedPackageRow: InstalledPackageRow? {
        allRows.first(where: { $0.id == activeSelectedPackageID })
    }

    /// Loads from Homebrew via the repository (`ARCHITECTURE.md`: View → ViewModel → Repository → Service).
    init(repository: InstalledPackagesRepository, detailsRepository: PackageDetailsRepository) {
        self.repository = repository
        self.detailsRepository = detailsRepository
    }

    func load() async {
        loadedContent = nil
        state = .loading
        do {
            let snapshot = try await repository.loadInstalledPackages()
            let formulaRows = snapshot.formulae.map { Self.row(from: $0, kind: .formula) }
            let caskRows = snapshot.casks.map { Self.row(from: $0, kind: .cask) }
            loadedContent = InstalledPackagesContent(formulaRows: formulaRows, caskRows: caskRows)
            applyLoadedStateForCurrentQuery()
            startDetailsLoadForCurrentSelection()
        } catch {
            state = .error(Self.userMessage(for: error))
            selectedPackageID = nil
            clearDetailsState()
        }
    }

    func toggleSelection(for rowID: InstalledPackageRow.ID) {
        if isSearchActive {
            didCommitSelectionDuringSearch = true
            searchPreviewSelectedPackageID = nil
        }
        if selectedPackageID == rowID {
            selectedPackageID = nil
        } else {
            selectedPackageID = rowID
        }
        startDetailsLoadForCurrentSelection()
    }

    func clearSelection() {
        selectedPackageID = nil
        searchPreviewSelectedPackageID = nil
        startDetailsLoadForCurrentSelection()
    }

    private var isSearchActive: Bool {
        !Self.normalizedSearchQuery(searchQuery).isEmpty
    }

    private var allRows: [InstalledPackageRow] {
        guard case let .loaded(content) = state else {
            return []
        }
        return content.formulaRows + content.caskRows
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

    private func firstVisibleRowID() -> InstalledPackageRow.ID? {
        allRows.first?.id
    }

    private static func filteredContent(_ content: InstalledPackagesContent, query: String) -> InstalledPackagesContent {
        let normalizedQuery = normalizedSearchQuery(query)
        guard !normalizedQuery.isEmpty else {
            return content
        }

        let filteredFormulaRows = content.formulaRows.filter {
            $0.name.localizedCaseInsensitiveContains(normalizedQuery)
        }
        let filteredCaskRows = content.caskRows.filter {
            $0.name.localizedCaseInsensitiveContains(normalizedQuery)
        }
        return InstalledPackagesContent(
            formulaRows: filteredFormulaRows,
            caskRows: filteredCaskRows,
        )
    }

    private static func normalizedSearchQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func startDetailsLoadForCurrentSelection() {
        guard let selectedRow = selectedPackageRow else {
            detailsViewModel = nil
            return
        }

        let detailsViewModel = InstalledDetailsViewModel(
            selectedRow: selectedRow,
            repository: detailsRepository,
        )
        self.detailsViewModel = detailsViewModel
        detailsViewModel.load()
    }

    private func clearDetailsState() {
        detailsViewModel = nil
    }

    private static func row(from info: InstalledPackageInfo, kind: InstalledPackageKind) -> InstalledPackageRow {
        let trimmed = info.version?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let versionLabel: String = if trimmed.isEmpty {
            "—"
        } else {
            displayVersion(trimmed)
        }
        return InstalledPackageRow(
            name: info.name,
            kind: kind,
            description: "",
            installedVersion: versionLabel,
            updateVersion: nil,
        )
    }

    private static func displayVersion(_ raw: String) -> String {
        if raw.hasPrefix("v") || raw.hasPrefix("V") {
            return raw
        }
        return "v\(raw)"
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
