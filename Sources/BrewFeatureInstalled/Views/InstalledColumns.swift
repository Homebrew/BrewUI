import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

public struct InstalledColumnsRoot: View {
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository

    public init() {}

    public var body: some View {
        InstalledColumns(installedPackagesRepository: installedPackagesRepository)
    }
}

/// Feature-owned content/detail columns for the main window.
struct InstalledColumns: View {
    @State var viewModel: InstalledViewModel

    init(installedPackagesRepository: any InstalledPackagesRepository) {
        _viewModel = State(
            initialValue: .init(repository: installedPackagesRepository),
        )
    }

    var body: some View {
        HSplitView {
            InstalledPackagesView(
                viewModel: viewModel,
            )
            .frame(
                minWidth: BrewLayout.installedListColumnMinWidth,
                idealWidth: BrewLayout.installedListColumnIdealWidth,
                maxWidth: BrewLayout.installedListColumnMaxWidth,
                maxHeight: .infinity,
                alignment: .topLeading,
            )

            Group {
                if let selectedPackage = viewModel.selectedPackage {
                    InstalledPackageDetailRoot(
                        selectedPackage: selectedPackage,
                        onSelectInstalledPackage: { viewModel.selectInstalledPackage(id: $0) },
                    )
                } else {
                    InstalledPackageDetailPlaceholder()
                }
            }
            .frame(
                minWidth: BrewLayout.inspectorWidth,
                idealWidth: BrewLayout.installedDetailColumnIdealWidth,
                maxWidth: BrewLayout.installedDetailColumnMaxWidth,
                maxHeight: .infinity,
                alignment: .topLeading,
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
