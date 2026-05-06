import SwiftUI

#Preview("List column") {
    let commandCenter = NoopBrewCommandCenter.preview()
    let viewModel = InstalledViewModel(
        repository: PreviewInstalledPackagesRepository(),
        detailsRepository: PreviewPackageDetailsRepository(),
    )
    InstalledPackagesView(
        viewModel: viewModel,
    )
    .environment(\.brewCommandCenter, commandCenter)
    .task {
        await viewModel.load()
    }
    .frame(minWidth: 360, minHeight: 500)
}

#Preview("Detail") {
    let commandCenter = NoopBrewCommandCenter.preview()
    let detailsViewModel = InstalledDetailsViewModel(
        selectedRow: InstalledPackageRow(
            name: "git",
            kind: .formula,
            description: "Distributed revision control system",
            installedVersion: "v2.45.0",
            updateVersion: "v2.46.1",
        ),
        repository: PreviewPackageDetailsRepository(),
        brewCommandCenter: commandCenter,
    )
    InstalledPackageDetailView(
        viewModel: detailsViewModel,
    )
    .environment(\.brewCommandCenter, commandCenter)
    .task {
        detailsViewModel.load()
    }
    .frame(minWidth: 280, minHeight: 200)
}
