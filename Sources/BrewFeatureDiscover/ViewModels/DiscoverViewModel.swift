import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

/// Package-kind filter for the Discover search field's scope picker.
enum DiscoverSearchScope: CaseIterable, Equatable {
    case all
    case formulae
    case casks
}

@Observable
@MainActor
final class DiscoverViewModel {
    @ObservationIgnored private let discoverPackagesRepository: any DiscoverPackagesRepository
    @ObservationIgnored private let catalogueRepository: any CatalogueRepository
    @ObservationIgnored private let installedRepository: any InstalledPackageStatusReading
    @ObservationIgnored private let topPackagesLimit: Int
    @ObservationIgnored private let analyticsWindow: BrewAnalyticsWindow
    @ObservationIgnored private let searchResultsLimit: Int

    var query: String = "" {
        didSet {
            guard oldValue != query else {
                return
            }
            synchronizeSelectionWithVisibleRows()
        }
    }

    var scope: DiscoverSearchScope = .all {
        didSet {
            guard oldValue != scope else {
                return
            }
            synchronizeSelectionWithVisibleRows()
        }
    }

    /// Catalogue top packages shown on the landing (empty-query) state.
    private(set) var trending: LoadState<[DiscoveryBrewPackage], String> = .loading
    /// Catalogue search results shown while the query is non-empty.
    private(set) var results: LoadState<[DiscoveryBrewPackage], String> = .loaded([])
    private(set) var selectedPackageID: BrewPackage.ID?

    init(
        discoverPackagesRepository: any DiscoverPackagesRepository,
        catalogueRepository: any CatalogueRepository,
        installedRepository: any InstalledPackageStatusReading,
        topPackagesLimit: Int = 10,
        analyticsWindow: BrewAnalyticsWindow = .days30,
        searchResultsLimit: Int = 50,
    ) {
        self.discoverPackagesRepository = discoverPackagesRepository
        self.catalogueRepository = catalogueRepository
        self.installedRepository = installedRepository
        self.topPackagesLimit = topPackagesLimit
        self.analyticsWindow = analyticsWindow
        self.searchResultsLimit = searchResultsLimit
    }

    // MARK: - Display mode

    var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Empty query → trending landing; non-empty → search results.
    var isSearching: Bool {
        !normalizedQuery.isEmpty
    }

    /// The load state the view renders for the current mode.
    var activeState: LoadState<[DiscoveryBrewPackage], String> {
        isSearching ? results : trending
    }

    /// Drives the list view's `@FocusState`. The list only owns keyboard focus on the trending landing
    /// once it has loaded — while a search is active focus belongs to the catalogue search field.
    var shouldFocusList: Bool {
        trending.isLoaded && !isSearching
    }

    /// Search results have no analytics, so install-count metadata is suppressed in that mode.
    var showsInstallMetrics: Bool {
        !isSearching
    }

    // MARK: - Heading

    /// Editorial heading for the list pane, driven by the display mode and result count.
    var paneHeading: String {
        guard isSearching else {
            return String(localized: "Trending", comment: "Discover list heading, trending landing")
        }
        if case .loaded = results, visiblePackages.isEmpty {
            return String(localized: "No matches", comment: "Discover list heading, zero search results")
        }
        return String(localized: "Results", comment: "Discover list heading, search results")
    }

    var subtitleText: String {
        switch activeState {
        case .loading:
            return isSearching
                ? String(localized: "Searching…", comment: "Discover subtitle while searching")
                : String(localized: "Loading packages…", comment: "Discover subtitle while loading")
        case .failed:
            return isSearching
                ? String(localized: "Could not search packages", comment: "Discover subtitle on search error")
                : String(localized: "Could not load packages", comment: "Discover subtitle on error")
        case .loaded:
            guard isSearching else {
                return String(
                    localized: "Most-installed packages in the last 30 days",
                    comment: "Discover subhead on the trending landing",
                )
            }
            return searchResultsSubtitle
        }
    }

    private var searchResultsSubtitle: String {
        let count = visiblePackages.count
        if count == 0 {
            return String(
                localized: "Nothing found for “\(normalizedQuery)”",
                comment: "Discover subhead, no search results",
            )
        }
        if count == 1 {
            return String(
                localized: "1 package matches “\(normalizedQuery)”",
                comment: "Discover subhead, single search result",
            )
        }
        return String(
            localized: "\(count) packages match “\(normalizedQuery)”",
            comment: "Discover subhead, search result count",
        )
    }

    /// The trending landing decorates its subhead with an upward-trend glyph once data is loaded.
    var showsSubtitleTrendIcon: Bool {
        if case .loaded = activeState, !isSearching {
            return true
        }
        return false
    }

    var isSubtitleError: Bool {
        if case .failed = activeState {
            return true
        }
        return false
    }

    // MARK: - Sections

    var showsFormulaeSection: Bool {
        scope != .casks
    }

