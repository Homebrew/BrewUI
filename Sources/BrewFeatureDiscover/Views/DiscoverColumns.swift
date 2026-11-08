import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import SwiftUI

/// Entry-point wrapper for the Discover tab content. Reads the discover/catalogue/installed
/// repositories from the environment (composed by the app's composition root).
public struct DiscoverColumnsRoot: View {
    @Environment(\.discoverPackagesRepository) private var discoverPackagesRepository
    @Environment(\.catalogueRepository) private var catalogueRepository
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository
    @Environment(\.aiEngine) private var aiEngine

    public init() {}

    public var body: some View {
        DiscoverColumns(
            discoverPackagesRepository: discoverPackagesRepository,
            catalogueRepository: catalogueRepository,
            installedRepository: installedPackagesRepository,
            aiEngine: aiEngine,
        )
    }
}

struct DiscoverColumns: View {
    @State private var viewModel: DiscoverViewModel

    init(
        discoverPackagesRepository: any DiscoverPackagesRepository,
        catalogueRepository: any CatalogueRepository,
        installedRepository: any InstalledPackageStatusReading,
        aiEngine: any AIEngineProtocol = PreviewSupport.aiEngine,
    ) {
        _viewModel = State(
            initialValue: DiscoverViewModel(
                discoverPackagesRepository: discoverPackagesRepository,
                catalogueRepository: catalogueRepository,
                installedRepository: installedRepository,
                installedInventory: installedRepository as? any InstalledInventoryObserving,
                aiEngine: aiEngine,
            ),
        )
    }

    var body: some View {
        HSplitView {
            DiscoverPackagesView(viewModel: viewModel)
                .frame(
                    minWidth: BrewLayout.installedListColumnMinWidth,
                    idealWidth: BrewLayout.installedListColumnIdealWidth,
                    maxWidth: .infinity,
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
                maxWidth: .infinity,
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

    #Preview {
        DiscoverColumns(
            discoverPackagesRepository: PreviewSupport.makeDiscoverPackagesRepository(),
            catalogueRepository: PreviewSupport.makeDiscoverCatalogueRepository(),
            installedRepository: PreviewSupport.makeInstalledPackagesRepository(),
        )
    }
#endif
