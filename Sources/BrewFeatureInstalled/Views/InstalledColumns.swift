import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

public struct InstalledColumnsRoot: View {
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository
    @Binding private var deepLinkSelection: InstalledBrewPackage.ID?

    public init(deepLinkSelection: Binding<InstalledBrewPackage.ID?> = .constant(nil)) {
        _deepLinkSelection = deepLinkSelection
    }

    public var body: some View {
        InstalledColumns(
            installedPackagesRepository: installedPackagesRepository,
            deepLinkSelection: $deepLinkSelection,
        )
    }
}

/// Feature-owned content/detail columns for the main window.
struct InstalledColumns: View {
    @State var viewModel: InstalledViewModel
    @Binding var deepLinkSelection: InstalledBrewPackage.ID?

    init(
        installedPackagesRepository: any InstalledPackagesRepository,
        deepLinkSelection: Binding<InstalledBrewPackage.ID?>,
    ) {
        _viewModel = State(
            initialValue: .init(
                repository: installedPackagesRepository,
                initialSelection: deepLinkSelection.wrappedValue,
            ),
        )
        _deepLinkSelection = deepLinkSelection
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
        .onAppear {
            if deepLinkSelection != nil { deepLinkSelection = nil }
        }
    }
}
