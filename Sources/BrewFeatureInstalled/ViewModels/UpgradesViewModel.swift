//
//  UpgradesViewModel.swift
//  BrewFeatureInstalled
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

@Observable
@MainActor
final class UpgradesViewModel {
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

    /// Package-kind scope picker. Filters the outdated inventory client-side alongside the search query
    /// and, together with the search, decides what "Upgrade All" actually upgrades (see ``upgradeSelection``).
    var scope: InstalledPackageScope = .all {
        didSet {
            guard oldValue != scope else {
                return
            }
            updateSelectionForScopeChange()
        }
    }

    private var selectedPackageID: InstalledBrewPackage.ID?

    private var runningIDs: Set<BrewOperationID> = []

    /// True while an explicit ``refresh()`` is in flight. The repository keeps its `.loaded` state
    /// during a revalidation, so the header's Refresh button needs its own progress signal.
    private(set) var isRefreshing = false

    var state: LoadState<InstalledPackagesContent, String> {
        switch repository.state {
        case .loading:
            .loading
        case let .failed(error):
            .failed(Self.userMessage(for: error))
        case let .loaded(packages):
            .loaded(
                Self.filteredContent(
                    InstalledPackagesContent(packages: packages.filter(\.outdated)),
                    scope: scope,
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
    /// "nothing matched the search, but upgrades exist".
    var totalOutdatedCount: Int {
        repository.outdatedCount
    }

    /// Initial fetch with no rows yet — show blocking spinner.
    private var shouldShowInitialLoadingIndicator: Bool {
        if case .loading = state {
            return true
        }
        return false
    }

    /// Subtitle for the in-page Upgrades header. Reflects the unfiltered
    /// inventory when no search is active, and "Showing N of M" / "No matches
    /// in M outdated packages" once a query narrows the list. The window-chrome
    /// subtitle is a static tab description owned by `MainWindowView`.
    var outdatedSubtitle: String {
        if shouldShowInitialLoadingIndicator {
            return String(localized: "Loading packages…", comment: "Upgrades tab subtitle while fetching")
        }
        if isFiltering {
            return filteredSubtitle
        }
        return inventorySubtitle
    }

    private var inventorySubtitle: String {
        switch totalOutdatedCount {
        case 0:
            String(
                localized: "All packages are up to date",
                comment: "Upgrades tab subtitle when nothing is outdated",
            )
        case 1:
            String(
                localized: "1 package can be upgraded",
                comment: "Upgrades tab subtitle for a single outdated package",
            )
        default:
            String(
                localized: "\(totalOutdatedCount) packages can be upgraded",
                comment: "Upgrades tab subtitle when multiple packages are outdated",
            )
        }
    }

    /// Subtitle while a scope and/or search filter is narrowing the list: "Showing N of M upgrades", or
    /// "No matches in M outdated packages" when the filters hide every available upgrade.
    private var filteredSubtitle: String {
        let total = totalOutdatedCount
        let visible = outdatedCount
        if visible > 0 {
            return String(
                localized: "Showing \(visible) of \(total) upgrades",
                comment: "Upgrades tab subtitle while filtering with at least one match",
            )
        }
        if total == 1 {
            return String(
                localized: "No matches in 1 outdated package",
                comment: "Upgrades tab subtitle when filters hide the single available upgrade",
            )
        }
        return String(
            localized: "No matches in \(total) outdated packages",
            comment: "Upgrades tab subtitle when filters hide every available upgrade",
        )
    }

    var selectedPackage: InstalledBrewPackage? {
        allRows.first(where: { $0.id == activeSelectedPackageID })
    }

    /// True while at least one upgrade kicked off from this VM is still running.
    /// Submit is coalescing-safe (`SerialBrewCommandCenter` dedupes in-flight IDs),
    /// so this drives the *Upgrade All* button's disabled state, not correctness.
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
        isRefreshing = true
        defer { isRefreshing = false }
        await repository.load(forceRefresh: true)
    }

    private var isSearchActive: Bool {
        !Self.normalizedSearchQuery(searchQuery).isEmpty
    }

    /// True when either the scope picker or the search field is narrowing the outdated inventory.
    var isFiltering: Bool {
        isSearchActive || scope != .all
    }

    /// Rows in the order the list renders them: casks and formulae interleaved, name-sorted across
    /// kinds. `firstVisibleRowID` picks the first of these as the default selection.
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

    /// Re-homes the search preview when a scope change hides the previewed row. Committed selections are
    /// left intact — `activeSelectedPackageID` falls back to the first visible row while a selection is
    /// scoped out and restores it if the scope widens again. Mirrors `InstalledViewModel`.
    private func updateSelectionForScopeChange() {
        guard isSearchActive, !didCommitSelectionDuringSearch else {
            return
        }
        searchPreviewSelectedPackageID = firstVisibleRowID()
    }

    private func firstVisibleRowID() -> InstalledBrewPackage.ID? {
        allRows.first?.id
    }

    /// Maintains `runningIDs` from the command-center stream so `isUpgradingAny`
    /// reflects whether the bulk upgrade is still in flight. Filtered to
    /// `.bulkUpgrade` — the only id this VM submits — so unrelated installs,
    /// uninstalls, and doctor fixes flowing through the shared command center
    /// don't disable the *Upgrade All* button.
    private func observePhaseChanges() async {
        let stream = await brewCommandCenter.allPhaseChanges()
        for await (id, phase) in stream {
            // Any bulk-upgrade selection (all / --formula / --cask / explicit names) counts; unrelated
            // installs, uninstalls, and doctor fixes on the shared stream are ignored.
            guard case .bulkUpgrade = id else {
                continue
            }
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
        scope: InstalledPackageScope,
        query: String,
    ) -> InstalledPackagesContent {
        let scoped = content.filtered(by: scope)
        let normalizedQuery = normalizedSearchQuery(query)
        guard !normalizedQuery.isEmpty else {
            return scoped
        }

        let filteredRows = scoped.packages.filter {
            $0.name.localizedCaseInsensitiveContains(normalizedQuery)
        }
        return InstalledPackagesContent(packages: filteredRows)
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
                comment: "Upgrades tab error when brew binary missing",
            )
        case let BrewCommandError.failed(_, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            return String(localized: "Homebrew command failed.", comment: "Upgrades tab error generic brew failure")
        case let BrewCommandError.launchFailed(underlying):
            return underlying
        default:
            return String(localized: "Something went wrong loading packages.", comment: "Upgrades tab generic error")
        }
    }
}

// MARK: - Upgrade action

extension UpgradesViewModel {
    /// User-facing command rendered by the Updates header's `CommandBlockView`. Derived from the same
    /// ``BrewUpgradeSelection`` that ``upgradeAll()`` submits, so the shown command always matches what runs.
    var bulkUpgradeDisplayCommand: String {
        upgradeSelection.displayCommand
    }

    var bulkUpgradeSummary: String {
        switch upgradeSelection {
        case .all:
            String(
                localized: "Upgrades every outdated package",
                comment: "Upgrades header command summary for an unfiltered batch",
            )
        case .formulae:
            String(
                localized: "Upgrades every outdated formula",
                comment: "Upgrades header command summary scoped to formulae",
            )
        case .casks:
            String(
                localized: "Upgrades every outdated cask",
                comment: "Upgrades header command summary scoped to casks",
            )
        case let .explicit(names):
            Self.searchedUpgradeSummary(count: names.count)
        }
    }

    private static func searchedUpgradeSummary(count: Int) -> String {
        if count == 1 {
            return String(
                localized: "Upgrades the 1 package matching your search",
                comment: "Upgrades header command summary for a single searched package",
            )
        }
        return String(
            localized: "Upgrades the \(count) packages matching your search",
            comment: "Upgrades header command summary for multiple searched packages",
        )
    }

    var isFilteringOutEveryUpgrade: Bool {
        outdatedCount == 0 && totalOutdatedCount > 0
    }

    var emptyUpgradeActionTitle: String {
        if isFilteringOutEveryUpgrade {
            return String(
                localized: "Nothing to upgrade here",
                comment: "Upgrades header stand-in when filters hide every available upgrade",
            )
        }
        return String(
            localized: "Nothing to upgrade",
            comment: "Upgrades header stand-in when no package is outdated",
        )
    }

    /// What "Upgrade All" upgrades, given the active filters:
    /// - A search narrows the batch to the visible rows by name (`brew upgrade git slack`).
    /// - Otherwise the scope picker maps to everything / `--formula` / `--cask`.
    var upgradeSelection: BrewUpgradeSelection {
        if isSearchActive, !allRows.isEmpty {
            return .explicit(allRows.map(\.name))
        }
        switch scope {
        case .all:
            return .all
        case .formulae:
            return .formulae
        case .casks:
            return .casks
        }
    }

    /// Submits one batch `brew upgrade` for ``upgradeSelection`` under ``BrewOperationID/bulkUpgrade(_:)``
    /// carrying that selection. Submit dedupes against the in-flight id, so a re-tap with the same
    /// selection is a no-op. The repository's completion observer reconciles inventory on running→idle,
    /// so finished rows drop from the list when the run completes.
    func upgradeAll() {
        let selection = upgradeSelection
        let id = BrewOperationID.bulkUpgrade(selection)
        let command = commandFactory.bulkUpgradeCommand(selection: selection)
        Task { try? await brewCommandCenter.perform(command, id: id) }
    }

    /// Clears both filters, restoring the full outdated list. Wired to the "Show all upgrades" affordance
    /// on the no-matches empty state.
    func resetFilters() {
        searchQuery = ""
        scope = .all
    }
}

// MARK: - Selection

extension UpgradesViewModel {
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

    func selectNext() {
        guard let currentID = activeSelectedPackageID else {
            if let first = state.value?.orderedPackageIDs.first { setSelection(first) }
            return
        }
        if let nextID = state.value?.orderedPackageIDs.item(after: currentID) {
            setSelection(nextID)
        }
    }

    func selectPrevious() {
        guard let currentID = activeSelectedPackageID else {
            if let last = state.value?.orderedPackageIDs.last { setSelection(last) }
            return
        }
        if let previousID = state.value?.orderedPackageIDs.item(before: currentID) {
            setSelection(previousID)
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
}
