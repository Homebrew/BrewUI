//
//  InstalledViewModel.swift
//  Brew
//

import Foundation
import Observation

struct InstalledPackagesContent: Equatable {
    var packages: [InstalledBrewPackage]

    var shouldShowFormulaeSection: Bool {
        !formulaPackages.isEmpty
    }

    var shouldShowCasksSection: Bool {
        !caskPackages.isEmpty
    }

    var formulaPackages: [InstalledBrewPackage] {
        packages.filter { $0.kind == .formula }
    }

    var caskPackages: [InstalledBrewPackage] {
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

@Observable
@MainActor
final class InstalledViewModel {
    @ObservationIgnored private let repository: any InstalledInventoryObserving

    private var preSearchSelectedPackageID: InstalledBrewPackage.ID?
    private var searchPreviewSelectedPackageID: InstalledBrewPackage.ID?
    private var didCommitSelectionDuringSearch = false
    var searchQuery: String = "" {
        didSet {
            updateSelectionForSearchQueryChange(from: oldValue, to: searchQuery)
        }
    }

    private var selectedPackageID: InstalledBrewPackage.ID?

    /// Projects the shared repository's inventory through the active search query. The repository is the
    /// single source of truth; this view model owns only screen-local search and selection state.
    var state: InstalledLoadState {
        switch repository.state {
        case .loading:
            .loading
        case let .failed(error):
            .error(Self.userMessage(for: error))
        case let .loaded(packages):
            .loaded(Self.filteredContent(InstalledPackagesContent(packages: packages), query: searchQuery))
        }
    }

    var activeSelectedPackageID: InstalledBrewPackage.ID? {
        let candidate = searchPreviewSelectedPackageID ?? selectedPackageID
        if let candidate, allRows.contains(where: { $0.id == candidate }) {
            return candidate
        }
        return firstVisibleRowID()
    }

    var totalPackageCount: Int {
        allRows.count
    }

    /// Initial fetch with no rows yet — show blocking spinner.
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

    var selectedPackage: InstalledBrewPackage? {
        allRows.first(where: { $0.id == activeSelectedPackageID })
    }

    /// Loads from Homebrew via the shared repository (`ARCHITECTURE.md`: View → ViewModel → Repository → Service).
    init(repository: any InstalledInventoryObserving) {
        self.repository = repository
    }

    func load() async {
        await repository.load()
    }

    /// Reloads installed packages without clearing the list UI (the repository keeps prior data on failure).
    func refresh() async {
        await repository.load(forceRefresh: true)
    }

    func setSelection(_ selection: InstalledBrewPackage.ID?) {
        if isSearchActive {
            didCommitSelectionDuringSearch = true
            searchPreviewSelectedPackageID = nil
        }
        if let selection {
            selectedPackageID = selection
        } else {
            selectedPackageID = firstVisibleRowID()
        }
    }

    func clearSelection() {
        selectedPackageID = firstVisibleRowID()
        searchPreviewSelectedPackageID = nil
    }

    func selectInstalledPackage(id: InstalledBrewPackage.ID) {
        guard allRows.contains(where: { $0.id == id }) else {
            return
        }
        setSelection(id)
    }

    private var isSearchActive: Bool {
        !Self.normalizedSearchQuery(searchQuery).isEmpty
    }

    private var allRows: [InstalledBrewPackage] {
        guard case let .loaded(content) = state else {
            return []
        }
        return content.packages
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

    private func firstVisibleRowID() -> InstalledBrewPackage.ID? {
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

    /// Maps a repository failure into user-facing copy — the presentation decision the repository
    /// deliberately leaves to this layer.
    private static func userMessage(for error: any Error) -> String {
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
