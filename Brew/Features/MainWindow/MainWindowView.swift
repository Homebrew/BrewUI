import AppKit
import SwiftUI

struct MainWindowView: View {
    @State var selectedSidebarItem: SidebarItem = .installed

    var body: some View {
        NavigationSplitView {
            sidebarColumn
        } detail: {
            featureColumn
        }
        .background(.bar)
    }

    private var sidebarColumn: some View {
        MainSidebarView(selection: $selectedSidebarItem)
            .navigationSplitViewColumnWidth(
                min: BrewLayout.sidebarWidth,
                ideal: BrewLayout.sidebarWidth,
                max: BrewLayout.sidebarWidth + 40,
            )
    }

    @ViewBuilder
    private var featureColumn: some View {
        switch selectedSidebarItem {
        case .installed:
            InstalledColumnsRoot()
        }
    }
}

#Preview {
    let commandCenter = NoopBrewCommandCenter.preview()
    MainWindowView()
    .environment(\.brewCommandCenter, commandCenter)
}
