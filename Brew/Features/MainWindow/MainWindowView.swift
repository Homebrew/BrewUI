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
        MainSidebarView(selection: $viewModel.selectedSidebarItem)
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
            InstalledColumns(
                viewModel: viewModel.installedViewModel,
            )
        }
    }
}

#Preview {
    let commandCenter = NoopBrewCommandCenter.preview()
    MainWindowView(
        viewModel: MainWindowViewModel(
            installedViewModel: InstalledViewModel(
                repository: PreviewInstalledPackagesRepository(),
                brewCommandCenter: commandCenter,
            ),
        ),
    )
    .environment(\.brewCommandCenter, commandCenter)
}
