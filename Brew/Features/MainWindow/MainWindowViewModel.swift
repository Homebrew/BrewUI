import CoreGraphics
import Observation

@Observable
@MainActor
final class MainWindowViewModel {
    var selectedSidebarItem: SidebarItem
    var installedViewModel: InstalledViewModel
    let installedDetailsRepository: any PackageDetailsRepository

    init(
        selectedSidebarItem: SidebarItem = .installed,
        installedViewModel: InstalledViewModel,
        installedDetailsRepository: any PackageDetailsRepository,
    ) {
        self.selectedSidebarItem = selectedSidebarItem
        self.installedViewModel = installedViewModel
        self.installedDetailsRepository = installedDetailsRepository
    }

    func loadForCurrentSelection() async {
        switch selectedSidebarItem {
        case .installed:
            await installedViewModel.load()
        }
    }
}
