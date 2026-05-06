//
//  InstalledViewModel.swift
//  Brew
//

import Foundation
import Observation
import OSLog

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
    private let detailsRepository: any PackageDetailsRepository
    private let brewCommandCenter: any BrewCommandCenter

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
    init(
        repository: InstalledPackagesRepository,
        detailsRepository: PackageDetailsRepository,
        brewCommandCenter: any BrewCommandCenter = NoopBrewCommandCenter.forTesting(),
    ) {
        self.repository = repository
        self.detailsRepository = detailsRepository
        self.brewCommandCenter = brewCommandCenter
    }

    func load() async {
        loadedContent = nil
        state = .loading
        do {
            let snapshot = try await repository.loadInstalledPackages()
            loadedContent = Self.packagesContent(from: snapshot)
            applyLoadedStateForCurrentQuery()
            startDetailsLoadForCurrentSelection()
        } catch {
            state = .error(Self.userMessage(for: error))
            selectedPackageID = nil
            clearDetailsState()
        }
    }

    /// Reloads installed packages without clearing the list UI (no `.loading` state).
    func refreshInstalledPackagesPreservingUI() async {
        guard state.isLoaded else {
            await load()
            return
        }
        do {
            let snapshot = try await repository.loadInstalledPackages()
            loadedContent = Self.packagesContent(from: snapshot)
            applyLoadedStateForCurrentQuery()
            startDetailsLoadForCurrentSelection()
        } catch {
            installedPackagesRefreshLogger.error(
                "Refresh installed packages failed: \(error.localizedDescription, privacy: .public)",
            )
        }
    }

    /// Applies a single row update to the currently loaded catalog without a full repository reload.
    func mergeInstalledRow(_ row: InstalledPackageRow) {
        guard var loadedContent else {
            return
        }

        var didReplace = false
        didReplace = replaceRow(withID: row.id, in: &loadedContent.formulaRows, using: row) || didReplace
        didReplace = replaceRow(withID: row.id, in: &loadedContent.caskRows, using: row) || didReplace
        guard didReplace else {
            return
        }

        self.loadedContent = loadedContent
        applyLoadedStateForCurrentQuery()
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

    private static func filteredContent(
        _ content: InstalledPackagesContent,
        query: String,
    ) -> InstalledPackagesContent {
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
            brewCommandCenter: brewCommandCenter,
            onUpgradeSuccess: { [weak self] in
                guard let self else {
                    return
                }
                guard let refreshedRow = await refreshedInstalledRow(selectedRow) else {
                    return
                }
                mergeInstalledRow(refreshedRow)
            },
        )
        self.detailsViewModel = detailsViewModel
        detailsViewModel.load()
    }

    private func clearDetailsState() {
        detailsViewModel = nil
    }

    private static func packagesContent(from snapshot: InstalledPackagesSnapshot) -> InstalledPackagesContent {
        InstalledPackagesContent(
            formulaRows: snapshot.formulae.map { Self.rowForInstalledPackageInfo($0, kind: .formula) },
            caskRows: snapshot.casks.map { Self.rowForInstalledPackageInfo($0, kind: .cask) },
        )
    }

    /// Shared mapper for converting repository package info into a list-row presentation model.
    static func rowForInstalledPackageInfo(
        _ info: InstalledPackageInfo,
        kind: InstalledPackageKind,
    ) -> InstalledPackageRow {
        let trimmed = info.version?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let versionLabel: String = if trimmed.isEmpty {
            "—"
        } else {
            InstalledBrewVersionFormatting.displayVersionLabel(trimmedRaw: trimmed)
        }
        return InstalledPackageRow(
            name: info.name,
            kind: kind,
            description: "",
            installedVersion: versionLabel,
            updateVersion: InstalledBrewVersionFormatting.upgradeDisplayLabel(from: info.upgradeToVersion),
        )
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

extension InstalledViewModel {
    func refreshedInstalledRow(_ row: InstalledPackageRow) async -> InstalledPackageRow? {
        do {
            let info = try await repository.loadInstalledPackage(kind: row.kind, named: row.name)
            return Self.rowForInstalledPackageInfo(info, kind: row.kind)
        } catch {
            let message = error.localizedDescription
            installedPackagesRefreshLogger.error(
                "Refresh installed row failed for \(row.id, privacy: .public): \(message, privacy: .public)",
            )
            return nil
        }
    }
}

private func replaceRow(
    withID rowID: InstalledPackageRow.ID,
    in rows: inout [InstalledPackageRow],
    using updatedRow: InstalledPackageRow,
) -> Bool {
    guard let index = rows.firstIndex(where: { $0.id == rowID }) else {
        return false
    }
    rows[index] = updatedRow
    return true
}
