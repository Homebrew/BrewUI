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
    @ObservationIgnored private let installedInventory: (any InstalledInventoryObserving)?
    @ObservationIgnored private let aiEngine: (any AIEngineProtocol)?
    @ObservationIgnored private let searchResultsLimit: Int

    var selectedCollection: DiscoverCuratedCollection = .trending {
        didSet {
            guard oldValue != selectedCollection else {
                return
            }
            synchronizeSelectionWithVisibleRows()
        }
    }

    private var collectionPackages: [DiscoverCuratedCollection: [DiscoveryBrewPackage]] = [:]
    private(set) var curatedState: LoadState<[DiscoveryBrewPackage], String> = .loaded([])
    private var activeSearchID = UUID()

    var isSemanticSearch: Bool = false {
        didSet {
            guard oldValue != isSemanticSearch else {
                return
            }
            synchronizeSelectionWithVisibleRows()
        }
    }

    var query: String = "" {
        didSet {
            guard oldValue != query else {
                return
            }
            activeSearchID = UUID()
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
        installedInventory: (any InstalledInventoryObserving)? = nil,
        aiEngine: (any AIEngineProtocol)? = nil,
        searchResultsLimit: Int = 50,
    ) {
        self.discoverPackagesRepository = discoverPackagesRepository
        self.catalogueRepository = catalogueRepository
        self.installedRepository = installedRepository
        self.installedInventory = installedInventory ?? (installedRepository as? any InstalledInventoryObserving)
        self.aiEngine = aiEngine
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
        if isSearching {
            return results
        }
        return selectedCollection == .trending ? trending : curatedState
    }

    /// Search results have no analytics, so install-count metadata is suppressed in that mode.
    var showsInstallMetrics: Bool {
        !isSearching && selectedCollection == .trending
    }

    // MARK: - Heading

    var paneHeading: LocalizedStringResource {
        guard isSearching else {
            return selectedCollection.title
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
                return curatedCollectionSubtitle
            }
            return searchResultsSubtitle
        }
    }

    private var curatedCollectionSubtitle: LocalizedStringResource {
        switch selectedCollection {
        case .trending:
            LocalizedStringResource("Most-installed packages in the last 30 days", bundle: #bundle, comment: "Discover subhead on trending landing")
        case .forYou:
            LocalizedStringResource("Personalised recommendations based on your installed tools", bundle: #bundle, comment: "Discover subhead on For You landing")
        case .cliTools:
            LocalizedStringResource("Essential high-performance command-line utilities", bundle: #bundle, comment: "Discover subhead on CLI tools landing")
        case .developer:
            LocalizedStringResource("Version control, editors, and modern developer tooling", bundle: #bundle, comment: "Discover subhead on developer tools landing")
        case .devops:
            LocalizedStringResource("Containers, Kubernetes, and cloud infrastructure", bundle: #bundle, comment: "Discover subhead on devops landing")
        case .security:
            LocalizedStringResource("Encryption, secret management, and network security", bundle: #bundle, comment: "Discover subhead on security landing")
        case .media:
            LocalizedStringResource("Audio, video, and image manipulation utilities", bundle: #bundle, comment: "Discover subhead on media landing")
        case .essentialCasks:
            LocalizedStringResource("Hand-picked GUI applications for macOS", bundle: #bundle, comment: "Discover subhead on essential casks landing")
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
            return isSemanticSearch
                ? LocalizedStringResource(
                    "1 AI semantic match for “\(normalizedQuery)”",
                    bundle: #bundle,
                    comment: "Discover subhead, single AI semantic result",
                )
                : LocalizedStringResource(
                    "1 package matches “\(normalizedQuery)”",
                    bundle: #bundle,
                    comment: "Discover subhead, single search result",
                )
        }
        return isSemanticSearch
            ? LocalizedStringResource(
                "\(count) AI semantic matches for “\(normalizedQuery)”",
                bundle: #bundle,
                comment: "Discover subhead, AI semantic result count",
            )
            : LocalizedStringResource(
                "\(count) packages match “\(normalizedQuery)”",
                bundle: #bundle,
                comment: "Discover subhead, search result count",
            )
    }

    var showsSubtitleTrendIcon: Bool {
        if case .loaded = activeState, !isSearching, selectedCollection == .trending {
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
        if forceRefresh {
            collectionPackages.removeAll()
        }
        await discoverPackagesRepository.load(forceRefresh: forceRefresh)
        if selectedCollection != .trending {
            await loadCollection(selectedCollection)
        }
        synchronizeSelectionWithVisibleRows()
    }

    func selectCollection(_ collection: DiscoverCuratedCollection) async {
        selectedCollection = collection
        if isSearching {
            query = ""
        }
        if collection == .trending {
            await load()
            return
        }
        if let cached = collectionPackages[collection] {
            curatedState = .loaded(cached)
            synchronizeSelectionWithVisibleRows()
            return
        }
        await loadCollection(collection)
    }

    func loadCollection(_ collection: DiscoverCuratedCollection) async {
        curatedState = .loading
        do {
            let pkgs = if collection == .forYou {
                try await loadForYouCollection()
            } else {
                try await loadCuratedCollection(collection)
            }
            guard selectedCollection == collection else { return }
            collectionPackages[collection] = pkgs
            curatedState = .loaded(pkgs)
        } catch {
            guard selectedCollection == collection else { return }
            curatedState = .failed(Self.userMessage(for: error, searching: false))
        }
        guard selectedCollection == collection else { return }
        synchronizeSelectionWithVisibleRows()
    }

    private func loadForYouCollection() async throws -> [DiscoveryBrewPackage] {
        guard let aiEngine else { return [] }
        let installed: [InstalledBrewPackage] = installedInventory?.state.value ?? []
        let installedNames = Set(installed.map(\.name))
        let recs = await aiEngine.recommendPackages(basedOn: installed)
        var pkgs: [DiscoveryBrewPackage] = []
        for rec in recs where !installedNames.contains(rec.packageName) {
            let ref = rec.isCask ? HomebrewPackageID.cask(token: rec.packageName) : HomebrewPackageID.formula(name: rec.packageName)
            if let found = try await catalogueRepository.package(for: ref) {
                pkgs.append(DiscoveryBrewPackage(package: found, thirtyDayInstallCount: 0))
            } else {
                let fallback = BrewPackage(
                    name: rec.packageName,
                    displayName: rec.packageName,
                    kind: rec.isCask ? .cask : .formula,
                    description: rec.reason,
                    homepage: "",
                    latestVersion: "",
                    dependencies: [],
                )
                pkgs.append(DiscoveryBrewPackage(package: fallback, thirtyDayInstallCount: 0))
            }
        }
        return pkgs
    }

    private func loadCuratedCollection(_ collection: DiscoverCuratedCollection) async throws -> [DiscoveryBrewPackage] {
        let names = collection.curatedPackageNames
        var pkgs: [DiscoveryBrewPackage] = []
        for name in names {
            let formulaRef = HomebrewPackageID.formula(name: name)
            let caskRef = HomebrewPackageID.cask(token: name)
            let foundFormula = try await catalogueRepository.package(for: formulaRef)
            let found: BrewPackage? = if let foundFormula {
                foundFormula
            } else {
                try await catalogueRepository.package(for: caskRef)
            }

            if let found {
                pkgs.append(DiscoveryBrewPackage(package: found, thirtyDayInstallCount: 0))
            } else {
                let fallback = BrewPackage(
                    name: name,
                    displayName: name,
                    kind: collection == .essentialCasks ? .cask : .formula,
                    description: "",
                    homepage: "",
                    latestVersion: "",
                    dependencies: [],
                )
                pkgs.append(DiscoveryBrewPackage(package: fallback, thirtyDayInstallCount: 0))
            }
        }
        return pkgs
    }

    func search() async {
        let currentSearchID = UUID()
        activeSearchID = currentSearchID
        let querySnapshot = normalizedQuery
        guard !querySnapshot.isEmpty else {
            results = .loaded([])
            synchronizeSelectionWithVisibleRows()
            return
        }
        results = .loading
        do {
            let limit = isSemanticSearch ? searchResultsLimit * 3 : searchResultsLimit
            let matches = try await catalogueRepository.searchPackages(
                matching: querySnapshot,
                limit: limit,
            )
            guard activeSearchID == currentSearchID else { return }

            if isSemanticSearch {
                let candidates = await gatherSemanticCandidates(query: querySnapshot, initialMatches: matches, limit: limit)
                guard activeSearchID == currentSearchID else { return }
                let searchPkgs = await executeSemanticSearch(query: querySnapshot, candidates: candidates, fallback: matches)
                guard activeSearchID == currentSearchID else { return }
                results = .loaded(searchPkgs)
            } else {
                results = .loaded(matches.map { DiscoveryBrewPackage(package: $0, thirtyDayInstallCount: 0) })
            }
        } catch {
            guard activeSearchID == currentSearchID else { return }
            results = .failed(Self.userMessage(for: error, searching: true))
        }
        guard activeSearchID == currentSearchID else { return }
        synchronizeSelectionWithVisibleRows()
    }

    private func gatherSemanticCandidates(query: String, initialMatches: [BrewPackage], limit: Int) async -> [BrewPackage] {
        var candidateSet = Set(initialMatches.map(\.id))
        var candidates = initialMatches

        let tokens = query
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
        for token in tokens.prefix(3) {
            if let tokenMatches = try? await catalogueRepository.searchPackages(matching: token, limit: limit) {
                for pkg in tokenMatches where !candidateSet.contains(pkg.id) {
                    candidateSet.insert(pkg.id)
                    candidates.append(pkg)
                }
            }
        }

        let trending = discoverPackagesRepository.state.value ?? []
        for p in trending where !candidateSet.contains(p.id) {
            candidateSet.insert(p.id)
            candidates.append(p.package)
        }

        return candidates
    }

    private func executeSemanticSearch(query: String, candidates: [BrewPackage], fallback: [BrewPackage]) async -> [DiscoveryBrewPackage] {
        guard let aiEngine else {
            return fallback.map { DiscoveryBrewPackage(package: $0, thirtyDayInstallCount: 0) }
        }
        let semanticResults = await aiEngine.semanticSearch(
            query: query,
            catalogue: candidates,
            limit: searchResultsLimit,
        )
        return semanticResults.map { DiscoveryBrewPackage(package: $0.package, thirtyDayInstallCount: 0) }
    }

    func reloadActive() async {
        collectionPackages.removeAll()
        if isSearching {
            await search()
        } else if selectedCollection == .trending {
            await load(forceRefresh: true)
        } else {
            await loadCollection(selectedCollection)
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
