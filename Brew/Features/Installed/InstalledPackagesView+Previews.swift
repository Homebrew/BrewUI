import SwiftUI

#Preview("List column") {
    let viewModel = InstalledViewModel(
        repository: PreviewInstalledPackagesRepository(),
        detailsRepository: PreviewPackageDetailsRepository(),
        upgradeRunner: PreviewPackageUpgradeRunner(),
    )
    InstalledPackagesView(
        viewModel: viewModel,
    )
    .environment(\.brewCommandCenter, NoopBrewCommandCenter.preview())
    .task {
        await viewModel.load()
    }
    .frame(minWidth: 360, minHeight: 500)
}

#Preview("Detail") {
    let detailsViewModel = InstalledDetailsViewModel(
        selectedRow: InstalledPackageRow(
            name: "git",
            kind: .formula,
            description: "Distributed revision control system",
            installedVersion: "v2.45.0",
            updateVersion: "v2.46.1",
        ),
        repository: PreviewPackageDetailsRepository(),
        upgradeRunner: PreviewPackageUpgradeRunner(),
    )
    InstalledPackageDetailView(
        viewModel: detailsViewModel,
    )
    .environment(\.brewCommandCenter, NoopBrewCommandCenter.preview())
    .task {
        detailsViewModel.load()
    }
    .frame(minWidth: 280, minHeight: 200)
}
