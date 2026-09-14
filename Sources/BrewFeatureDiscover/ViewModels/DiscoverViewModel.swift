/*
 * [INPUT]: 依赖 BrewCore 包身份、RepositoryInterfaces 状态与共享展示本地化
 * [OUTPUT]: 提供 DiscoverViewModel
 * [POS]: Discover 展示策略；语言解析不参与仓库或安装任务生命周期
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
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

    func trending(localization: AppLocalization = AppLocalization(language: "en")) -> LoadState<[DiscoveryBrewPackage], String> {
        switch discoverPackagesRepository.state {
        case .loading:
            .loading
        case let .loaded(packages):
            .loaded(packages)
        case let .failed(error):
            .failed(Self.userMessage(for: error, searching: false).string(localization: localization))
        }
    }

    private var searchState: LoadState<[DiscoveryBrewPackage], AppMessage> = .loaded([])

    func results(localization: AppLocalization = AppLocalization(language: "en")) -> LoadState<[DiscoveryBrewPackage], String> {
        switch searchState {
        case .loading: .loading
        case let .loaded(packages): .loaded(packages)
        case let .failed(message): .failed(message.string(localization: localization))
        }
    }

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

    func activeState(localization: AppLocalization = AppLocalization(language: "en")) -> LoadState<[DiscoveryBrewPackage], String> {
        isSearching ? results(localization: localization) : trending(localization: localization)
    }

    /// Search results have no analytics, so install-count metadata is suppressed in that mode.
    var showsInstallMetrics: Bool {
        !isSearching
    }

    // MARK: - Heading

    func paneHeading(localization: AppLocalization = AppLocalization(language: "en")) -> String {
        guard isSearching else {
            return localization.string("Trending")
        }
        if case .loaded = searchState, visiblePackages.isEmpty {
            return localization.string("No matches")
        }
        return localization.string("Results")
    }

    func subtitleText(localization: AppLocalization = AppLocalization(language: "en")) -> String {
        switch activeState(localization: localization) {
        case .loading:
            return isSearching
                ? localization.string("Searching…")
                : localization.string("Loading packages…")
        case .failed:
            return isSearching
                ? localization.string("Could not search packages")
                : localization.string("Could not load packages")
        case .loaded:
            guard isSearching else {
                return localization.string("Most-installed packages in the last 30 days")
            }
            return searchResultsSubtitle(localization: localization)
        }
    }

    private func searchResultsSubtitle(localization: AppLocalization = AppLocalization(language: "en")) -> String {
        let count = visiblePackages.count
        if count == 0 {
            return localization.string("Nothing found for “\(normalizedQuery)”")
        }
        if count == 1 {
            return localization.string("1 package matches “\(normalizedQuery)”")
        }
        return localization.string("\(count) packages match “\(normalizedQuery)”")
    }

    var showsSubtitleTrendIcon: Bool {
        if case .loaded = activeState(), !isSearching {
            return true
        }
        return false
    }

    var isSubtitleError: Bool {
        if case .failed = activeState() {
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

    func formulaeSectionTitle(localization: AppLocalization = AppLocalization(language: "en")) -> String {
        isSearching
            ? localization.string("Formulae")
            : localization.string("Popular Formulae")
    }

    func casksSectionTitle(localization: AppLocalization = AppLocalization(language: "en")) -> String {
        isSearching
            ? localization.string("Casks")
            : localization.string("Popular Casks")
    }

    var visiblePackages: [DiscoveryBrewPackage] {
        guard case let .loaded(packages) = activeState() else {
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

    private static func userMessage(for error: Error, searching: Bool) -> AppMessage {
        if case let BrewAPIClientError.transport(underlying) = error {
            return .raw(underlying)
        }
        if searching {
            return .localized("Something went wrong searching the catalogue.")
        }
        return .localized("Something went wrong loading Discover packages.")
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
            searchState = .loaded([])
            synchronizeSelectionWithVisibleRows()
            return
        }
        searchState = .loading
        do {
            let matches = try await catalogueRepository.searchPackages(
                matching: normalizedQuery,
                limit: searchResultsLimit,
            )
            // Catalogue search has no analytics, so install counts are zero (hidden in this mode).
            searchState = .loaded(matches.map { DiscoveryBrewPackage(package: $0, thirtyDayInstallCount: 0) })
        } catch {
            searchState = .failed(Self.userMessage(for: error, searching: true))
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
