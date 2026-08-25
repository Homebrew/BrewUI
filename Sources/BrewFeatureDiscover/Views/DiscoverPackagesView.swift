import BrewAccessibilityID
import BrewCore
import BrewUIComponents
import SwiftUI

/// Middle column of the main window: Discover package list.
struct DiscoverPackagesView: View {
    @Bindable var viewModel: DiscoverViewModel

    @State private var searchFocus = SearchFocusArbiter()
    @FocusState private var focus: SearchFocusTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            scopePicker
            Divider()
            AsyncContentView(
                state: viewModel.activeState,
                onRetry: { Task { await viewModel.reloadActive() } },
                loaded: { packages in
                    DiscoverPackageSections(viewModel: viewModel, packages: packages, focus: $focus)
                },
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .axid(.discoverScreen)
        // `.searchable` injects its field into the window toolbar, and SwiftUI offers no hook to
        // put an accessibility identifier on it — an `.axid` here would land on this content and
        // overwrite `.discoverScreen`. `AXID.discoverSearchField` therefore stays unattached until
        // the field is custom; query it via `app.searchFields` for now.
        .searchable(
            text: $viewModel.query,
            isPresented: searchFieldPresented,
            placement: .toolbar,
            prompt: "Search Homebrew's Packages",
        )
        .searchFocused($focus, equals: .searchField)
        .focusedSceneValue(\.focusSearchField, focusSearchField)
        .onChange(of: searchFocus.target) { _, _ in
            moveFocusToTarget()
        }
        .onChange(of: focus) { _, focus in
            searchFocus.focusDidChange(to: focus)
            if focus != .searchField, viewModel.query.isEmpty {
                searchFocus.emptySearchFieldDidLoseFocus()
            }
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
        .onChange(of: canFocusList, initial: true) { _, canFocus in
            if canFocus {
                searchFocus.contentDidLoad()
            }
        }
        .onChange(of: viewModel.query, initial: true) { _, query in
            if !query.isEmpty {
                searchFocus.searchFieldDidPresent()
            }
        }
        .task(id: viewModel.query) {
            // Debounce so intermediate keystrokes don't each fire a search; cancellation handles the rest.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else {
                return
            }
            await viewModel.search()
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

    /// Clearing the query back to empty must not kick the cursor out of the search field.
    private var canFocusList: Bool {
        viewModel.trending.isLoaded && !viewModel.isSearching
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text(viewModel.paneHeading)
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
            HStack(spacing: BrewSpacing.xs) {
                if viewModel.showsSubtitleTrendIcon {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.brewSubheadline)
                        .foregroundStyle(Color.brewBrandPrimary)
                }
                Text(viewModel.subtitleText)
                    .font(.brewSubheadline)
                    .foregroundStyle(
                        viewModel.isSubtitleError ? Color.brewStatusError : Color.brewTextSecondary,
                    )
            }
        }
        .padding(BrewSpacing.lg)
        .accessibilityElement(children: .combine)
    }

    /// Persistent kind filter, always visible (trending and results). Filters client-side; never refetches.
    private var scopePicker: some View {
        Picker("Scope", selection: $viewModel.scope) {
            Text("All").tag(DiscoverSearchScope.all)
            Text("Formulae").tag(DiscoverSearchScope.formulae)
            Text("Casks").tag(DiscoverSearchScope.casks)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, BrewSpacing.lg)
        .padding(.bottom, BrewSpacing.md)
    }
}

/// Sectioned Discover list, split by package kind and filtered by the active scope. Renders an inline
/// empty-state message when a visible section has no rows (e.g. a scope filter that excludes everything).
private struct DiscoverPackageSections: View {
    let viewModel: DiscoverViewModel
    /// The redacted-placeholder or loaded packages handed down by `AsyncContentView` for this render.
    let packages: [DiscoveryBrewPackage]
    @FocusState.Binding var focus: SearchFocusTarget?

    private var formulae: [DiscoveryBrewPackage] {
        viewModel.showsFormulaeSection ? DiscoverViewModel.section(packages, kind: .formula) : []
    }

    private var casks: [DiscoveryBrewPackage] {
        viewModel.showsCasksSection ? DiscoverViewModel.section(packages, kind: .cask) : []
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if viewModel.showsFormulaeSection {
                    Section(viewModel.formulaeSectionTitle) {
                        sectionContent(formulae, kind: .formula)
                    }
                }
                if viewModel.showsCasksSection {
                    Section(viewModel.casksSectionTitle) {
                        sectionContent(casks, kind: .cask)
                    }
                }
            }
            .listStyle(.inset)
            .accessibilityLabel("Discover packages")
            .axid(.discoverList)
            .onAppear {
                scrollToSelection(viewModel.selectedPackageID, with: proxy)
            }
            .focused($focus, equals: .list)
            .onChange(of: viewModel.selectedPackageID) { _, selectedID in
                scrollToSelection(selectedID, with: proxy)
            }
            .onChange(of: packages.map(\.id)) { _, _ in
                scrollToSelection(viewModel.selectedPackageID, with: proxy)
            }
            .onKeyPress(.upArrow) {
                viewModel.selectPrevious()
                return .handled
            }
            .onKeyPress(.downArrow) {
                viewModel.selectNext()
                return .handled
            }
            .onExitCommand {
                viewModel.setSelection(nil)
            }
        }
    }

    @ViewBuilder
    private func sectionContent(_ rows: [DiscoveryBrewPackage], kind: HomebrewPackageKind) -> some View {
        if rows.isEmpty {
            emptyState(for: kind)
        } else {
            ForEach(rows) { package in
                listRow(package)
                    .id(package.id)
                    .contentShape(Rectangle())
                    .listRowBackground(
                        RoundedRectangle(
                            cornerRadius: BrewRadius.lg,
                            style: .continuous,
                        )
                        .fill(
                            viewModel.selectedPackageID == package.id ? Color.brewBrandTint : Color.clear,
                        )
                        .padding(.horizontal, BrewSpacing.sm),
                    )
                    .onTapGesture {
                        // Needed to suppress the default ugly blue macOS highlight state
                        viewModel.setSelection(package.id)
                    }
                    .axid(.discoverRow(token: package.name))
            }
        }
    }

    private func listRow(_ package: DiscoveryBrewPackage) -> some View {
        DiscoverListRowRoot(
            discoveryPackage: package,
            showsInstallMetrics: viewModel.showsInstallMetrics,
        )
    }

    private func emptyState(for kind: HomebrewPackageKind) -> some View {
        Text(emptyStateMessage(for: kind))
            .font(.brewCallout)
            .foregroundStyle(Color.brewTextTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, BrewSpacing.sm)
            .listRowBackground(Color.clear)
    }

    private func emptyStateMessage(for kind: HomebrewPackageKind) -> String {
        switch kind {
        case .formula:
            String(localized: "No formulae match", comment: "Discover empty formulae section")
        case .cask:
            String(localized: "No casks match", comment: "Discover empty casks section")
        }
    }

    private func scrollToSelection(
        _ selectedID: BrewPackage.ID?,
        with proxy: ScrollViewProxy,
    ) {
        guard let selectedID, packages.contains(where: { $0.id == selectedID }) else {
            return
        }
        withAnimation(.brewFast) {
            proxy.scrollTo(selectedID, anchor: .center)
        }
    }
}