    var showsCasksSection: Bool {
        scope != .formulae
    }

    /// Trending mode frames sections editorially ("Popular"); search mode drops the framing.
    var formulaeSectionTitle: String {
        isSearching
            ? String(localized: "Formulae", comment: "Discover formulae section header while searching")
            : String(localized: "Popular Formulae", comment: "Discover trending formulae section header")
    }

    var casksSectionTitle: String {
        isSearching
            ? String(localized: "Casks", comment: "Discover casks section header while searching")
            : String(localized: "Popular Casks", comment: "Discover trending casks section header")
    }

    /// Loaded packages of the active mode, scope-filtered, in display order. Drives selection.
    var visiblePackages: [DiscoveryBrewPackage] {
        guard case let .loaded(packages) = activeState else {
            return []
        }
        var visible: [DiscoveryBrewPackage] = []
        if showsFormulaeSection {
            visible += Self.section(packages, kind: .formula)
        }
        if showsCasksSection {
            visible += Self.section(packages, kind: .cask)
        }
        return visible
    }

    var selectedPackage: DiscoveryBrewPackage? {
        guard let selectedPackageID, let package = visiblePackages.first(where: { $0.id == selectedPackageID }) else {
            return nil
        }
        return package
    }

    // MARK: - Helpers

    /// Packages of one kind, in the order the source handed them down. Ranking is the source's job:
    /// trending arrives in the backend's install-rank order, search in the catalogue's match order — the
    /// view model never re-sorts, it only partitions by kind.
    static func section(
        _ packages: [DiscoveryBrewPackage],
        kind: HomebrewPackageKind,
    ) -> [DiscoveryBrewPackage] {
        packages.filter { $0.kind == kind }
    }

    private static func userMessage(for error: Error, searching: Bool) -> String {
        if case let BrewAPIClientError.transport(underlying) = error {
            return underlying
        }
        if searching {
            return String(
                localized: "Something went wrong searching the catalogue.",
                comment: "Discover tab generic search failure",
            )
        }
        return String(
            localized: "Something went wrong loading Discover packages.",
            comment: "Discover tab generic load failure",
        )
    }
}

// MARK: - Selection

extension DiscoverViewModel {
    func setSelection(_ packageID: BrewPackage.ID?) {
        if let packageID {
            guard visiblePackages.contains(where: { $0.id == packageID }) else {
                return
            }
            selectedPackageID = packageID
        } else {
            selectedPackageID = visiblePackages.first?.id
        }
    }

    func selectNext() {
        let orderedIDs = visiblePackages.map(\.id)
        guard let currentID = selectedPackageID else {
            if let first = orderedIDs.first { setSelection(first) }
            return
        }
        if let nextID = orderedIDs.item(after: currentID) {
            setSelection(nextID)
        }
    }

    func selectPrevious() {
        let orderedIDs = visiblePackages.map(\.id)
        guard let currentID = selectedPackageID else {
            if let last = orderedIDs.last { setSelection(last) }
            return
        }
        if let previousID = orderedIDs.item(before: currentID) {
            setSelection(previousID)
        }
    }

    private func synchronizeSelectionWithVisibleRows() {
        let visibleIDs = Set(visiblePackages.map(\.id))
        if let selectedPackageID, !visibleIDs.contains(selectedPackageID) {
            self.selectedPackageID = nil
        }
        if selectedPackageID == nil {
            selectedPackageID = visiblePackages.first?.id
        }
    }
}

// MARK: - Loading

extension DiscoverViewModel {
    func load() async {
        trending = .loading
        do {
            let snapshot = try await discoverPackagesRepository.loadTopPackages(
                limit: topPackagesLimit,
                window: analyticsWindow,
            )
            trending = .loaded(snapshot.topFormulae + snapshot.topCasks)
        } catch {
            trending = .failed(Self.userMessage(for: error, searching: false))
        }
        synchronizeSelectionWithVisibleRows()
    }

    /// Issues a catalogue search for the current query. Empty queries skip the call and clear results so
    /// the view falls back to the trending landing.
    func search() async {
        guard isSearching else {
            results = .loaded([])
            synchronizeSelectionWithVisibleRows()
            return
        }
        results = .loading
        do {
            let matches = try await catalogueRepository.searchPackages(
                matching: normalizedQuery,
                limit: searchResultsLimit,
            )
            // Catalogue search has no analytics, so install counts are zero (hidden in this mode).
            results = .loaded(matches.map { DiscoveryBrewPackage(package: $0, thirtyDayInstallCount: 0) })
        } catch {
            results = .failed(Self.userMessage(for: error, searching: true))
        }
        synchronizeSelectionWithVisibleRows()
    }

    /// Re-runs whichever load backs the active mode — wired to the error state's Retry affordance.
    func reloadActive() async {
        if isSearching {
            await search()
        } else {
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
