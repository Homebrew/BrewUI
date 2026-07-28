import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Hosts the Installed and Upgrades columns under one stable view identity so a single toolbar
/// `.searchable` stays mounted across tab switches. Tearing it down per switch (as separate cases
/// did) eventually detaches the native search field from the toolbar's mouse hit-testing.
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

/// Split from the Root because environment values aren't available in a `View`'s `init`, and both
/// view models must be constructed there so they persist as `@State`.
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
