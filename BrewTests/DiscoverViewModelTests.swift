@testable import Brew
import Foundation
import Testing

struct DiscoverViewModelTests {
    @Test @MainActor func `load maps enriched discovery packages and installed inventory`() async throws {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [
                        discoveryPackage(
                            name: "git",
                            description: "Distributed revision control",
                            homepage: "https://git-scm.com",
                            latestVersion: "2.46.1",
                            thirtyDayInstallCount: 100,
                        ),
                    ],
                    topCasks: [
                        discoveryPackage(
                            name: "iterm2",
                            kind: .cask,
                            description: "Terminal emulator",
                            homepage: "https://iterm2.com",
                            latestVersion: "3.5.0",
                            thirtyDayInstallCount: 90,
                        ),
                    ],
                ),
            ),
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo([.fixture(name: "git", installedVersions: ["2.45.0"])]),
        )

        await viewModel.load()

        guard case .loaded = viewModel.trending else {
            Issue.record("expected loaded trending state")
            return
        }
        #expect(viewModel.visiblePackages.count == 2)
        #expect(viewModel.selectedRow?.id == .formula(name: "git"))

        let git = try #require(viewModel.selectedRow)
        #expect(git.descriptionText == "Distributed revision control")
        #expect(git.stableVersionLabel == "2.46.1")
        #expect(git.installedStatusLabel == "Installed")
        #expect(git.installedVersionLabel == "v2.45.0")
        #expect(git.showsInstallMetrics)
    }

    @Test @MainActor func `load maps discover repository transport errors to underlying message`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: ThrowingDiscoverPackagesRepository(
                error: BrewAPIClientError.transport(underlying: "offline"),
            ),
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        await viewModel.load()

        guard case let .failed(message) = viewModel.trending else {
            Issue.record("expected failed trending state")
            return
        }
        #expect(message == "offline")
    }

    @Test @MainActor func `load maps unknown discover repository errors to generic message`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: ThrowingDiscoverPackagesRepository(error: DiscoverOddError()),
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        await viewModel.load()

        guard case let .failed(message) = viewModel.trending else {
            Issue.record("expected failed trending state")
            return
        }
        #expect(message == "Something went wrong loading Discover packages.")
    }

    @Test @MainActor func `setSelection ignores invalid package ids`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [discoveryPackage(name: "git", thirtyDayInstallCount: 100)],
                    topCasks: [discoveryPackage(name: "iterm2", kind: .cask, thirtyDayInstallCount: 90)],
                ),
            ),
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        await viewModel.load()
        #expect(viewModel.selectedRow?.id == .formula(name: "git"))

        viewModel.setSelection(.formula(name: "missing"))

        #expect(viewModel.selectedRow?.id == .formula(name: "git"))
    }

    @Test @MainActor func `load selects first visible row by popularity`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [discoveryPackage(name: "git", thirtyDayInstallCount: 100)],
                    topCasks: [discoveryPackage(name: "iterm2", kind: .cask, thirtyDayInstallCount: 90)],
                ),
            ),
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        await viewModel.load()

        #expect(viewModel.selectedRow?.id == .formula(name: "git"))
    }

    @Test @MainActor func `setSelection nil resolves to first visible row`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [
                        discoveryPackage(name: "git", thirtyDayInstallCount: 100),
                        discoveryPackage(name: "node", thirtyDayInstallCount: 80),
                    ],
                    topCasks: [],
                ),
            ),
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        await viewModel.load()
        viewModel.setSelection(.formula(name: "node"))
        #expect(viewModel.selectedRow?.id == .formula(name: "node"))

        viewModel.setSelection(nil)

        #expect(viewModel.selectedRow?.id == .formula(name: "git"))
    }

    @Test @MainActor func `reload preserves selection when package still exists`() async {
        let repository = MutableDiscoverPackagesRepository(
            snapshot: DiscoverTopPackagesSnapshot(
                topFormulae: [
                    discoveryPackage(name: "git", thirtyDayInstallCount: 100),
                    discoveryPackage(name: "node", thirtyDayInstallCount: 80),
                ],
                topCasks: [],
            ),
        )
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: repository,
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        await viewModel.load()
        viewModel.setSelection(.formula(name: "node"))

        await viewModel.load()

        #expect(viewModel.selectedRow?.id == .formula(name: "node"))
    }

    @Test @MainActor func `rows with equal install count are sorted alphabetically`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [
                        discoveryPackage(name: "wget", thirtyDayInstallCount: 50),
                        discoveryPackage(name: "git", thirtyDayInstallCount: 50),
                        discoveryPackage(name: "node", thirtyDayInstallCount: 50),
                    ],
                    topCasks: [],
                ),
            ),
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        await viewModel.load()

        #expect(viewModel.visiblePackages.map(\.name) == ["git", "node", "wget"])
    }

    @Test @MainActor func `visible packages partition by kind formulae first then casks`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [
                        discoveryPackage(name: "git", thirtyDayInstallCount: 100),
                        discoveryPackage(name: "node", thirtyDayInstallCount: 80),
                    ],
                    topCasks: [
                        discoveryPackage(name: "docker", kind: .cask, thirtyDayInstallCount: 70),
                    ],
                ),
            ),
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        await viewModel.load()

        #expect(viewModel.visiblePackages.map(\.id) == [
            .formula(name: "git"),
            .formula(name: "node"),
            .cask(token: "docker"),
        ])
    }

    @Test @MainActor func `visible packages are empty before load`() {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(topFormulae: [], topCasks: []),
            ),
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        #expect(viewModel.visiblePackages.isEmpty)
    }

    @Test @MainActor func `scope formulae hides casks and casks hides formulae`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [discoveryPackage(name: "git", thirtyDayInstallCount: 100)],
                    topCasks: [discoveryPackage(name: "docker", kind: .cask, thirtyDayInstallCount: 70)],
                ),
            ),
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        await viewModel.load()

        viewModel.scope = .formulae
        #expect(viewModel.visiblePackages.map(\.id) == [.formula(name: "git")])
        #expect(viewModel.selectedRow?.id == .formula(name: "git"))

        viewModel.scope = .casks
        #expect(viewModel.visiblePackages.map(\.id) == [.cask(token: "docker")])
        #expect(viewModel.selectedRow?.id == .cask(token: "docker"))
    }

    @Test @MainActor func `subtitle reflects loading state`() {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(topFormulae: [], topCasks: []),
            ),
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        // VM starts in .loading before load() is called
        #expect(viewModel.subtitleText == "Loading packages…")
        #expect(!viewModel.showsSubtitleTrendIcon)
        #expect(!viewModel.isSubtitleError)
    }

    @Test @MainActor func `subtitle reflects trending loaded state`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(topFormulae: [], topCasks: []),
            ),
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        await viewModel.load()

        #expect(viewModel.subtitleText == "Trending this month")
        #expect(viewModel.showsSubtitleTrendIcon)
        #expect(!viewModel.isSubtitleError)
    }

    @Test @MainActor func `subtitle reflects error state`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: ThrowingDiscoverPackagesRepository(error: DiscoverOddError()),
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        await viewModel.load()

        #expect(viewModel.subtitleText == "Could not load packages")
        #expect(!viewModel.showsSubtitleTrendIcon)
        #expect(viewModel.isSubtitleError)
    }

    @Test @MainActor func `reload repoints selection when selected package disappears`() async {
        let repository = MutableDiscoverPackagesRepository(
            snapshot: DiscoverTopPackagesSnapshot(
                topFormulae: [
                    discoveryPackage(name: "git", thirtyDayInstallCount: 100),
                    discoveryPackage(name: "node", thirtyDayInstallCount: 80),
                ],
                topCasks: [],
            ),
        )
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: repository,
            catalogueRepository: StubCatalogueRepository(),
            installedRepository: installedRepo(),
        )

        await viewModel.load()
        viewModel.setSelection(.formula(name: "node"))

        repository.snapshot = DiscoverTopPackagesSnapshot(
            topFormulae: [discoveryPackage(name: "git", thirtyDayInstallCount: 100)],
            topCasks: [],
        )
        await viewModel.load()

        #expect(viewModel.selectedRow?.id == .formula(name: "git"))
    }

    // MARK: - Search

    @Test @MainActor func `search populates results and switches into searching mode`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [discoveryPackage(name: "git", thirtyDayInstallCount: 100)],
                    topCasks: [],
                ),
            ),
            catalogueRepository: StubCatalogueRepository(
                searchResults: [
                    cataloguePackage(name: "ripgrep"),
                    cataloguePackage(name: "imagemagick"),
                ],
            ),
            installedRepository: installedRepo(),
        )

        await viewModel.load()
        viewModel.query = "rip"
        await viewModel.search()

        #expect(viewModel.isSearching)
        #expect(!viewModel.showsInstallMetrics)
        #expect(viewModel.visiblePackages.map(\.name) == ["imagemagick", "ripgrep"])
        #expect(viewModel.selectedRow?.showsInstallMetrics == false)
    }

    @Test @MainActor func `clearing the query returns to trending without searching`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(
                    topFormulae: [discoveryPackage(name: "git", thirtyDayInstallCount: 100)],
                    topCasks: [],
                ),
            ),
            catalogueRepository: StubCatalogueRepository(
                searchResults: [cataloguePackage(name: "ripgrep")],
            ),
            installedRepository: installedRepo(),
        )

        await viewModel.load()
        viewModel.query = "rip"
        await viewModel.search()
        #expect(viewModel.isSearching)

        viewModel.query = ""
        await viewModel.search()

        #expect(!viewModel.isSearching)
        #expect(viewModel.visiblePackages.map(\.id) == [.formula(name: "git")])
        #expect(viewModel.showsInstallMetrics)
    }

    @Test @MainActor func `search subtitle reflects result count`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(topFormulae: [], topCasks: []),
            ),
            catalogueRepository: StubCatalogueRepository(
                searchResults: [
                    cataloguePackage(name: "git"),
                    cataloguePackage(name: "gitup", kind: .cask),
                ],
            ),
            installedRepository: installedRepo(),
        )

        viewModel.query = "git"
        await viewModel.search()

        #expect(viewModel.subtitleText == "2 results for “git”")
        #expect(!viewModel.showsSubtitleTrendIcon)
    }

    @Test @MainActor func `search subtitle reports no matches`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(topFormulae: [], topCasks: []),
            ),
            catalogueRepository: StubCatalogueRepository(searchResults: []),
            installedRepository: installedRepo(),
        )

        viewModel.query = "zzz"
        await viewModel.search()

        #expect(viewModel.subtitleText == "No matches for “zzz”")
    }

    @Test @MainActor func `search maps transport errors to underlying message`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(topFormulae: [], topCasks: []),
            ),
            catalogueRepository: StubCatalogueRepository(
                searchError: BrewAPIClientError.transport(underlying: "offline"),
            ),
            installedRepository: installedRepo(),
        )

        viewModel.query = "git"
        await viewModel.search()

        guard case let .failed(message) = viewModel.results else {
            Issue.record("expected failed results state")
            return
        }
        #expect(message == "offline")
        #expect(viewModel.subtitleText == "Could not search packages")
        #expect(viewModel.isSubtitleError)
    }

    @Test @MainActor func `search maps unknown errors to generic search message`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(topFormulae: [], topCasks: []),
            ),
            catalogueRepository: StubCatalogueRepository(searchError: DiscoverOddError()),
            installedRepository: installedRepo(),
        )

        viewModel.query = "git"
        await viewModel.search()

        guard case let .failed(message) = viewModel.results else {
            Issue.record("expected failed results state")
            return
        }
        #expect(message == "Something went wrong searching the catalogue.")
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
private final class MutableDiscoverPackagesRepository: DiscoverPackagesRepository {
    var snapshot: DiscoverTopPackagesSnapshot

