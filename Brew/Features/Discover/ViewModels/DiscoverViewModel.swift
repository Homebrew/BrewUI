import Foundation
import Observation

enum DiscoverFilterSegment: String, CaseIterable, Identifiable {
    case all
    case formula
    case cask

    var id: String {
        rawValue
    }
}

enum DiscoverLoadState: Equatable {
    case loading
    case loaded
    case error(String)
}

@Observable
@MainActor
final class DiscoverViewModel {
    private let discoverPackagesRepository: any DiscoverPackagesRepository
    private let installedInventoryReading: any InstalledInventoryReading
    private let topPackagesLimit: Int
    private let analyticsWindow: BrewAnalyticsWindow

    private var rows: [DiscoverListRowViewModel] = []

    private(set) var state: DiscoverLoadState = .loading
    private(set) var selectedPackageID: BrewPackage.ID?
    private(set) var detailViewModel: DiscoverPackageDetailViewModel?
    var selectedSegment: DiscoverFilterSegment = .all {
        didSet {
            guard selectedSegment != oldValue else {
                return
            }
            synchronizeSelectionWithLoadedRows()
            refreshDetailViewModel()
        }
    }

    init(
        discoverPackagesRepository: any DiscoverPackagesRepository,
        installedInventoryReading: any InstalledInventoryReading,
        topPackagesLimit: Int = 10,
        analyticsWindow: BrewAnalyticsWindow = .days30,
    ) {
        self.discoverPackagesRepository = discoverPackagesRepository
        self.installedInventoryReading = installedInventoryReading
        self.topPackagesLimit = topPackagesLimit
        self.analyticsWindow = analyticsWindow
    }

    var visibleRows: [DiscoverListRowViewModel] {
        guard case .loaded = state else {
            return []
        }
        switch selectedSegment {
        case .all:
            return rows
        case .formula:
            return rows.filter { $0.packageKind == .formula }
        case .cask:
            return rows.filter { $0.packageKind == .cask }
        }
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
            let installedPackages = await installedInventoryReading.installedPackages()

            rows = Self.makeRows(
                from: topPackages.topFormulae + topPackages.topCasks,
                installedPackages: installedPackages,
            )
            state = .loaded
            synchronizeSelectionWithLoadedRows()
            refreshDetailViewModel()
        } catch {
            state = .error(Self.userMessage(for: error))
            rows = []
            selectedPackageID = nil
            detailViewModel = nil
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
        refreshDetailViewModel()
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

    private func refreshDetailViewModel() {
        guard let selectedRow else {
            detailViewModel = nil
            return
        }
        if let detailViewModel {
            detailViewModel.update(row: selectedRow)
        } else {
            detailViewModel = DiscoverPackageDetailViewModel(row: selectedRow)
        }
    }

    private static func makeRows(
        from discoveryPackages: [DiscoveryPackage],
        installedPackages: [InstalledBrewPackage],
    ) -> [DiscoverListRowViewModel] {
        let installedByID = Dictionary(uniqueKeysWithValues: installedPackages.map { ($0.id, $0) })

        return discoveryPackages
            .map { discoveryPackage in
                DiscoverListRowViewModel(
                    discoveryPackage: discoveryPackage,
                    installedPackage: installedByID[discoveryPackage.id],
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
