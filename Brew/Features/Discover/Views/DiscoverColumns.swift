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
        HSplitView {
            DiscoverPackagesView(viewModel: viewModel)
                .frame(
                    minWidth: BrewLayout.installedListColumnMinWidth,
                    idealWidth: BrewLayout.installedListColumnIdealWidth,
                    maxWidth: BrewLayout.installedListColumnMaxWidth,
                    maxHeight: .infinity,
                    alignment: .topLeading,
                )

            Group {
                if let detailViewModel = viewModel.detailViewModel {
                    DiscoverPackageDetailView(viewModel: detailViewModel)
                } else {
                    DiscoverPackageDetailPlaceholder()
                }
            }
            .frame(
                minWidth: BrewLayout.inspectorWidth,
                idealWidth: BrewLayout.installedDetailColumnIdealWidth,
                maxWidth: BrewLayout.installedDetailColumnMaxWidth,
                maxHeight: .infinity,
                alignment: .topLeading,
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    DiscoverColumns(
        discoverPackagesRepository: AppPreviewSupport.makeDiscoverPackagesRepository(),
        catalogueRepository: AppPreviewSupport.makeDiscoverCatalogueRepository(),
        installedInventoryReading: AppPreviewSupport.makeInstalledInventoryReading(),
    )
}
