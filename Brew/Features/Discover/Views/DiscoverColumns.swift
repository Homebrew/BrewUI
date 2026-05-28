import Foundation
import SwiftUI

/// Entry-point wrapper for the Discover tab content.
struct DiscoverColumnsRoot: View {
    @Environment(\.catalogueCache) private var catalogueCache
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository

    var body: some View {
        let apiClient = URLSessionBrewAPIClient.live()
        let catalogueRepository = BrewCatalogueRepository(
            apiClient: apiClient,
            cache: catalogueCache,
        )
        let discoverPackagesRepository = BrewDiscoverPackagesRepository(
            apiClient: apiClient,
            catalogueRepository: catalogueRepository,
        )
        DiscoverColumns(
            discoverPackagesRepository: discoverPackagesRepository,
            catalogueRepository: catalogueRepository,
            installedRepository: installedPackagesRepository,
        )
    }
}

struct DiscoverColumns: View {
    @State private var viewModel: DiscoverViewModel

    init(
        discoverPackagesRepository: any DiscoverPackagesRepository,
        catalogueRepository: any CatalogueRepository,
        installedRepository: any InstalledPackageStatusReading,
    ) {
        _viewModel = State(
            initialValue: DiscoverViewModel(
                discoverPackagesRepository: discoverPackagesRepository,
                catalogueRepository: catalogueRepository,
                installedRepository: installedRepository,
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
                if let selectedPackage = viewModel.selectedPackage {
                    DiscoverPackageDetailRoot(selectedPackage: selectedPackage)
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
        installedRepository: AppPreviewSupport.makeInstalledPackagesRepository(),
    )
}
