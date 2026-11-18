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
import BrewFeatureServices
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

struct MainWindowView: View {
    /// 主窗口正文的统一顶界开关，不随页面或滚动状态变化。
    private static let showsContentTopSeparator = true

    @Environment(\.selfUpgradeCoordinator) private var selfUpgradeCoordinator
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository
    @Environment(\.discoverPackagesRepository) private var discoverPackagesRepository
    @Environment(\.configRepository) private var configRepository
    @Environment(\.doctorRepository) private var doctorRepository
    @Environment(\.servicesRepository) private var servicesRepository
    @Environment(\.brewCommandCenter) private var brewCommandCenter
    @Environment(\.mutatingCommandFactory) private var mutatingCommandFactory

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
            .overlay(alignment: .top) {
                if Self.showsContentTopSeparator {
                    Divider()
                        // 独立底面阻止横竖线叠色；背景只占线条范围，不跨入工具栏。
                        .background(.background, ignoresSafeAreaEdges: [])
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .focusedSceneValue(\.consoleExpanded, $consoleExpanded)
        }
        .navigationSplitViewStyle(.automatic)
        // 关闭工具栏背景自带的自动边界，正文顶界只由上方的 Divider 绘制。
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .focusedSceneValue(\.consoleExpanded, $consoleExpanded)
        .focusedSceneValue(\.sidebarSelection, $selectedSidebarItem)
        .focusedSceneValue(\.refreshAll, RefreshAllAction { refreshAll() })
        .focusedSceneValue(
            \.saveBrewfile,
            SaveBrewfileAction(commandCenter: brewCommandCenter, commandFactory: mutatingCommandFactory),
        )
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
        Button(String(localized: "OK", bundle: #bundle, comment: "Self-upgrade outcome alert: dismiss")) { selfUpgradeCoordinator?.acknowledgeUpgradeCompletion() }
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
            guard !selectedSidebarItem.refreshesDoctorReport else {
                await doctorRepository.load(forceRefresh: true)
                return
            }
            await installedPackagesRepository.load(forceRefresh: true)
            await discoverPackagesRepository.load(forceRefresh: true)
            await configRepository.load(forceRefresh: true)
            await servicesRepository.load(forceRefresh: true)
        }
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
        // One combined case keeps the shared toolbar search field alive across the switch
        // (see `InstalledUpgradesRoot`).
        case .installed, .upgrades:
            InstalledUpgradesRoot(
                mode: selectedSidebarItem == .upgrades ? .upgrades : .installed,
                deepLinkSelection: $pendingInstalledSelection,
            )
            .navigationTitle(selectedSidebarItem.title)
        case .discover:
            DiscoverColumnsRoot()
                .navigationTitle(selectedSidebarItem.title)
        case .services:
            ServicesRoot()
                .navigationTitle(selectedSidebarItem.title)
        case .doctor:
            DoctorColumnsRoot()
                .navigationTitle(selectedSidebarItem.title)
        case .configuration:
            ConfigColumnsRoot()
                .navigationTitle(selectedSidebarItem.title)
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
            .environment(\.servicesRepository, PreviewSupport.makeServicesRepository())
    }
#endif
