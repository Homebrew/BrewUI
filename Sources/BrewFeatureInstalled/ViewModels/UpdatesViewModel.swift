//
//  UpdatesViewModel.swift
//  BrewFeatureInstalled
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

@Observable
@MainActor
final class UpdatesViewModel {
    @ObservationIgnored private let repository: any InstalledInventoryObserving
    @ObservationIgnored private let brewCommandCenter: any BrewCommandCenter
    @ObservationIgnored private let commandFactory: any BrewMutatingCommandFactory
    @ObservationIgnored private var phaseObserverTask: Task<Void, Never>?

    private var preSearchSelectedPackageID: InstalledBrewPackage.ID?
    private var searchPreviewSelectedPackageID: InstalledBrewPackage.ID?
    private var didCommitSelectionDuringSearch = false
    var searchQuery: String = "" {
        didSet {
            updateSelectionForSearchQueryChange(from: oldValue, to: searchQuery)
        }
    }

    private var selectedPackageID: InstalledBrewPackage.ID?

    private var runningIDs: Set<BrewOperationID> = []

    var state: InstalledLoadState {
        switch repository.state {
        case .loading:
            .loading
        case let .failed(error):
            .error(Self.userMessage(for: error))
        case let .loaded(packages):
            .loaded(
                Self.filteredContent(
                    InstalledPackagesContent(packages: packages.filter(\.outdated)),
                    query: searchQuery,
                ),
            )
        }
    }

    var activeSelectedPackageID: InstalledBrewPackage.ID? {
        let candidate = searchPreviewSelectedPackageID ?? selectedPackageID
        if let candidate, allRows.contains(where: { $0.id == candidate }) {
            return candidate
        }
        return firstVisibleRowID()
    }

    var outdatedCount: Int {
        allRows.count
    }

    /// Total installed package count from the underlying inventory, used by the
    /// "All N packages are at their latest versions." empty-state copy.
    var totalInstalledCount: Int {
        (repository.state.value ?? []).count
    }

    /// Outdated count from the underlying inventory, ignoring the active search.
    /// Lets the empty state distinguish "truly nothing to upgrade" from
    /// "nothing matched the search, but updates exist".
    var totalOutdatedCount: Int {
        repository.outdatedCount
    }

    /// Initial fetch with no rows yet — show blocking spinner.
    var shouldShowInitialLoadingIndicator: Bool {
        if case .loading = state {
            return true
        }
        return false
    }

    /// Subtitle for the Updates header and the window chrome. Reflects the
    /// unfiltered inventory when no search is active, and "Showing N of M" /
    /// "No matches in M outdated packages" once a query narrows the list.
    var outdatedSubtitle: String {
        if shouldShowInitialLoadingIndicator {
            return String(localized: "Loading packages…", comment: "Updates tab subtitle while fetching")
        }
        if isSearchActive {
            return searchActiveSubtitle
        }
        return inventorySubtitle
    }

    private var inventorySubtitle: String {
        switch totalOutdatedCount {
        case 0:
            String(
                localized: "All packages are up to date",
                comment: "Updates tab subtitle when nothing is outdated",
            )
        case 1:
            String(
                localized: "1 package can be upgraded",
                comment: "Updates tab subtitle for a single outdated package",
            )
        default:
            String(
                localized: "\(totalOutdatedCount) packages can be upgraded",
                comment: "Updates tab subtitle when multiple packages are outdated",
            )
        }
    }

    private var searchActiveSubtitle: String {
        let total = totalOutdatedCount
        let visible = outdatedCount
        if visible > 0 {
            return String(
                localized: "Showing \(visible) of \(total) updates",
                comment: "Updates tab subtitle while searching with at least one match",
            )
        }
        if total == 1 {
            return String(
                localized: "No matches in 1 outdated package",
                comment: "Updates tab subtitle when search hides the single available update",
            )
        }
        return String(
            localized: "No matches in \(total) outdated packages",
            comment: "Updates tab subtitle when search hides every available update",
        )
    }

    var selectedPackage: InstalledBrewPackage? {
        allRows.first(where: { $0.id == activeSelectedPackageID })
    }

    /// True while at least one upgrade kicked off from this VM is still running.
    /// Submit is coalescing-safe (`SerialBrewCommandCenter` dedupes in-flight IDs),
    /// so this drives the *Update All* button's disabled state, not correctness.
    var isUpgradingAny: Bool {
        !runningIDs.isEmpty
    }

    init(
        repository: any InstalledInventoryObserving,
        brewCommandCenter: any BrewCommandCenter,
        commandFactory: any BrewMutatingCommandFactory,
    ) {
        self.repository = repository
        self.brewCommandCenter = brewCommandCenter
        self.commandFactory = commandFactory
        phaseObserverTask = Task { @MainActor [weak self] in
            await self?.observePhaseChanges()
        }
    }

    isolated deinit {
        phaseObserverTask?.cancel()
    }

    func load() async {
        await repository.load()
    }

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

    /// Enqueues an upgrade for every outdated package. Submit dedupes a duplicate
    /// in-flight `BrewOperationID`, so a re-tap during a batch is a no-op.
    /// The repository's completion observer reconciles inventory on running→idle,
    /// dropping each finished row from this list automatically.
    func upgradeAll() {
        for package in repository.outdatedPackages {
            let id = BrewOperationID(kind: package.kind, name: package.name)
            let command = commandFactory.upgradeCommand(kind: package.kind, name: package.name)
            Task { try? await brewCommandCenter.submit(id: id, command: command) }
        }
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

    /// Maintains `runningIDs` from the command-center stream so `isUpgradingAny`
    /// reflects whether any batch-upgrade is still in flight.
    private func observePhaseChanges() async {
        let stream = await brewCommandCenter.allPhaseChanges()
        for await (id, phase) in stream {
            switch phase {
            case .running:
                runningIDs.insert(id)
            case .idle, .failed:
                runningIDs.remove(id)
            }
        }
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

    /// Maps a repository failure into user-facing copy. Mirrors `InstalledViewModel.userMessage(for:)`.
    private static func userMessage(for error: any Error) -> String {
        switch error {
        case BrewLookupError.executableNotFound:
            return String(
                localized: "Could not find Homebrew. Install it or ensure brew is in the default location.",
                comment: "Updates tab error when brew binary missing",
            )
        case let BrewCommandError.failed(_, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            return String(localized: "Homebrew command failed.", comment: "Updates tab error generic brew failure")
        case let BrewCommandError.launchFailed(underlying):
            return underlying
        default:
            return String(localized: "Something went wrong loading packages.", comment: "Updates tab generic error")
        }
    }
}
