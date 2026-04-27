import SwiftUI

/// Feature-owned content/detail columns for the main window shell.
struct InstalledColumns {
    @Bindable var viewModel: InstalledViewModel

    /// Right-side feature surface in the app shell.
    /// Uses a two-pane internal split only when a row is selected.
    var featureView: some View {
        Group {
            if let detailsViewModel = viewModel.detailsViewModel {
                HSplitView {
                    InstalledShellView(viewModel: viewModel)
                        .frame(
                            minWidth: BrewLayout.installedListColumnMinWidth,
                            idealWidth: BrewLayout.installedListColumnIdealWidth,
                            maxWidth: BrewLayout.installedListColumnMaxWidth,
                            maxHeight: .infinity,
                            alignment: .topLeading,
                        )

                    InstalledPackageDetailView(viewModel: detailsViewModel)
                        .frame(
                            minWidth: BrewLayout.inspectorWidth,
                            idealWidth: BrewLayout.installedDetailColumnIdealWidth,
                            maxWidth: BrewLayout.installedDetailColumnMaxWidth,
                            maxHeight: .infinity,
                            alignment: .topLeading,
                        )
                }
            } else {
                InstalledShellView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
