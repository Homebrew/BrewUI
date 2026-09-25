//
//  InstalledViewModel.swift
//  Brew
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

/// What the Installed header renders after a "Save Brewfile…" submission.
enum BrewfileSaveOutcome: Equatable {
    /// The dump finished; `url` is the file `brew` wrote.
    case saved(url: URL)
    /// The dump failed; `message` is user-facing copy. The technical detail stays in the console.
    case failed(message: String)
}

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

    func filtered(hidingDependencies: Bool) -> InstalledPackagesContent {
        guard hidingDependencies else { return self }
        return InstalledPackagesContent(packages: packages.filter(\.installedOnRequest))
    }
}

@Observable
@MainActor
final class InstalledViewModel {
    @ObservationIgnored private let repository: any InstalledInventoryObserving
    @ObservationIgnored private let preferences: any InstalledPreferences
    @ObservationIgnored let brewCommandCenter: any BrewCommandCenter
    @ObservationIgnored let commandFactory: any BrewMutatingCommandFactory
    @ObservationIgnored var brewfileSaveTask: Task<Void, Never>?

    /// Outcome of the most recent "Save Brewfile…" submission — one property for the header's
    /// confirmation/error note, cleared when a new dump is submitted.
    var brewfileOutcome: BrewfileSaveOutcome?
    /// `true` while a dump runs: the header disables its button and the console streams the command.
    var isSavingBrewfile = false

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
            updateSelectionForFilterChange()
        }
    }

    /// Computed over `preferences` (itself `Observable`) so the value survives relaunch.
    var hideDependencies: Bool {
        get { preferences.hideDependencies }
        set {
            guard newValue != preferences.hideDependencies else {
                return
            }
            preferences.hideDependencies = newValue
            updateSelectionForFilterChange()
        }
    }

    private var selectedPackageID: InstalledBrewPackage.ID?

    /// Projects the repository's inventory through scope, dependency filter and search. The repository
    /// is the source of truth; this view model owns only screen-local filter and selection state.
    var state: LoadState<InstalledPackagesContent, String> {
        switch repository.state {
        case .loading:
            .loading
        case let .failed(error):
            .failed(Self.userMessage(for: error))
        case .loaded:
            .loaded(Self.filteredContent(
                InstalledPackagesContent(packages: repository.userManagedPackages),
                scope: scope,
                hideDependencies: hideDependencies,
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

    var packageCountSubtitle: LocalizedStringResource {
        if shouldShowInitialLoadingIndicator {
            return LocalizedStringResource("Loading packages…", bundle: #bundle, comment: "Installed tab subtitle while fetching")
        }
        if totalPackageCount == 1 {
            return LocalizedStringResource("1 package", bundle: #bundle, comment: "Installed tab subtitle, exactly one package")
        }
        return LocalizedStringResource(
            "\(totalPackageCount) packages",
            bundle: #bundle,
            comment: "Installed tab subtitle; %lld is the package count (never 1)",
        )
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
        preferences: any InstalledPreferences,
        brewCommandCenter: any BrewCommandCenter,
        commandFactory: any BrewMutatingCommandFactory,
        initialSelection: InstalledBrewPackage.ID? = nil,
    ) {
        self.repository = repository
        self.preferences = preferences
        self.brewCommandCenter = brewCommandCenter
        self.commandFactory = commandFactory
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

    func reconcileSelection(
        afterChangingFrom previousIDs: [InstalledBrewPackage.ID],
        to currentIDs: [InstalledBrewPackage.ID],
    ) {
        guard let selectedPackageID,
              !repository.userManagedPackages.contains(where: { $0.id == selectedPackageID }),
              let removedIndex = previousIDs.firstIndex(of: selectedPackageID)
        else {
            return
        }

        self.selectedPackageID = previousIDs[..<removedIndex]
            .reversed()
            .first(where: currentIDs.contains) ?? currentIDs.first
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

    /// Re-homes the search preview when a filter hides the previewed row. Committed selections are left
    /// alone: `activeSelectedPackageID` already falls back while filtered out and restores afterwards.
    private func updateSelectionForFilterChange() {
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
        hideDependencies: Bool,
        query: String,
    ) -> InstalledPackagesContent {
        let scoped = content
            .filtered(by: scope)
            .filtered(hidingDependencies: hideDependencies)
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

    private static func userMessage(for error: any Error) -> String {
        BrewErrorCopy.message(
            for: error,
            fallback: String(
                localized: "Something went wrong loading packages.",
                bundle: #bundle,
                comment: "Installed tab generic error",
            ),
        )
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
