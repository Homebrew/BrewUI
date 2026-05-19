import Foundation
import SwiftUI

/// Entry-point wrapper for the Discover tab content.
struct DiscoverColumnsRoot: View {
    @Environment(\.catalogueCache) private var catalogueCache
    @Environment(\.installedInventoryCache) private var installedInventoryCache

    var body: some View {
        let apiClient = URLSessionBrewAPIClient.live()
        let discoverPackagesRepository = BrewDiscoverPackagesRepository(apiClient: apiClient)
        let catalogueRepository = BrewCatalogueRepository(
            apiClient: apiClient,
            cache: catalogueCache,
        )
        let installedInventoryReading = BrewInstalledPackagesRepository.live(cache: installedInventoryCache)
        DiscoverColumns(
            discoverPackagesRepository: discoverPackagesRepository,
            catalogueRepository: catalogueRepository,
            installedInventoryReading: installedInventoryReading,
        )
    }
}

struct DiscoverColumns: View {
    @State private var viewModel: DiscoverViewModel

    init(
        discoverPackagesRepository: any DiscoverPackagesRepository,
        catalogueRepository: any CatalogueRepository,
        installedInventoryReading: any InstalledInventoryReading,
    ) {
        _viewModel = State(
            initialValue: DiscoverViewModel(
                discoverPackagesRepository: discoverPackagesRepository,
                catalogueRepository: catalogueRepository,
                installedInventoryReading: installedInventoryReading,
            ),
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            Text("Discover")
                .font(.brewLargeTitle)
                .foregroundStyle(Color.brewTextPrimary)
            switch viewModel.state {
            case .loading:
                Text("Loading packages…")
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextSecondary)
            case let .error(message):
                Text(message)
                    .font(.brewBody)
                    .foregroundStyle(Color.brewStatusError)
            case .loaded:
                Text("\(viewModel.visibleRows.count) packages")
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(BrewSpacing.xl)
        .background(Color.brewSurface)
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    DiscoverColumns(
        discoverPackagesRepository: PreviewDiscoverPackagesRepository(),
        catalogueRepository: PreviewCatalogueRepository(),
        installedInventoryReading: AppPreviewSupport.makeInstalledInventoryReading(),
    )
}

@MainActor
private struct PreviewDiscoverPackagesRepository: DiscoverPackagesRepository {
    func loadTopPackages(
        limit _: Int,
        window _: BrewAnalyticsWindow,
    ) async throws -> DiscoverTopPackagesSnapshot {
        DiscoverTopPackagesSnapshot(
            topFormulae: [
                DiscoverTopPackage(reference: .formula(name: "git"), installCount: 420_000),
                DiscoverTopPackage(reference: .formula(name: "node"), installCount: 360_000),
            ],
            topCasks: [
                DiscoverTopPackage(reference: .cask(token: "iterm2"), installCount: 180_000),
            ],
        )
    }
}

@MainActor
private struct PreviewCatalogueRepository: CatalogueRepository {
    func loadFormulaCatalogue(forceRefresh _: Bool) async throws -> [BrewPackage] {
        [
            BrewPackage(
                name: "git",
                displayName: "git",
                kind: .formula,
                description: "Distributed revision control system",
                homepage: "https://git-scm.com",
                latestVersion: "2.46.0",
                dependencies: [],
            ),
            BrewPackage(
                name: "node",
                displayName: "node",
                kind: .formula,
                description: "JavaScript runtime",
                homepage: "https://nodejs.org",
                latestVersion: "22.14.0",
                dependencies: [],
            ),
        ]
    }

    func loadCaskCatalogue(forceRefresh _: Bool) async throws -> [BrewPackage] {
        [
            BrewPackage(
                name: "iterm2",
                displayName: "iterm2",
                kind: .cask,
                description: "Terminal emulator",
                homepage: "https://iterm2.com",
                latestVersion: "3.5.0",
                dependencies: [],
            ),
        ]
    }
}
