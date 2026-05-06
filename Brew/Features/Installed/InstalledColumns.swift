import SwiftUI

/// Feature-owned content/detail columns for the main window.
struct InstalledColumns: View {
    @Bindable var viewModel: InstalledViewModel
    let detailsRepository: any PackageDetailsRepository
    @Environment(\.brewCommandCenter) private var brewCommandCenter
    @State private var detailsViewModel: InstalledDetailsViewModel?
    @State private var detailsSelectionRow: InstalledPackageRow?

    var body: some View {
        Group {
            if let detailsViewModel {
                HSplitView {
                    InstalledPackagesView(viewModel: viewModel)
                        .frame(
                            minWidth: BrewLayout.installedListColumnMinWidth,
                            idealWidth: BrewLayout.installedListColumnIdealWidth,
                            maxWidth: BrewLayout.installedListColumnMaxWidth,
                            maxHeight: .infinity,
                            alignment: .topLeading,
                        )

                    InstalledPackageDetailWiringView(viewModel: detailsViewModel)
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
        .task(id: viewModel.selectedPackageRow) {
            rebuildDetailsViewModelIfNeeded()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func rebuildDetailsViewModelIfNeeded() {
        guard let selectedRow = viewModel.selectedPackageRow else {
            detailsSelectionRow = nil
            detailsViewModel = nil
            return
        }
        guard detailsSelectionRow != selectedRow else {
            return
        }
        guard let brewCommandCenter else {
            detailsSelectionRow = nil
            detailsViewModel = nil
            return
        }

        let nextDetailsViewModel = InstalledDetailsViewModel(
            selectedRow: selectedRow,
            repository: detailsRepository,
            brewCommandCenter: brewCommandCenter,
            onUpgradeSuccess: { [viewModel] in
                await viewModel.refreshInstalledPackagesPreservingUI()
            },
        )
        detailsSelectionRow = selectedRow
        detailsViewModel = nextDetailsViewModel
        nextDetailsViewModel.load()
    }
}
