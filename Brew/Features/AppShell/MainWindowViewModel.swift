import CoreGraphics
import Observation

@Observable
@MainActor
final class MainWindowViewModel {
    var selectedSidebarItem: SidebarItem
    var installedViewModel: InstalledViewModel

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
