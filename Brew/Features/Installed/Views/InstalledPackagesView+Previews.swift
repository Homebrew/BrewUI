import SwiftUI

#Preview("List column") {
    let commandCenter = NoopBrewCommandCenter.preview()
    let inventoryCache = InstalledInventoryCache()
    let viewModel = InstalledViewModel(
        repository: BrewInstalledPackagesRepository.live(cache: inventoryCache),
        brewCommandCenter: commandCenter,
    )
    InstalledPackagesView(
        viewModel: viewModel,
    )
    .environment(\.brewCommandCenter, commandCenter)
    .environment(\.installedInventoryCache, inventoryCache)
    .task {
        await viewModel.load()
    }
    .frame(minWidth: 360, minHeight: 500)
}

#Preview("Detail") {
    let commandCenter = NoopBrewCommandCenter.preview()
    let inventoryCache = InstalledInventoryCache()
    let package = BrewPackage(
        name: "git",
        kind: .formula,
        description: "",
        homepage: "",
        latestVersion: "2.46.1",
        installedVersions: ["2.45.0"],
        dependencies: [],
        outdated: true,
    )
    InstalledPackageDetailView(
        package: package,
        brewCommandCenter: commandCenter,
        installedDependentsRepository: BrewInstalledDependentsRepository(cache: inventoryCache),
        installedInventoryReading: BrewInstalledPackagesRepository.live(cache: inventoryCache),
    )
    .frame(minWidth: 280, minHeight: 200)
}
