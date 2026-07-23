import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Hosts the Installed and Upgrades columns under a single, stable view identity.
///
/// Both tabs previously owned their own `.searchable(placement: .toolbar)`. Because the main
/// window swaps the entire feature subtree on every sidebar switch, that meant a toolbar-placed
/// search field was torn down and rebuilt on each Installed⇄Upgrades toggle. After a few cycles
/// the native search field detached from the toolbar's hit-testing — clicks stopped landing while
/// ⌘F (which drives `.searchable` programmatically via `isPresented`) still worked.
///
/// Keeping one searchable alive here — and only re-routing its bindings to the active tab's view
/// model — avoids that churn. The two view models persist for as long as either tab is on screen.
public struct InstalledUpgradesRoot: View {
    public enum Mode: Sendable { case installed, upgrades }

    @Environment(\.installedPackagesRepository) private var installedPackagesRepository
    @Environment(\.brewCommandCenter) private var brewCommandCenter
    @Environment(\.mutatingCommandFactory) private var mutatingCommandFactory
    @Environment(\.navigateToInstalledPackage) private var navigateToInstalledPackage

    private let mode: Mode
    @Binding private var deepLinkSelection: InstalledBrewPackage.ID?

    public init(
        mode: Mode,
        deepLinkSelection: Binding<InstalledBrewPackage.ID?> = .constant(nil),
    ) {
        self.mode = mode
        _deepLinkSelection = deepLinkSelection
    }

    public var body: some View {
        InstalledUpgradesContainer(
            installedPackagesRepository: installedPackagesRepository,
            brewCommandCenter: brewCommandCenter,
            mutatingCommandFactory: mutatingCommandFactory,
            navigateToInstalledPackage: navigateToInstalledPackage,
            mode: mode,
            deepLinkSelection: $deepLinkSelection,
        )
    }
}

/// Owns both view models as persistent `@State` (environment values aren't available in a `View`'s
/// `init`, hence the Root→Container split) and applies the single shared `.searchable`.
struct InstalledUpgradesContainer: View {
    @State private var installed: InstalledViewModel
    @State private var upgrades: UpgradesViewModel
    private let mode: InstalledUpgradesRoot.Mode
    private let navigateToInstalledPackage: @MainActor (InstalledBrewPackage.ID) -> Void
    @Binding private var deepLinkSelection: InstalledBrewPackage.ID?

    init(
        installedPackagesRepository: any InstalledPackagesRepository,
        brewCommandCenter: any BrewCommandCenter,
        mutatingCommandFactory: any BrewMutatingCommandFactory,
        navigateToInstalledPackage: @escaping @MainActor (InstalledBrewPackage.ID) -> Void,
        mode: InstalledUpgradesRoot.Mode,
        deepLinkSelection: Binding<InstalledBrewPackage.ID?>,
    ) {
        _installed = State(
            initialValue: InstalledViewModel(
                repository: installedPackagesRepository,
                initialSelection: deepLinkSelection.wrappedValue,
            ),
        )
        _upgrades = State(
            initialValue: UpgradesViewModel(
                repository: installedPackagesRepository,
                brewCommandCenter: brewCommandCenter,
                commandFactory: mutatingCommandFactory,
            ),
        )
        self.mode = mode
        self.navigateToInstalledPackage = navigateToInstalledPackage
        _deepLinkSelection = deepLinkSelection
    }

    var body: some View {
        content
            .searchable(
                text: activeSearchQuery,
                isPresented: activeSearchPresented,
                placement: .toolbar,
                prompt: activeSearchPrompt,
            )
            .focusedSceneValue(\.searchPresented, activeSearchPresented)
    }

    @ViewBuilder private var content: some View {
        switch mode {
        case .installed:
            InstalledColumns(viewModel: installed, deepLinkSelection: $deepLinkSelection)
        case .upgrades:
            UpgradesColumns(viewModel: upgrades, navigateToInstalledPackage: navigateToInstalledPackage)
        }
    }

    private var activeSearchQuery: Binding<String> {
        switch mode {
        case .installed: $installed.searchQuery
        case .upgrades: $upgrades.searchQuery
        }
    }

    private var activeSearchPresented: Binding<Bool> {
        switch mode {
        case .installed: $installed.isSearchFieldPresented
        case .upgrades: $upgrades.isSearchFieldPresented
        }
    }

    private var activeSearchPrompt: LocalizedStringKey {
        switch mode {
        case .installed: "Search Installed Packages"
        case .upgrades: "Search Upgrades"
        }
    }
}
