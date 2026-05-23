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
            installedInventoryReading: StubInstalledInventoryReading(
                installedIDs: [.formula(name: "git")],
                packages: [.fixture(name: "git", installedVersions: ["2.45.0"])],
            ),
        )

        await viewModel.load()

        guard case .loaded = viewModel.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(viewModel.visibleRows.count == 2)
        #expect(viewModel.selectedRow?.id == .formula(name: "git"))

        let git = try #require(viewModel.visibleRows.first { $0.id == .formula(name: "git") })
        #expect(git.descriptionText == "Distributed revision control")
        #expect(git.stableVersionLabel == "2.46.1")
        #expect(git.installedStatusLabel == "Installed")
        #expect(git.installedVersionLabel == "v2.45.0")
    }

    @Test @MainActor func `load maps discover repository transport errors to underlying message`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: ThrowingDiscoverPackagesRepository(
                error: BrewAPIClientError.transport(underlying: "offline"),
            ),
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
                    topFormulae: [discoveryPackage(name: "git", thirtyDayInstallCount: 100)],
                    topCasks: [discoveryPackage(name: "iterm2", kind: .cask, thirtyDayInstallCount: 90)],
                ),
            ),
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
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
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
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
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
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
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
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
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
        )

        await viewModel.load()

        #expect(viewModel.visibleRows.map(\.name) == ["git", "node", "wget"])
    }

    @Test @MainActor func `formulaRows and caskRows partition loaded rows by kind`() async {
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
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
        )

        await viewModel.load()

        #expect(viewModel.formulaRows.map(\.id) == [.formula(name: "git"), .formula(name: "node")])
        #expect(viewModel.caskRows.map(\.id) == [.cask(token: "docker")])
    }

    @Test @MainActor func `formulaRows and caskRows are empty before load`() {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(topFormulae: [], topCasks: []),
            ),
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
        )

        #expect(viewModel.formulaRows.isEmpty)
        #expect(viewModel.caskRows.isEmpty)
    }

    @Test @MainActor func `subtitle reflects loading state`() {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(topFormulae: [], topCasks: []),
            ),
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
        )

        // VM starts in .loading before load() is called
        #expect(viewModel.subtitleText == "Loading packages…")
        #expect(!viewModel.showsSubtitleTrendIcon)
        #expect(!viewModel.isSubtitleError)
    }

    @Test @MainActor func `subtitle reflects loaded state`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(
                snapshot: DiscoverTopPackagesSnapshot(topFormulae: [], topCasks: []),
            ),
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
        )

        await viewModel.load()

        #expect(viewModel.subtitleText == "Top 10 formulae · Top 10 casks")
        #expect(viewModel.showsSubtitleTrendIcon)
        #expect(!viewModel.isSubtitleError)
    }

    @Test @MainActor func `subtitle reflects error state`() async {
        let viewModel = DiscoverViewModel(
            discoverPackagesRepository: ThrowingDiscoverPackagesRepository(error: DiscoverOddError()),
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
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
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: []),
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

private struct DiscoverOddError: Error {}

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
