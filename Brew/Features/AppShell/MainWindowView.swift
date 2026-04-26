import SwiftUI

struct MainWindowView: View {
    @Bindable var viewModel: MainWindowViewModel

    var body: some View {
        Group {
            if viewModel.shouldShowInstalledDetailColumn {
                NavigationSplitView {
                    sidebarColumn
                } content: {
                    contentColumn
                } detail: {
                    detailColumn
                }
            } else {
                NavigationSplitView {
                    sidebarColumn
                } detail: {
                    contentColumn
                }
            }
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

    private var sidebarColumn: some View {
        ShellSidebarView(selection: $viewModel.selectedSidebarItem)
            .navigationSplitViewColumnWidth(
                min: BrewLayout.sidebarWidth,
                ideal: BrewLayout.sidebarWidth,
                max: BrewLayout.sidebarWidth + 40,
            )
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
