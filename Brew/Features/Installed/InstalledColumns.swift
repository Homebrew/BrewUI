import SwiftUI

/// Feature-owned content/detail columns for the main window.
struct InstalledColumns: View {
    @Bindable var viewModel: InstalledViewModel

    var body: some View {
        Group {
            if let selectedPackage = viewModel.selectedPackage {
                HSplitView {
                    InstalledPackagesView(viewModel: viewModel)
                        .frame(
                            minWidth: BrewLayout.installedListColumnMinWidth,
                            idealWidth: BrewLayout.installedListColumnIdealWidth,
                            maxWidth: BrewLayout.installedListColumnMaxWidth,
                            maxHeight: .infinity,
                            alignment: .topLeading,
                        )

                    InstalledPackageDetailRoot(
                        selectedPackage: selectedPackage,
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
