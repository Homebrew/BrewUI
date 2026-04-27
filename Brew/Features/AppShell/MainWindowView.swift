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
            minWidth: viewModel.minimumWindowWidth,
            minHeight: BrewLayout.minWindowHeight,
        )
        .background(.bar)
        .onAppear {
            ensureWindowMeetsMinimumWidth()
        }
        .onChange(of: viewModel.shouldShowInstalledDetailColumn) { _, _ in
            ensureWindowMeetsMinimumWidth()
        }
        .task(id: viewModel.selectedSidebarItem) {
            await viewModel.loadForCurrentSelection()
        }
    }

    private func ensureWindowMeetsMinimumWidth() {
        let requiredWidth = viewModel.minimumWindowWidth
        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first else {
            return
        }
        let frame = window.frame
        guard frame.width < requiredWidth else {
            return
        }

        var expandedFrame = frame
        expandedFrame.size.width = requiredWidth
        window.setFrame(expandedFrame, display: true, animate: true)
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
                previewFormulae: InstalledViewModelDummyData.formulae,
                previewCasks: InstalledViewModelDummyData.casks,
            ),
        ),
    )
}
