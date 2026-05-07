import SwiftUI

/// Feature-owned content/detail columns for the main window.
struct InstalledColumns: View {
    @Bindable var viewModel: InstalledViewModel
    let detailsRepository: any PackageDetailsRepository

    var body: some View {
        Group {
            if let selectedRow = viewModel.selectedPackageRow {
                HSplitView {
                    // TODO: Completion here for when the selectedPackage changes
                    InstalledPackagesView(viewModel: viewModel)
                        .frame(
                            minWidth: BrewLayout.installedListColumnMinWidth,
                            idealWidth: BrewLayout.installedListColumnIdealWidth,
                            maxWidth: BrewLayout.installedListColumnMaxWidth,
                            maxHeight: .infinity,
                            alignment: .topLeading,
                        )

                    InstalledPackageDetailRoot(
                        selectedRow: selectedRow,
                        onUpgradeSuccess: { [viewModel] in
                            // TODO: This could just be an observation of upgrades by the list view
                            await viewModel.refreshInstalledPackagesPreservingUI()
                        },
                    )
                    .frame(
                        minWidth: BrewLayout.inspectorWidth,
                        idealWidth: BrewLayout.installedDetailColumnIdealWidth,
                        maxWidth: BrewLayout.installedDetailColumnMaxWidth,
                        maxHeight: .infinity,
                        alignment: .topLeading,
                    )
                }
            } else {
                InstalledPackagesView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
