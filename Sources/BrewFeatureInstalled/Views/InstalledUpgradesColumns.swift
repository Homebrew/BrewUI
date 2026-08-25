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

    @State private var searchFocus = SearchFocusArbiter()
    @FocusState private var focus: SearchFocusTarget?

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
                isPresented: searchFieldPresented,
                placement: .toolbar,
                prompt: activeSearchPrompt,
            )
            .searchFocused($focus, equals: .searchField)
            .focusedSceneValue(\.focusSearchField, focusSearchField)
            .onChange(of: searchFocus.target) { _, _ in
                moveFocusToTarget()
            }
            .onChange(of: focus) { _, focus in
                searchFocus.focusDidChange(to: focus)
            }
            .onChange(of: searchFocus.isSearchFieldPresented) { _, presented in
                guard presented else {
                    return
                }
                // The field only reaches the toolbar after this update commits, so a ⌘F that had to
                // present it first has to wait a turn before it can be handed the keyboard.
                Task { @MainActor in
                    searchFocus.searchFieldDidPresent()
                }
            }
            .onChange(of: isActiveContentLoaded, initial: true) { _, loaded in
                if loaded {
                    searchFocus.contentDidLoad()
                }
            }
            // Also this view's only read of the query, which is what subscribes it to changes:
            // the binding handed to `.searchable` is lazy and subscribes to nothing.
            .onChange(of: activeSearchQuery.wrappedValue, initial: true) { _, query in
                if !query.isEmpty {
                    searchFocus.searchFieldDidPresent()
                }
            }
    }

    /// Hopping off this update is load-bearing. `.searchable` reports its dismissal from inside
    /// AppKit's layout pass, so writing the arbiter's new target straight back into `.searchFocused`
    /// re-enters that pass, which dismisses again — Escape used to wedge the app until the stack ran out.
    private func moveFocusToTarget() {
        Task { @MainActor in
            guard focus != searchFocus.target else {
                return
            }
            focus = searchFocus.target
        }
    }

    private var focusSearchField: FocusSearchFieldAction {
        FocusSearchFieldAction {
            searchFocus.requestSearchFocus()
        }
    }

    private var searchFieldPresented: Binding<Bool> {
        Binding(
            get: { searchFocus.isSearchFieldPresented },
            set: { presented in
                if presented {
                    searchFocus.searchFieldDidPresent()
                } else {
                    searchFocus.searchFieldDidDismiss()
                }
            },
        )
    }

    @ViewBuilder private var content: some View {
        switch mode {
        case .installed:
            InstalledColumns(
                viewModel: installed,
                deepLinkSelection: $deepLinkSelection,
                focus: $focus,
            )
        case .upgrades:
            UpgradesColumns(
                viewModel: upgrades,
                navigateToInstalledPackage: navigateToInstalledPackage,
                focus: $focus,
            )
        }
    }

    private var isActiveContentLoaded: Bool {
        switch mode {
        case .installed: installed.state.isLoaded
        case .upgrades: upgrades.state.isLoaded
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
