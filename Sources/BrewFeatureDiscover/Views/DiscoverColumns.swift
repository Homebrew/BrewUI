import BrewCore
import BrewDesignSystem
import BrewRepositories
import Foundation
import SwiftUI

/// Entry-point wrapper for the Discover tab content. Reads the discover/catalogue/installed
/// repositories from the environment (composed by the app's composition root).
public struct DiscoverColumnsRoot: View {
    @Environment(\.discoverPackagesRepository) private var discoverPackagesRepository
    @Environment(\.catalogueRepository) private var catalogueRepository
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository

    public init() {}

    public var body: some View {
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

#if DEBUG
    import BrewRepositoriesTestSupport

    #Preview {
        DiscoverColumns(
            discoverPackagesRepository: AppPreviewSupport.makeDiscoverPackagesRepository(),
            catalogueRepository: AppPreviewSupport.makeDiscoverCatalogueRepository(),
            installedRepository: AppPreviewSupport.makeInstalledPackagesRepository(),
        )
    }
#endif
