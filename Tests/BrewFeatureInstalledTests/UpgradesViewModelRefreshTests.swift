//
//  UpgradesViewModelRefreshTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import Foundation
import Observation
import Testing

struct UpgradesViewModelRefreshTests {
    @Test @MainActor func `refresh forces a fetch and reports progress while it runs`() async {
        let repository = GatedInstalledPackagesRepository(packages: [
            .fixture(name: "git", kind: .formula, outdated: true),
        ])
        let viewModel = Self.makeViewModel(repository: repository)

        #expect(!viewModel.isRefreshing)

        let refresh = Task { await viewModel.refresh() }
        await waitUntil { repository.didStartLoad }
        #expect(viewModel.isRefreshing)

        repository.resumeLoad()
        await refresh.value

        #expect(!viewModel.isRefreshing)
        #expect(repository.forceRefreshCalls == [true])
    }

    @Test @MainActor func `refresh is available whether or not upgrades exist`() async {
        // The header's Refresh affordance is not conditional on the outdated count, so both an empty
        // and a populated inventory must be refreshable.
        for packages in [[], [InstalledBrewPackage.fixture(name: "git", kind: .formula, outdated: true)]] {
            let repository = GatedInstalledPackagesRepository(packages: packages)
            repository.resumeLoad()
            let viewModel = Self.makeViewModel(repository: repository)

            await viewModel.refresh()

            #expect(repository.forceRefreshCalls == [true])
            #expect(!viewModel.isRefreshing)
        }
    }

    @Test @MainActor func `load leaves the refresh indicator alone`() async {
        // The initial `.task` load paints its own skeleton; only an explicit refresh drives the button.
        let repository = GatedInstalledPackagesRepository(packages: [])
        repository.resumeLoad()
        let viewModel = Self.makeViewModel(repository: repository)

        await viewModel.load()

        #expect(!viewModel.isRefreshing)
        #expect(repository.forceRefreshCalls == [false])
    }

    // MARK: - Helpers

    @MainActor
    private static func makeViewModel(
        repository: GatedInstalledPackagesRepository,
    ) -> UpgradesViewModel {
        UpgradesViewModel(
            repository: repository,
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )
    }
}

/// Loaded-state inventory whose `load` parks until released, so a test can observe the view model
/// mid-refresh rather than only before and after.
@Observable
@MainActor
private final class GatedInstalledPackagesRepository: InstalledPackagesRepository {
    private(set) var state: LoadState<[InstalledBrewPackage], any Error>
    private(set) var refreshFailure: (any Error)?
    private(set) var forceRefreshCalls: [Bool] = []
    private(set) var didStartLoad = false
    private var isGated = true

    private var lookup: [HomebrewPackageID: InstalledBrewPackage]

    init(packages: [InstalledBrewPackage]) {
        state = .loaded(packages)
        lookup = Dictionary(packages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func resumeLoad() {
        isGated = false
    }

    func load(forceRefresh: Bool) async {
        forceRefreshCalls.append(forceRefresh)
        didStartLoad = true
        while isGated {
            await Task.yield()
        }
    }

    func isInstalled(_ id: HomebrewPackageID) -> Bool {
        lookup[id] != nil
    }

    func info(for id: HomebrewPackageID) -> InstalledBrewPackage? {
        lookup[id]
    }

    func installedPackageIDs() async -> Set<InstalledBrewPackage.ID> {
        Set(lookup.keys)
    }
}

/// Yields cooperatively until `condition` holds, with a bounded budget so a regression fails an
/// assertion instead of hanging the suite.
@MainActor
private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0 ..< 500 {
        if condition() {
            return
        }
        await Task.yield()
    }
}
