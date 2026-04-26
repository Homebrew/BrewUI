import SwiftUI

struct MainWindowView: View {
    @Bindable var viewModel: MainWindowViewModel

    var body: some View {
        NavigationSplitView {
            ShellSidebarView(selection: $viewModel.selectedSidebarItem)
                .navigationSplitViewColumnWidth(
                    min: BrewLayout.sidebarWidth,
                    ideal: BrewLayout.sidebarWidth,
                    max: BrewLayout.sidebarWidth + 40,
                )
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .frame(
            minWidth: BrewLayout.minWindowWidth,
            minHeight: BrewLayout.minWindowHeight,
        )
        .background(.bar)
        .task(id: viewModel.selectedSidebarItem) {
            await viewModel.loadForCurrentSelection()
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch viewModel.selectedSidebarItem {
        case .installed:
            InstalledColumns(viewModel: viewModel.installedViewModel).contentColumn
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch viewModel.selectedSidebarItem {
        case .installed:
            InstalledColumns(viewModel: viewModel.installedViewModel).detailColumn
        }
    }
}

#Preview {
    MainWindowView(
        viewModel: MainWindowViewModel(
            installedViewModel: InstalledViewModel(
                previewFormulae: InstalledViewModelDummyData.formulae,
                previewCasks: InstalledViewModelDummyData.casks,
            ),
        ),
    )
}
