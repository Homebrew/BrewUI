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

    /// Search results have no analytics, so install-count metadata is suppressed in that mode.
    var showsInstallMetrics: Bool {
        !isSearching
    }

    // MARK: - Heading

    var paneHeading: LocalizedStringResource {
        guard isSearching else {
            return LocalizedStringResource("Trending", bundle: #bundle, comment: "Discover list heading, trending landing")
        }
        if case .loaded = results, visiblePackages.isEmpty {
            return LocalizedStringResource("No matches", bundle: #bundle, comment: "Discover list heading, zero search results")
        }
        return LocalizedStringResource("Results", bundle: #bundle, comment: "Discover list heading, search results")
    }

    var subtitleText: LocalizedStringResource {
        switch activeState {
        case .loading:
            return isSearching
                ? LocalizedStringResource("Searching…", bundle: #bundle, comment: "Discover subtitle while searching")
                : LocalizedStringResource("Loading packages…", bundle: #bundle, comment: "Discover subtitle while loading")
        case .failed:
            return isSearching
                ? LocalizedStringResource("Could not search packages", bundle: #bundle, comment: "Discover subtitle on search error")
                : LocalizedStringResource("Could not load packages", bundle: #bundle, comment: "Discover subtitle on error")
        case .loaded:
            guard isSearching else {
                return LocalizedStringResource(
                    "Most-installed packages in the last 30 days",
                    bundle: #bundle,
                    comment: "Discover subhead on the trending landing",
                )
            }
            return searchResultsSubtitle
        }
    }

    private var searchResultsSubtitle: LocalizedStringResource {
        let count = visiblePackages.count
        if count == 0 {
            return LocalizedStringResource(
                "Nothing found for “\(normalizedQuery)”",
                bundle: #bundle,
                comment: "Discover subhead, no search results",
            )
        }
        if count == 1 {
            return LocalizedStringResource(
                "1 package matches “\(normalizedQuery)”",
                bundle: #bundle,
                comment: "Discover subhead, single search result",
            )
        }
        return LocalizedStringResource(
            "\(count) packages match “\(normalizedQuery)”",
            bundle: #bundle,
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

    var formulaeSectionTitle: LocalizedStringResource {
        isSearching
            ? LocalizedStringResource("Formulae", bundle: #bundle, comment: "Discover formulae section header while searching")
            : LocalizedStringResource("Popular Formulae", bundle: #bundle, comment: "Discover trending formulae section header")
    }

    var casksSectionTitle: LocalizedStringResource {
        isSearching
            ? LocalizedStringResource("Casks", bundle: #bundle, comment: "Discover casks section header while searching")
            : LocalizedStringResource("Popular Casks", bundle: #bundle, comment: "Discover trending casks section header")
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
                localized: "Something went wrong searching the catalog.",
                bundle: #bundle,
                comment: "Discover tab generic search failure",
            )
        }
        return String(
            localized: "Something went wrong loading Discover packages.",
            bundle: #bundle,
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
