import CoreGraphics
import Observation

@Observable
@MainActor
final class MainWindowViewModel {
    var selectedSidebarItem: SidebarItem
    var installedViewModel: InstalledViewModel

    var shouldShowInstalledDetailColumn: Bool {
        switch selectedSidebarItem {
        case .installed:
            installedViewModel.selectedPackageRow != nil
        }
    }

    var minimumWindowWidth: CGFloat {
        if shouldShowInstalledDetailColumn {
            let threePaneFloor = BrewLayout.sidebarWidth + BrewLayout.installedListColumnMinWidth + BrewLayout.inspectorWidth
            return max(threePaneFloor, BrewLayout.installedThreePaneMinWindowWidth)
        }
        return BrewLayout.sidebarWidth + BrewLayout.installedListColumnMinWidth
    }

    init(
        selectedSidebarItem: SidebarItem = .installed,
        installedViewModel: InstalledViewModel
    ) {
        self.selectedSidebarItem = selectedSidebarItem
        self.installedViewModel = installedViewModel
    }

    func loadForCurrentSelection() async {
        switch selectedSidebarItem {
        case .installed:
            await installedViewModel.load()
        }
    }
}
