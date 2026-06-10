import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

public struct UpgradesColumnsRoot: View {
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository
    @Environment(\.brewCommandCenter) private var brewCommandCenter
    @Environment(\.mutatingCommandFactory) private var mutatingCommandFactory
    @Environment(\.navigateToInstalledPackage) private var navigateToInstalledPackage

    public init() {}

    public var body: some View {
        UpgradesColumns(
            installedPackagesRepository: installedPackagesRepository,
            brewCommandCenter: brewCommandCenter,
            mutatingCommandFactory: mutatingCommandFactory,
            navigateToInstalledPackage: navigateToInstalledPackage,
        )
    }
}

/// Feature-owned content/detail columns for the Upgrades tab. Mirrors `InstalledColumns`
/// but projects only outdated packages and adds an Upgrade All affordance.
struct UpgradesColumns: View {
    @State var viewModel: UpgradesViewModel
    private let navigateToInstalledPackage: @MainActor (InstalledBrewPackage.ID) -> Void

    init(
        installedPackagesRepository: any InstalledPackagesRepository,
        brewCommandCenter: any BrewCommandCenter,
        mutatingCommandFactory: any BrewMutatingCommandFactory,
        navigateToInstalledPackage: @escaping @MainActor (InstalledBrewPackage.ID) -> Void,
    ) {
        _viewModel = State(
            initialValue: UpgradesViewModel(
                repository: installedPackagesRepository,
                brewCommandCenter: brewCommandCenter,
                commandFactory: mutatingCommandFactory,
            ),
        )
        self.navigateToInstalledPackage = navigateToInstalledPackage
    }

    var body: some View {
        HSplitView {
            UpgradesPackagesView(viewModel: viewModel)
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
                    // routing through the local Upgrades VM would silently fail
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
