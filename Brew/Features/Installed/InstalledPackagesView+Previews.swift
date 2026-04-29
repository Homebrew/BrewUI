import SwiftUI

#Preview("List column") {
    let viewModel = InstalledViewModel(
        repository: PreviewInstalledPackagesRepository(),
        detailsRepository: PreviewPackageDetailsRepository(),
    )
    InstalledPackagesView(
        viewModel: viewModel,
    )
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
        ),
        repository: PreviewPackageDetailsRepository(),
    )
    InstalledPackageDetailView(
        viewModel: detailsViewModel,
    )
    .task {
        detailsViewModel.load()
    }
    .frame(minWidth: 280, minHeight: 200)
}
