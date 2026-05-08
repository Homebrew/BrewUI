import SwiftUI

struct InstalledColumnsRoot: View {
    @Environment(\.brewCommandCenter) var brewCommandCenter
    @State var repository: BrewInstalledPackagesRepository = .init(
        commandRunner: BrewCommandService(),
        locator: BrewExecutableLocator()
    )

    var body: some View {
        InstalledColumns(
            repository: repository,
            brewCommandCenter: brewCommandCenter
        )
    }
}

/// Feature-owned content/detail columns for the main window.
struct InstalledColumns: View {
    @State var viewModel: InstalledViewModel

    init(repository: InstalledPackagesRepository, brewCommandCenter: BrewCommandCenter) {
        _viewModel = State(
            initialValue: .init(
                repository: repository,
                brewCommandCenter: brewCommandCenter
            )
        )
    }

    var body: some View {
        Group {
            if let selectedPackage = viewModel.selectedPackage {
                HSplitView {
                    InstalledPackagesView(
                        viewModel: viewModel
                    )
                    .frame(
                        minWidth: BrewLayout.installedListColumnMinWidth,
                        idealWidth: BrewLayout.installedListColumnIdealWidth,
                        maxWidth: BrewLayout.installedListColumnMaxWidth,
                        maxHeight: .infinity,
                        alignment: .topLeading,
                    )

                    InstalledPackageDetailRoot(
                        selectedPackage: selectedPackage,
                    )
                    .frame(
                        minWidth: BrewLayout.inspectorWidth,
                        idealWidth: BrewLayout.installedDetailColumnIdealWidth,
                        maxWidth: BrewLayout.installedDetailColumnMaxWidth,
                        maxHeight: .infinity,
                        alignment: .topLeading,
                    )
                }
            } else {
                InstalledPackagesView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await viewModel.load()
        }
    }
}
