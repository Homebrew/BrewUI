import AppKit
import BrewAppEnvironment
import BrewCore
import BrewFeatureConfig
import BrewFeatureConsole
import BrewFeatureDiscover
import BrewFeatureDoctor
import BrewFeatureInstalled
import BrewUIComponents
import SwiftUI

struct MainWindowView: View {
    @State var selectedSidebarItem: SidebarItem = .installed
    @State private var pendingInstalledSelection: InstalledBrewPackage.ID?
    @SceneStorage("consoleExpanded") private var consoleExpanded: Bool = false
    @SceneStorage("consoleHeight") private var consoleHeight: Double = BrewLayout.consoleDefaultExpandedHeight

    var body: some View {
        AnimatedSplit(
            collapsed: !consoleExpanded,
            collapsedHeight: BrewLayout.consoleCollapsedHeight,
            expandedHeight: consoleHeight,
            minExpandedHeight: BrewLayout.consoleMinExpandedHeight,
            maxExpandedHeight: BrewLayout.consoleMaxExpandedHeight,
            animation: .brewFast,
        ) {
            NavigationSplitView {
                sidebarColumn
            } detail: {
                featureColumn
            }
            .background(.bar)
            .navigationSplitViewStyle(.prominentDetail)
        } bottom: {
            ConsolePanelRoot(expanded: $consoleExpanded)
        }
        .focusedSceneValue(\.consoleExpanded, $consoleExpanded)
        .environment(\.navigateToInstalledPackage) { id in
            pendingInstalledSelection = id
            selectedSidebarItem = .installed
        }
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
            InstalledColumnsRoot(deepLinkSelection: $pendingInstalledSelection)
                .navigationTitle("Installed")
                .navigationSubtitle("Browse or search your installed packages")
        case .upgrades:
            UpgradesColumnsRoot()
                .navigationTitle("Upgrades")
                .navigationSubtitle("Review and upgrade outdated packages")
        case .discover:
            DiscoverColumnsRoot()
                .navigationTitle("Discover")
                .navigationSubtitle("Browse and search \(Self.approximateCatalogueSize) packages")
        case .doctor:
            DoctorColumnsRoot()
                .navigationTitle("Doctor")
                .navigationSubtitle("Check your Homebrew installation for problems")
        case .configuration:
            ConfigColumnsRoot()
                .navigationTitle("Configuration")
                .navigationSubtitle("Homebrew environment & diagnostics")
        }
    }
}

#if DEBUG
    import BrewRepositoryInterfaces

    #Preview {
        MainWindowView()
            .environment(\.brewCommandCenter, PreviewSupport.commandCenter)
            .environment(\.installedPackagesRepository, PreviewSupport.makeInstalledPackagesRepository())
            .environment(\.discoverPackagesRepository, PreviewSupport.makeDiscoverPackagesRepository())
            .environment(\.catalogueRepository, PreviewSupport.makeDiscoverCatalogueRepository())
            .environment(\.installedDependentsRepository, PreviewSupport.makeInstalledDependentsRepository())
            .environment(\.doctorRepository, PreviewSupport.makeDoctorRepository())
            .environment(\.configRepository, PreviewSupport.makeConfigRepository())
            .environment(\.envFileRepository, PreviewSupport.makeEnvFileRepository())
    }
#endif
