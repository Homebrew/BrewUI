@testable import Brew
import Foundation
import Testing

struct DiscoverViewModelTests {
    @Test @MainActor func `load enriches top packages from catalogue and installed inventory`() async throws {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [DiscoverTopPackage(reference: .formula(name: "git"), installCount: 100)],
                    topCasks: [DiscoverTopPackage(reference: .cask(token: "iterm2"), installCount: 90)],
                ),
            ),
            catalogueRepository: StubCatalogueRepository(
                formulaCatalogue: [
                    .fixture(
                        name: "git",
                        description: "Distributed revision control",
                        homepage: "https://git-scm.com",
                        latestVersion: "2.46.1",
                    ),
                ],
                caskCatalogue: [
                    .fixture(
                        name: "iterm2",
                        kind: .cask,
                        description: "Terminal emulator",
                        homepage: "https://iterm2.com",
                        latestVersion: "3.5.0",
                    ),
                ],
            ),
            installedInventoryReading: StubInstalledInventoryReading(
                installedIDs: ["formula:git"],
                packages: [.fixture(name: "git", installedVersions: ["2.45.0"])],
            ),
        )

        await viewModel.load()

        guard case .loaded = viewModel.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(viewModel.visibleRows.count == 2)
        #expect(viewModel.selectedRow?.id == "formula:git")

        let git = try #require(viewModel.visibleRows.first { $0.id == "formula:git" })
        #expect(git.descriptionText == "Distributed revision control")
        #expect(git.stableVersionLabel == "2.46.1")
        #expect(git.isInstalled)
        #expect(git.installedVersionLabel == "v2.45.0")
    }

    @Test @MainActor func `load falls back when catalogue fetch fails`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [DiscoverTopPackage(reference: .formula(name: "wget"), installCount: 55)],
                    topCasks: [],
                ),
            ),
            catalogueRepository: ThrowingCatalogueRepository(),
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
        )

        await viewModel.load()

        guard case .loaded = viewModel.state else {
            Issue.record("expected loaded state")
            return
        }
        guard let wget = viewModel.visibleRows.first else {
            Issue.record("expected one visible row")
            return
        }
        #expect(wget.descriptionText.isEmpty)
        #expect(wget.stableVersionLabel == "—")
        #expect(wget.analyticsInstallCount == 55)
        #expect(!wget.isInstalled)
    }

    @Test @MainActor func `segment filtering keeps selection scoped to visible rows`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [DiscoverTopPackage(reference: .formula(name: "git"), installCount: 100)],
                    topCasks: [DiscoverTopPackage(reference: .cask(token: "iterm2"), installCount: 90)],
                ),
            ),
            catalogueRepository: StubCatalogueRepository.empty,
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
        )

        await viewModel.load()
        #expect(viewModel.selectedRow?.id == "formula:git")

        viewModel.selectedSegment = .cask

        #expect(viewModel.visibleRows.count == 1)
        #expect(viewModel.selectedRow?.id == "cask:iterm2")
    }

    @Test @MainActor func `selected row maps into detail install command`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [],
                    topCasks: [DiscoverTopPackage(reference: .cask(token: "docker"), installCount: 88)],
                ),
            ),
            catalogueRepository: StubCatalogueRepository.empty,
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
        )

        await viewModel.load()
        viewModel.selectedSegment = .cask

        #expect(viewModel.detailViewModel?.installCommand == "brew install --cask docker")
    }

    @Test @MainActor func `load maps discover repository transport errors to underlying message`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: ThrowingDiscoverPackagesRepository(
                error: BrewAPIClientError.transport(underlying: "offline"),
            ),
            catalogueRepository: StubCatalogueRepository.empty,
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
        )

        await viewModel.load()

        guard case let .error(message) = viewModel.state else {
            Issue.record("expected error state")
            return
        }
        #expect(message == "offline")
    }

    @Test @MainActor func `load maps unknown discover repository errors to generic message`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: ThrowingDiscoverPackagesRepository(error: DiscoverOddError()),
            catalogueRepository: StubCatalogueRepository.empty,
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
        )

        await viewModel.load()

        guard case let .error(message) = viewModel.state else {
            Issue.record("expected error state")
            return
        }
        #expect(message == "Something went wrong loading Discover packages.")
    }

    @Test @MainActor func `setSelection ignores invalid package ids`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [DiscoverTopPackage(reference: .formula(name: "git"), installCount: 100)],
                    topCasks: [DiscoverTopPackage(reference: .cask(token: "iterm2"), installCount: 90)],
                ),
            ),
            catalogueRepository: StubCatalogueRepository.empty,
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
        )

        await viewModel.load()
        #expect(viewModel.selectedRow?.id == "formula:git")

        viewModel.setSelection("formula:missing")

        #expect(viewModel.selectedRow?.id == "formula:git")
    }
}

@MainActor
private struct StubDiscoverPackagesRepository: DiscoverPackagesRepository {
    let snapshot: DiscoverTopPackagesSnapshot

    func loadTopPackages(
        limit _: Int,
        window _: BrewAnalyticsWindow,
    ) async throws -> DiscoverTopPackagesSnapshot {
        snapshot
    }
}

@MainActor
private struct ThrowingDiscoverPackagesRepository: DiscoverPackagesRepository {
    let error: Error

    func loadTopPackages(
        limit _: Int,
        window _: BrewAnalyticsWindow,
    ) async throws -> DiscoverTopPackagesSnapshot {
        throw error
    }
}

@MainActor
private struct StubCatalogueRepository: CatalogueRepository {
    static let empty = StubCatalogueRepository(formulaCatalogue: [], caskCatalogue: [])

    let formulaCatalogue: [BrewPackage]
    let caskCatalogue: [BrewPackage]

    func loadFormulaCatalogue(forceRefresh _: Bool) async throws -> [BrewPackage] {
        formulaCatalogue
    }

    func loadCaskCatalogue(forceRefresh _: Bool) async throws -> [BrewPackage] {
        caskCatalogue
    }
}

@MainActor
private struct ThrowingCatalogueRepository: CatalogueRepository {
    func loadFormulaCatalogue(forceRefresh _: Bool) async throws -> [BrewPackage] {
        throw BrewAPIClientError.transport(underlying: "offline")
    }

    func loadCaskCatalogue(forceRefresh _: Bool) async throws -> [BrewPackage] {
        throw BrewAPIClientError.transport(underlying: "offline")
    }
}

private struct DiscoverOddError: Error {}
