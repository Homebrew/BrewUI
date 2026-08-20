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

    @State private var isSearchFieldPresented = false
    @FocusState private var isSearchFieldFocused: Bool

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
                isPresented: $isSearchFieldPresented,
                placement: .toolbar,
                prompt: activeSearchPrompt,
            )
            .searchFocused($isSearchFieldFocused)
            .focusedSceneValue(\.focusSearchField, focusSearchField)
            .onChange(of: isSearchFieldFocused, initial: true) { _, focused in
                installed.isSearchFieldFocused = focused
                upgrades.isSearchFieldFocused = focused
            }
            // Also this view's only read of the query, which is what subscribes it to changes:
            // the binding handed to `.searchable` is lazy and subscribes to nothing.
            .onChange(of: activeSearchQuery.wrappedValue, initial: true) { _, query in
                if !query.isEmpty {
                    isSearchFieldPresented = true
                }
            }
    }

    /// Order matters: the list auto-focuses off `shouldFocusList` and would claim the cursor back.
    private var focusSearchField: FocusSearchFieldAction {
        let presented = $isSearchFieldPresented
        let focused = $isSearchFieldFocused
        let installed = installed
        let upgrades = upgrades
        return FocusSearchFieldAction {
            installed.isSearchFieldFocused = true
            upgrades.isSearchFieldFocused = true
            presented.wrappedValue = true
            focused.wrappedValue = true
        }
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

    private var activeSearchPrompt: LocalizedStringKey {
        switch mode {
        case .installed: "Search Installed Packages"
        case .upgrades: "Search Upgrades"
        }
    }
}
