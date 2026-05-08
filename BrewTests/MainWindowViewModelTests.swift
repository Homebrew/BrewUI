//
//  MainWindowViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Testing

struct MainWindowViewModelTests {
    @Test @MainActor func `loadForCurrentSelection triggers installed load`() async {
        let countingRepository = CountingInstalledRepository()
        let installed = InstalledViewModel(
            repository: countingRepository,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        let vm = MainWindowViewModel(
            installedViewModel: installed,
        )
        await vm.loadForCurrentSelection()
        let callCount = await countingRepository.loadCallCount
        #expect(callCount == 1)
    }

    @Test @MainActor func `main window defaults to installed sidebar selection`() {
        let installed = InstalledViewModel(
            repository: StubInstalledPackagesRepository(snapshot: .empty),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        let vm = MainWindowViewModel(
            installedViewModel: installed,
        )
        #expect(vm.selectedSidebarItem == .installed)
    }
}

private actor CountingInstalledRepository: InstalledPackagesRepository {
    private(set) var loadCallCount: Int = 0

    func loadInstalledPackages() async throws -> [BrewPackage] {
        loadCallCount += 1
        return []
    }
}