    init(snapshot: DiscoverTopPackagesSnapshot) {
        self.snapshot = snapshot
    }

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
    var searchResults: [BrewPackage] = []
    var searchError: Error?

    func package(for _: HomebrewPackageID) async throws -> BrewPackage? {
        nil
    }

    func searchPackages(matching _: String, limit _: Int) async throws -> [BrewPackage] {
        if let searchError {
            throw searchError
        }
        return searchResults
    }
}

private struct DiscoverOddError: Error {}

@MainActor
private func installedRepo(_ packages: [InstalledBrewPackage] = []) -> BrewInstalledPackagesRepository {
    BrewInstalledPackagesRepository.previewLoaded(packages)
}

private func discoveryPackage(
    name: String,
    kind: HomebrewPackageKind = .formula,
    description: String = "",
    homepage: String = "",
    latestVersion: String = "",
    thirtyDayInstallCount: Int,
) -> DiscoveryBrewPackage {
    DiscoveryBrewPackage(
        package: .fixture(
            name: name,
            kind: kind,
            description: description,
            homepage: homepage,
            latestVersion: latestVersion,
        ),
        thirtyDayInstallCount: thirtyDayInstallCount,
    )
}

private func cataloguePackage(
    name: String,
    kind: HomebrewPackageKind = .formula,
) -> BrewPackage {
    .fixture(name: name, kind: kind)
}
