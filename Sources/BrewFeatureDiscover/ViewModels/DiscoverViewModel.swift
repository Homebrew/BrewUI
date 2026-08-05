import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

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

    var trending: LoadState<[DiscoveryBrewPackage], String> {
        switch discoverPackagesRepository.state {
        case .loading:
            .loading
        case let .loaded(packages):
            .loaded(packages)
        case let .failed(error):
            .failed(Self.userMessage(for: error, searching: false))
        }
    }

    private(set) var results: LoadState<[DiscoveryBrewPackage], String> = .loaded([])
    private(set) var selectedPackageID: BrewPackage.ID?

    init(
        discoverPackagesRepository: any DiscoverPackagesRepository,
        catalogueRepository: any CatalogueRepository,
        installedRepository: any InstalledPackageStatusReading,
        searchResultsLimit: Int = 50,
    ) {
        self.discoverPackagesRepository = discoverPackagesRepository
        self.catalogueRepository = catalogueRepository
        self.installedRepository = installedRepository
        self.searchResultsLimit = searchResultsLimit
    }

    // MARK: - Display mode

    var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isSearching: Bool {
        !normalizedQuery.isEmpty
    }

    var activeState: LoadState<[DiscoveryBrewPackage], String> {
        isSearching ? results : trending
    }

    /// Bound to `.searchable(isPresented:)`; lives here so ``shouldFocusList`` can factor it in.
    var isSearchFieldPresented: Bool = false

    /// Never claims focus while the search field is open — clearing the query back to empty must not
    /// kick the cursor out of it.
    var shouldFocusList: Bool {
        trending.isLoaded && !isSearching && !isSearchFieldPresented
    }

    /// Search results have no analytics, so install-count metadata is suppressed in that mode.
    var showsInstallMetrics: Bool {
        !isSearching
    }

    // MARK: - Heading

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
    func load(forceRefresh: Bool = false) async {
        await discoverPackagesRepository.load(forceRefresh: forceRefresh)
        synchronizeSelectionWithVisibleRows()
    }

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

    func reloadActive() async {
        if isSearching {
            await search()
        } else {
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
