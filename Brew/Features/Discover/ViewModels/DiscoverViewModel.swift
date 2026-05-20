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
    private let catalogueRepository: any CatalogueRepository
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
            synchronizeSelectionForVisibleRows()
            refreshDetailViewModel()
        }
    }

    init(
        discoverPackagesRepository: any DiscoverPackagesRepository,
        catalogueRepository: any CatalogueRepository,
        installedInventoryReading: any InstalledInventoryReading,
        topPackagesLimit: Int = 10,
        analyticsWindow: BrewAnalyticsWindow = .days30,
    ) {
        self.discoverPackagesRepository = discoverPackagesRepository
        self.catalogueRepository = catalogueRepository
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

            async let formulaCatalogueTask = catalogueRepository.loadFormulaCatalogue()
            async let caskCatalogueTask = catalogueRepository.loadCaskCatalogue()
            let installedPackages = await installedInventoryReading.installedPackages()
            let formulaCatalogueResult = try? await formulaCatalogueTask
            let caskCatalogueResult = try? await caskCatalogueTask
            let formulaCatalogue = formulaCatalogueResult ?? []
            let caskCatalogue = caskCatalogueResult ?? []

            rows = Self.makeRows(
                snapshot: topPackages,
                formulaCatalogue: formulaCatalogue,
                caskCatalogue: caskCatalogue,
                installedPackages: installedPackages,
            )
            state = .loaded
            synchronizeSelectionForVisibleRows()
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
            selectedPackageID = visibleRows.first?.id
        }
        refreshDetailViewModel()
    }

    private func synchronizeSelectionForVisibleRows() {
        let visibleIDs = Set(visibleRows.map(\.id))
        if let selectedPackageID, visibleIDs.contains(selectedPackageID) {
            return
        }
        selectedPackageID = visibleRows.first?.id
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
        snapshot: DiscoverTopPackagesSnapshot,
        formulaCatalogue: [BrewPackage],
        caskCatalogue: [BrewPackage],
        installedPackages: [InstalledBrewPackage],
    ) -> [DiscoverListRowViewModel] {
        let catalogueByID = Dictionary(
            uniqueKeysWithValues: (formulaCatalogue + caskCatalogue).map { ($0.id, $0) },
        )
        let installedByID = Dictionary(uniqueKeysWithValues: installedPackages.map { ($0.id, $0) })

        let topPackages = snapshot.topFormulae + snapshot.topCasks
        let rowViewModels = topPackages.map { topPackage in
            let packageID = topPackage.reference.packageID
            let package = catalogueByID[packageID] ?? topPackage.package
            return DiscoverListRowViewModel(
                package: package,
                analyticsInstallCount: topPackage.thirtyDayInstallCount,
                installedPackage: installedByID[packageID],
            )
        }
        return rowViewModels.sorted(by: sortRowsByPopularityThenName)
    }

    private static func sortRowsByPopularityThenName(
        _ lhs: DiscoverListRowViewModel,
        _ rhs: DiscoverListRowViewModel,
    ) -> Bool {
        if lhs.analyticsInstallCount == rhs.analyticsInstallCount {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return lhs.analyticsInstallCount > rhs.analyticsInstallCount
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
