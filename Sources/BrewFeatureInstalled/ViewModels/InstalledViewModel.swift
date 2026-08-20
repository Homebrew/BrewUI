//
//  InstalledViewModel.swift
//  Brew
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

struct InstalledPackagesContent: Equatable {
    /// Formulae and casks interleaved into a single list, ordered as the repository sorted them
    /// (by name across both kinds). The per-row kind badge keeps casks and formulae distinguishable.
    var packages: [InstalledBrewPackage]

    var formulaPackages: [InstalledBrewPackage] {
        packages.filter { $0.kind == .formula }
    }

    var caskPackages: [InstalledBrewPackage] {
        packages.filter { $0.kind == .cask }
    }

    var orderedPackageIDs: [InstalledBrewPackage.ID] {
        packages.map(\.id)
    }

    /// Narrows the content to a single package kind for the scope picker. `.all` is the identity —
    /// returning `self` keeps the original ordering intact.
    func filtered(by scope: InstalledPackageScope) -> InstalledPackagesContent {
        switch scope {
        case .all:
            self
        case .formulae:
            InstalledPackagesContent(packages: formulaPackages)
        case .casks:
            InstalledPackagesContent(packages: caskPackages)
        }
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

    /// Package-kind scope picker. Filters the loaded inventory client-side alongside the search query.
    var scope: InstalledPackageScope = .all {
        didSet {
            guard oldValue != scope else {
                return
            }
            updateSelectionForScopeChange()
        }
    }

    private var selectedPackageID: InstalledBrewPackage.ID?

    /// Projects the shared repository's inventory through the active scope and search query. The
    /// repository is the single source of truth; this view model owns only screen-local filter and
    /// selection state.
    var state: LoadState<InstalledPackagesContent, String> {
        switch repository.state {
        case .loading:
            .loading
        case let .failed(error):
            .failed(Self.userMessage(for: error))
        case let .loaded(packages):
            .loaded(Self.filteredContent(
                InstalledPackagesContent(packages: packages),
                scope: scope,
                query: searchQuery,
            ))
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

    /// Mirrors whether the toolbar search field holds the cursor (`.searchFocused`). Owned here —
    /// rather than as view `@State` — so ``shouldFocusList`` can factor it in and stay a pure,
    /// unit-testable decision. Tracks *focus*, not `.searchable(isPresented:)`: on macOS a toolbar
    /// field stays presented after the cursor leaves it, so presentation is no signal at all for
    /// whether stealing focus would interrupt someone.
    var isSearchFieldFocused: Bool = false

    /// Drives the list view's `@FocusState`. The list claims keyboard focus once the inventory has
    /// loaded, but never while the search field is active — auto-focusing the list must not kick the
    /// cursor out of an in-progress search.
    var shouldFocusList: Bool {
        state.isLoaded && !isSearchFieldFocused
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
    /// `initialSelection` seeds `selectedPackageID` for deep links (e.g. cross-tab navigation from a
    /// "Used by" tap). It's intentionally not gated on `allRows` — when the repo is still loading, the
    /// existing `activeSelectedPackageID` fallback returns nil, and once the inventory lands the
    /// candidate resolves naturally via observation-driven re-render.
    init(
        repository: any InstalledInventoryObserving,
        initialSelection: InstalledBrewPackage.ID? = nil,
    ) {
        self.repository = repository
        selectedPackageID = initialSelection
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

    /// Re-homes the search preview when a scope change hides the previewed row. Committed selections
    /// are left untouched: `activeSelectedPackageID` already falls back to the first visible row while a
    /// selection is scoped out, and restores it if the user widens the scope again.
    private func updateSelectionForScopeChange() {
        guard isSearchActive, !didCommitSelectionDuringSearch else {
            return
        }
        searchPreviewSelectedPackageID = firstVisibleRowID()
    }

    private func firstVisibleRowID() -> InstalledBrewPackage.ID? {
        allRows.first?.id
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
