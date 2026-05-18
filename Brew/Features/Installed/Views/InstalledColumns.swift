import SwiftUI

struct InstalledColumnsRoot: View {
    @Environment(\.brewCommandCenter) private var brewCommandCenter
    @Environment(\.installedInventoryCache) private var installedInventoryCache

    var body: some View {
        let installedPackagesRepository = BrewInstalledPackagesRepository.live(cache: installedInventoryCache)
        InstalledColumns(
            installedPackagesRepository: installedPackagesRepository,
            brewCommandCenter: brewCommandCenter,
        )
    }
}

/// Feature-owned content/detail columns for the main window.
struct InstalledColumns: View {
    @State var viewModel: InstalledViewModel

    init(
        installedPackagesRepository: any InstalledPackagesRepository,
        brewCommandCenter: BrewCommandCenter,
    ) {
        _viewModel = State(
            initialValue: .init(
                repository: installedPackagesRepository,
                brewCommandCenter: brewCommandCenter,
            ),
        )
    }

    var body: some View {
        HSplitView {
            InstalledPackagesView(
                viewModel: viewModel,
            )
            .frame(
                minWidth: BrewLayout.installedListColumnMinWidth,
                idealWidth: BrewLayout.installedListColumnIdealWidth,
                maxWidth: BrewLayout.installedListColumnMaxWidth,
                maxHeight: .infinity,
                alignment: .topLeading,
            )

            Group {
                if let selectedPackage = viewModel.selectedPackage {
                    InstalledPackageDetailRoot(
                        selectedPackage: selectedPackage,
                        onSelectInstalledPackage: { viewModel.selectInstalledPackage(id: $0) },
                    )
                } else {
                    InstalledPackageDetailPlaceholder()
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
