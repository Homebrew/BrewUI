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
        .frame(
            minWidth: minimumWindowWidth,
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
    private var featureColumn: some View {
        switch viewModel.selectedSidebarItem {
        case .installed:
            InstalledColumns(viewModel: viewModel.installedViewModel).featureView
        }
    }

    private var minimumWindowWidth: CGFloat {
        if viewModel.shouldShowInstalledDetailColumn {
            let threePaneFloor = BrewLayout.sidebarWidth + BrewLayout.installedListColumnMinWidth + BrewLayout.inspectorWidth
            return max(threePaneFloor, BrewLayout.installedThreePaneMinWindowWidth)
        }
        return BrewLayout.sidebarWidth + BrewLayout.installedListColumnMinWidth
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
