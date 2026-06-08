import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

public struct UpdatesColumnsRoot: View {
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository
    @Environment(\.brewCommandCenter) private var brewCommandCenter
    @Environment(\.mutatingCommandFactory) private var mutatingCommandFactory
    @Environment(\.navigateToInstalledPackage) private var navigateToInstalledPackage

    public init() {}

    public var body: some View {
        UpdatesColumns(
            installedPackagesRepository: installedPackagesRepository,
            brewCommandCenter: brewCommandCenter,
            mutatingCommandFactory: mutatingCommandFactory,
            navigateToInstalledPackage: navigateToInstalledPackage,
        )
    }
}

/// Feature-owned content/detail columns for the Updates tab. Mirrors `InstalledColumns`
/// but projects only outdated packages and adds an Update All affordance.
struct UpdatesColumns: View {
    @State var viewModel: UpdatesViewModel
    private let navigateToInstalledPackage: @MainActor (InstalledBrewPackage.ID) -> Void

    init(
        installedPackagesRepository: any InstalledPackagesRepository,
        brewCommandCenter: any BrewCommandCenter,
        mutatingCommandFactory: any BrewMutatingCommandFactory,
        navigateToInstalledPackage: @escaping @MainActor (InstalledBrewPackage.ID) -> Void,
    ) {
        _viewModel = State(
            initialValue: UpdatesViewModel(
                repository: installedPackagesRepository,
                brewCommandCenter: brewCommandCenter,
                commandFactory: mutatingCommandFactory,
            ),
        )
        self.navigateToInstalledPackage = navigateToInstalledPackage
    }

    var body: some View {
        HSplitView {
            UpdatesPackagesView(viewModel: viewModel)
                .frame(
                    minWidth: BrewLayout.installedListColumnMinWidth,
                    idealWidth: BrewLayout.installedListColumnIdealWidth,
                    maxWidth: BrewLayout.installedListColumnMaxWidth,
                    maxHeight: .infinity,
                    alignment: .topLeading,
                )

            Group {
                if let selectedPackage = viewModel.selectedPackage {
                    // Relationship taps (Used by / Dependencies) cross to the
                    // Installed tab — the dependent is rarely outdated, so
                    // routing through the local Updates VM would silently fail
                    // its outdated-only guard.
                    InstalledPackageDetailRoot(
                        selectedPackage: selectedPackage,
                        onSelectInstalledPackage: navigateToInstalledPackage,
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
        .task {
            await viewModel.load()
        }
    }
}
