import AppKit
import SwiftUI

struct MainWindowView: View {
    @Bindable var viewModel: MainWindowViewModel

    var body: some View {
        NavigationSplitView {
            sidebarColumn
        } detail: {
            featureColumn
        }
        .background(.bar)
        .task(id: viewModel.selectedSidebarItem) {
            await viewModel.loadForCurrentSelection()
        }
    }

    private var sidebarColumn: some View {
        ShellSidebarView(selection: $viewModel.selectedSidebarItem)
            .navigationSplitViewColumnWidth(
                min: BrewLayout.sidebarWidth,
                ideal: BrewLayout.sidebarWidth,
                max: BrewLayout.sidebarWidth + 40,
            )
    }

    @ViewBuilder
    private var featureColumn: some View {
        switch viewModel.selectedSidebarItem {
        case .installed:
            InstalledColumns(viewModel: viewModel.installedViewModel).featureView
        }
    }
}

#Preview {
    MainWindowView(
        viewModel: MainWindowViewModel(
            installedViewModel: InstalledViewModel(
                repository: PreviewInstalledPackagesRepository(),
                detailsRepository: PreviewPackageDetailsRepository(),
            ),
        ),
    )
}
