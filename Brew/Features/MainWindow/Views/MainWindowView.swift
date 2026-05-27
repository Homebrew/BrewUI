import AppKit
import SwiftUI

struct MainWindowView: View {
    @State var selectedSidebarItem: SidebarItem = .installed
    @SceneStorage("consoleExpanded") private var consoleExpanded: Bool = false
    @SceneStorage("consoleHeight") private var consoleHeight: Double = BrewLayout.consoleDefaultExpandedHeight

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                sidebarColumn
            } detail: {
                featureColumn
            }
            .background(.bar)

            Divider()

            ConsolePanelRoot(expanded: $consoleExpanded, height: $consoleHeight)
        }
        .focusedSceneValue(\.consoleExpanded, $consoleExpanded)
    }

    /// Approximate catalogue size for the Discover subtitle. Hardcoded for now; should eventually be
    /// sourced from the catalogue once a package-count property is exposed.
    private static let approximateCatalogueSize = "9,000+"

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
                .navigationTitle("Installed")
                .navigationSubtitle("Browse or search your installed packages")
        case .discover:
            DiscoverColumnsRoot()
                .navigationTitle("Discover")
                .navigationSubtitle("Browse and search \(Self.approximateCatalogueSize) packages")
        }
    }
}

#Preview {
    MainWindowView()
        .environment(\.brewCommandCenter, AppPreviewSupport.commandCenter)
        .environment(\.installedInventoryCache, AppPreviewSupport.installedInventoryCache)
        .environment(\.installedPackagesRepository, AppPreviewSupport.makeInstalledPackagesRepository())
}
