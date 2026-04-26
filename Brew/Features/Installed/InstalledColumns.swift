import SwiftUI

/// Feature-owned content/detail columns for the main window shell.
struct InstalledColumns {
    @Bindable var viewModel: InstalledViewModel

    var contentColumn: some View {
        InstalledShellView(viewModel: viewModel)
            .navigationSplitViewColumnWidth(
                min: BrewLayout.installedListColumnMinWidth,
                ideal: BrewLayout.installedListColumnIdealWidth,
                max: BrewLayout.installedListColumnMaxWidth,
            )
    }

    var detailColumn: some View {
        Group {
            if let row = viewModel.selectedPackageRow {
                InstalledPackageDetailView(row: row)
            } else {
                InstalledPackageDetailPlaceholder()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationSplitViewColumnWidth(
            min: BrewLayout.inspectorWidth,
            ideal: BrewLayout.installedDetailColumnIdealWidth,
            max: BrewLayout.installedDetailColumnMaxWidth,
        )
    }
}
