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

    public init() {
        _searchQuery = .constant("")
    }

    @Binding private var searchQuery: String
    private var isSearchFocused = false

    /// `isSearchFocused` reports whether the window's toolbar search field holds the keyboard.
    public init(searchQuery: Binding<String>, isSearchFocused: Bool = false) {
        _searchQuery = searchQuery
        self.isSearchFocused = isSearchFocused
    }

    public static var searchPrompt: String {
        String(localized: "Search Homebrew’s Packages", bundle: #bundle, comment: "Search field placeholder, Discover tab")
    }

    public var body: some View {
        DiscoverColumns(
            discoverPackagesRepository: discoverPackagesRepository,
            catalogueRepository: catalogueRepository,
            installedRepository: installedPackagesRepository,
            searchQuery: $searchQuery,
            isSearchFocused: isSearchFocused,
        )
    }
}

struct DiscoverColumns: View {
    @State private var viewModel: DiscoverViewModel
    @Binding private var searchQuery: String
    private let isSearchFocused: Bool

    init(
        discoverPackagesRepository: any DiscoverPackagesRepository,
        catalogueRepository: any CatalogueRepository,
        installedRepository: any InstalledPackageStatusReading,
        searchQuery: Binding<String> = .constant(""),
        isSearchFocused: Bool = false,
    ) {
        _viewModel = State(
            initialValue: DiscoverViewModel(
                discoverPackagesRepository: discoverPackagesRepository,
                catalogueRepository: catalogueRepository,
                installedRepository: installedRepository,
            ),
        )
        _searchQuery = searchQuery
        self.isSearchFocused = isSearchFocused
    }

    var body: some View {
        HSplitView {
            DiscoverPackagesView(viewModel: viewModel, searchQuery: $searchQuery, isSearchFocused: isSearchFocused)
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
