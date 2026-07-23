import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Feature-owned content/detail columns for the Installed tab. The view model is owned by
/// ``InstalledUpgradesContainer`` so it (and the shared toolbar search field) survives switching
/// between the Installed and Upgrades tabs.
struct InstalledColumns: View {
    let viewModel: InstalledViewModel
    @Binding var deepLinkSelection: InstalledBrewPackage.ID?

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
        // The view model now persists across tab switches, so a deep link can't be applied via the
        // model's initialiser. Apply it whenever the pending selection changes (and on first
        // appearance), then clear it. `initial: true` covers arriving at the tab with a selection
        // already queued; `setSelection` sets it directly, so it works before the list has loaded.
        .onChange(of: deepLinkSelection, initial: true) { _, pending in
            guard let pending else { return }
            viewModel.setSelection(pending)
            deepLinkSelection = nil
        }
    }
}
