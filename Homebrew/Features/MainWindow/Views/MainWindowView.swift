import AppKit
import BrewAccessibilityID
import BrewAppEnvironment
import BrewCore
import BrewFeatureConfig
import BrewFeatureConsole
import BrewFeatureDiscover
import BrewFeatureDoctor
import BrewFeatureInstalled
import BrewFeatureSelfUpgrade
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

struct MainWindowView: View {
    @Environment(\.selfUpgradeCoordinator) private var selfUpgradeCoordinator
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository
    @Environment(\.discoverPackagesRepository) private var discoverPackagesRepository
    @Environment(\.configRepository) private var configRepository
    @Environment(\.doctorRepository) private var doctorRepository

    @State var selectedSidebarItem: SidebarItem = .installed
    @State private var pendingInstalledSelection: InstalledBrewPackage.ID?
    @SceneStorage("consoleExpanded") private var consoleExpanded: Bool = false
    @SceneStorage("consoleHeight") private var consoleHeight: Double = BrewLayout.consoleDefaultExpandedHeight

    var body: some View {
        NavigationSplitView {
            sidebarColumn
        } detail: {
            AnimatedSplit(
                collapsed: !consoleExpanded,
                collapsedHeight: BrewLayout.consoleCollapsedHeight,
                expandedHeight: consoleHeight,
                minExpandedHeight: BrewLayout.consoleMinExpandedHeight,
                maxExpandedHeight: BrewLayout.consoleMaxExpandedHeight,
                minTopHeight: BrewLayout.mainPaneMinHeight,
                animation: .brewFast,
            ) {
                featureColumn
            } bottom: {
                ConsolePanelRoot(expanded: $consoleExpanded)
            }
            .focusedSceneValue(\.consoleExpanded, $consoleExpanded)
        }
        .navigationSplitViewStyle(.automatic)
        .focusedSceneValue(\.consoleExpanded, $consoleExpanded)
        .focusedSceneValue(\.sidebarSelection, $selectedSidebarItem)
        .focusedSceneValue(\.refreshAll, RefreshAllAction { refreshAll() })
        .environment(\.navigateToInstalledPackage) { id in
            pendingInstalledSelection = id
            selectedSidebarItem = .installed
        }
        .environment(\.packageListBanner, PackageListBanner { SelfUpgradeBanner() })
        .alert(
            Text(outcomeCopy.title),
            isPresented: launchOutcomeBinding,
            presenting: launchOutcome,
        ) { _ in
            acknowledgeButton
        } message: { outcome in
            Text(SelfUpgradeOutcomePresentation(outcome: outcome).message)
        }
    }

    private var acknowledgeButton: some View {
        Button("OK") { selfUpgradeCoordinator?.acknowledgeUpgradeCompletion() }
            .axid(.selfUpgradeOutcomeAcknowledgeButton)
    }

    private var launchOutcome: SelfUpgradeOutcome? {
        selfUpgradeCoordinator?.lastLaunchOutcome
    }

    /// Read outside `presenting:`, so it still needs a value while the alert dismisses; that copy is unseen.
    private var outcomeCopy: SelfUpgradeOutcomePresentation {
        SelfUpgradeOutcomePresentation(outcome: launchOutcome ?? .succeeded)
    }

    private var launchOutcomeBinding: Binding<Bool> {
        Binding(
            get: { selfUpgradeCoordinator?.lastLaunchOutcome != nil },
            set: { presented in
                if !presented {
                    selfUpgradeCoordinator?.acknowledgeUpgradeCompletion()
                }
            },
        )
    }

    /// ⌘R refetches every cached surface except the Doctor report, whichever tab is showing, since the
    /// sidebar counts and the other tabs go stale just as readily as the visible one. Re-running
    /// `brew doctor` is a full diagnostic run rather than a refetch, so it only happens from Doctor.
    private func refreshAll() {
        Task {
            async let doctor: Void = refreshDoctorReportIfSelected()
            await installedPackagesRepository.load(forceRefresh: true)
            await discoverPackagesRepository.load(forceRefresh: true)
            await configRepository.load(forceRefresh: true)
            await doctor
        }
    }

    private func refreshDoctorReportIfSelected() async {
        guard selectedSidebarItem.refreshesDoctorReport else { return }
        await doctorRepository.load(forceRefresh: true)
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
        // One combined case keeps the shared toolbar search field alive across the switch
        // (see `InstalledUpgradesRoot`).
        case .installed, .upgrades:
            InstalledUpgradesRoot(
                mode: selectedSidebarItem == .upgrades ? .upgrades : .installed,
                deepLinkSelection: $pendingInstalledSelection,
            )
            .navigationTitle(selectedSidebarItem == .upgrades ? "Upgrades" : "Installed")
            .navigationSubtitle(
                selectedSidebarItem == .upgrades
                    ? "Review and upgrade outdated packages"
                    : "Browse or search your installed packages",
            )
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
    #Preview {
        MainWindowView()
            .environment(\.brewCommandCenter, PreviewSupport.commandCenter)
            .environment(\.installedPackagesRepository, PreviewSupport.makeInstalledPackagesRepository())
            .environment(\.discoverPackagesRepository, PreviewSupport.makeDiscoverPackagesRepository())
            .environment(\.catalogueRepository, PreviewSupport.makeDiscoverCatalogueRepository())
            .environment(\.installedDependentsRepository, PreviewSupport.makeInstalledDependentsRepository())
            .environment(\.doctorRepository, PreviewSupport.makeDoctorRepository())
            .environment(\.configRepository, PreviewSupport.makeConfigRepository())
    }
#endif
