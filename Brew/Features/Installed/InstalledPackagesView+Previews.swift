import SwiftUI

#Preview("List column") {
    let commandCenter = NoopBrewCommandCenter.preview()
    let viewModel = InstalledViewModel(
        repository: PreviewInstalledPackagesRepository(),
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
        selectedPackage: BrewPackage(
            name: "git",
            kind: .formula,
            description: nil,
            homepage: nil,
            latestVersion: "2.46.1",
            installedVersions: ["2.45.0"],
            dependencies: [],
            outdated: true,
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
