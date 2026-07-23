import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Feature-owned content/detail columns for the Upgrades tab. Mirrors ``InstalledColumns`` but
/// projects only outdated packages and adds an Upgrade All affordance. The view model is owned by
/// ``InstalledUpgradesContainer`` so it (and the shared toolbar search field) survives switching
/// between the Installed and Upgrades tabs.
struct UpgradesColumns: View {
    let viewModel: UpgradesViewModel
    let navigateToInstalledPackage: @MainActor (InstalledBrewPackage.ID) -> Void

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
