import Foundation
import Observation

enum DiscoverLoadState: Equatable {
    case loading
    case loaded
    case error(String)
}

@Observable
@MainActor
final class DiscoverViewModel {
    @ObservationIgnored private let discoverPackagesRepository: any DiscoverPackagesRepository
    @ObservationIgnored private let installedRepository: any InstalledPackageStatusReading
    @ObservationIgnored private let topPackagesLimit: Int
    @ObservationIgnored private let analyticsWindow: BrewAnalyticsWindow

    private var rows: [DiscoverListRowViewModel] = []

    private(set) var state: DiscoverLoadState = .loading
    private(set) var selectedPackageID: BrewPackage.ID?

    init(
        discoverPackagesRepository: any DiscoverPackagesRepository,
        installedRepository: any InstalledPackageStatusReading,
        topPackagesLimit: Int = 10,
        analyticsWindow: BrewAnalyticsWindow = .days30,
    ) {
        self.discoverPackagesRepository = discoverPackagesRepository
        self.installedRepository = installedRepository
        self.topPackagesLimit = topPackagesLimit
        self.analyticsWindow = analyticsWindow
    }

    var subtitleText: String {
        switch state {
        case .loading:
            String(localized: "Loading packages…", comment: "Discover subtitle while loading")
        case .loaded:
            String(
                localized: "Top 10 formulae · Top 10 casks",
                comment: "Discover subtitle when loaded",
            )
        case .error:
            String(localized: "Could not load packages", comment: "Discover subtitle on error")
        }
    }

    var showsSubtitleTrendIcon: Bool {
        if case .loaded = state { return true }
        return false
    }

    var isSubtitleError: Bool {
        if case .error = state { return true }
        return false
    }

    var visibleRows: [DiscoverListRowViewModel] {
        guard case .loaded = state else {
            return []
        }
        return rows
    }

    var formulaRows: [DiscoverListRowViewModel] {
        visibleRows.filter { $0.packageKind == .formula }
    }

    var caskRows: [DiscoverListRowViewModel] {
        visibleRows.filter { $0.packageKind == .cask }
    }

    var selectedRow: DiscoverListRowViewModel? {
        guard let selectedPackageID else {
            return nil
        }
        return visibleRows.first { $0.id == selectedPackageID }
    }

    func load() async {
        state = .loading
        do {
            let topPackages = try await discoverPackagesRepository.loadTopPackages(
                limit: topPackagesLimit,
                window: analyticsWindow,
            )

            rows = Self.makeRows(
                from: topPackages.topFormulae + topPackages.topCasks,
                installedRepository: installedRepository,
            )
            state = .loaded
            synchronizeSelectionWithLoadedRows()
        } catch {
            state = .error(Self.userMessage(for: error))
            rows = []
            selectedPackageID = nil
        }
    }

    func setSelection(_ packageID: BrewPackage.ID?) {
        if let packageID {
            guard visibleRows.contains(where: { $0.id == packageID }) else {
                return
            }
            selectedPackageID = packageID
        } else {
            selectedPackageID = firstVisibleRowID()
        }
    }

    private func synchronizeSelectionWithLoadedRows() {
        let visibleIDs = Set(visibleRows.map(\.id))
        if let selectedPackageID, !visibleIDs.contains(selectedPackageID) {
            self.selectedPackageID = nil
        }
        if selectedPackageID == nil {
            selectedPackageID = firstVisibleRowID()
        }
    }

    private func firstVisibleRowID() -> BrewPackage.ID? {
        visibleRows.first?.id
    }

    private static func makeRows(
        from discoveryPackages: [DiscoveryBrewPackage],
        installedRepository: any InstalledPackageStatusReading,
    ) -> [DiscoverListRowViewModel] {
        discoveryPackages
            .map { discoveryPackage in
                DiscoverListRowViewModel(
                    discoveryPackage: discoveryPackage,
                    installedRepository: installedRepository,
                )
            }
            .sorted(by: sortRowsByPopularityThenName)
    }

    private static func sortRowsByPopularityThenName(
        _ lhs: DiscoverListRowViewModel,
        _ rhs: DiscoverListRowViewModel,
    ) -> Bool {
        if lhs.thirtyDayInstallCount == rhs.thirtyDayInstallCount {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return lhs.thirtyDayInstallCount > rhs.thirtyDayInstallCount
    }

    private static func userMessage(for error: Error) -> String {
        if case let BrewAPIClientError.transport(underlying) = error {
            return underlying
        }
        return String(
            localized: "Something went wrong loading Discover packages.",
            comment: "Discover tab generic load failure",
        )
    }
}
