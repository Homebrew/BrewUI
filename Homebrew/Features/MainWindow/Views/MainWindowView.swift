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
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @SceneStorage("consoleExpanded") private var consoleExpanded: Bool = false
    @SceneStorage("consoleHeight") private var consoleHeight: Double = BrewLayout.consoleDefaultExpandedHeight

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        withAnimation(.brewSpring) {
                            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                        }
                    } label: {
                        Image(systemName: "sidebar.leading")
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .navigationSplitViewStyle(.automatic)
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

    /// Approximate catalogue size for the Discover subtitle. Hardcoded for now; should eventually be
    /// sourced from the catalogue once a package-count property is exposed.
    fileprivate static let approximateCatalogueSize = 9000

    private var sidebarColumn: some View {
        MainSidebarView(selection: $selectedSidebarItem)
            .navigationSplitViewColumnWidth(
                min: BrewLayout.sidebarWidth,
                ideal: BrewLayout.sidebarWidth,
                max: BrewLayout.sidebarWidth + 40,
            )
            .toolbar(removing: .sidebarToggle)
    }

    private var featureColumn: some View {
        FeatureColumnContent(
            selectedSidebarItem: $selectedSidebarItem,
            deepLinkSelection: $pendingInstalledSelection,
        )
    }
}

private struct FeatureColumnContent: View {
    @Binding var selectedSidebarItem: SidebarItem
    @Binding var deepLinkSelection: InstalledBrewPackage.ID?
    @State private var searchQuery = ""
    @State private var isSearchFocused = false
    @State private var searchFocusRequest = 0

    var body: some View {
        Group {
            if supportsSearch {
                searchableContent
            } else {
                content
            }
        }
        .navigationTitle(selectedSidebarItem.title)
        .navigationSubtitle(selectedSidebarItem.subtitle)
    }

    private var searchableContent: some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ToolbarSearchField(
                        text: $searchQuery,
                        isFocused: $isSearchFocused,
                        prompt: searchPrompt,
                        focusRequest: searchFocusRequest,
                    )
                    .frame(width: 320)
                }
            }
            .focusedSceneValue(\.focusSearchField, FocusSearchFieldAction {
                searchFocusRequest += 1
            })
            .onChange(of: selectedSidebarItem) { _, _ in
                let shouldRestoreFocus = isSearchFocused
                searchQuery = ""
                guard shouldRestoreFocus else {
                    return
                }
                Task { @MainActor in
                    await Task.yield()
                    searchFocusRequest += 1
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSidebarItem {
        // One combined case keeps the shared toolbar search field alive across switches
        // (see `InstalledUpgradesRoot`).
        case .installed, .upgrades:
            InstalledUpgradesRoot(
                mode: selectedSidebarItem == .upgrades ? .upgrades : .installed,
                deepLinkSelection: $deepLinkSelection,
                searchQuery: $searchQuery,
            )
        case .discover:
            DiscoverColumnsRoot(searchQuery: $searchQuery)
        case .services:
            ServicesRoot()
        case .doctor:
            DoctorColumnsRoot()
        case .configuration:
            ConfigColumnsRoot()
        }
    }

    private var searchPrompt: String {
        switch selectedSidebarItem {
        case .installed:
            InstalledUpgradesRoot.searchPrompt(for: .installed)
        case .upgrades:
            InstalledUpgradesRoot.searchPrompt(for: .upgrades)
        case .discover:
            DiscoverColumnsRoot.searchPrompt
        case .services, .doctor, .configuration:
            ""
        }
    }

    private var supportsSearch: Bool {
        switch selectedSidebarItem {
        case .installed, .upgrades, .discover: true
        case .services, .doctor, .configuration: false
        }
    }
}

private extension SidebarItem {
    var subtitle: String {
        switch self {
        case .installed:
            String(localized: "Browse or search your installed packages", bundle: #bundle, comment: "Window subtitle, Installed")
        case .upgrades:
            String(localized: "Review and upgrade outdated packages", bundle: #bundle, comment: "Window subtitle, Upgrades")
        case .discover:
            String(
                localized: "Browse and search \(MainWindowView.approximateCatalogueSize)+ packages",
                bundle: #bundle,
                comment: "Window subtitle, Discover; %lld is the approximate catalog size",
            )
        case .services:
            String(localized: "View your Homebrew services", bundle: #bundle, comment: "Window subtitle, read-only Services tab")
        case .doctor:
            String(localized: "Check your Homebrew installation for problems", bundle: #bundle, comment: "Window subtitle, Doctor")
        case .configuration:
            String(localized: "Homebrew environment & diagnostics", bundle: #bundle, comment: "Window subtitle, Configuration")
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
