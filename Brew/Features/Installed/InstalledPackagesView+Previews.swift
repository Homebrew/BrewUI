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
        selection: PackageSelection(name: "git", kind: .formula),
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
