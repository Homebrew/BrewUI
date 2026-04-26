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
