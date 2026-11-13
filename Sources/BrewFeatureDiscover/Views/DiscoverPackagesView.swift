import BrewAccessibilityID
import BrewAppEnvironment
import BrewCore
import BrewUIComponents
import SwiftUI

/// Middle column of the main window: Discover package list.
struct DiscoverPackagesView: View {
    @Bindable var viewModel: DiscoverViewModel
    @Binding var searchQuery: String
    /// Whether the window's toolbar search field holds the keyboard. That field is AppKit and lives
    /// outside this view, so `focus` stays nil while the user types in it.
    var isSearchFocused = false

    /// The search field lives in the window toolbar now, so this view only hands the list the keyboard.
    @FocusState private var focus: SearchFocusTarget?
    @State private var hasFocusedList = false

    @Environment(\.packageListBanner) private var packageListBanner

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            packageListBanner()

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
        .onChange(of: canFocusList, initial: true) { _, canFocus in
            focusListOnFirstLoad(canFocus: canFocus)
        }
        // Neither sync runs on mount: seeding one side from the other then races the window's
        // sidebar-switch reset, which searches with the previous tab's query or ping-pongs forever.
        .onChange(of: viewModel.query) { _, query in
            if searchQuery != query {
                searchQuery = query
            }
        }
        .onChange(of: searchQuery) { _, query in
            if viewModel.query != query {
                viewModel.query = query
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

    /// Only the first load claims the keyboard: later loads follow a search, and taking focus then
    /// would pull the cursor out of the toolbar field mid-typing. The hop lets the list mount first.
    private func focusListOnFirstLoad(canFocus: Bool) {
        guard canFocus, !hasFocusedList else {
            return
        }
        hasFocusedList = true
        // The user is typing in the toolbar field; leave the keyboard with them.
        guard !isSearchFocused else {
            return
        }
        Task { @MainActor in
            if focus == nil {
                focus = .list
            }
        }
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
                        .foregroundStyle(Color.brewTextBrand)
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
        Picker(String(localized: "Scope", bundle: #bundle, comment: "Discover tab: formula/cask scope picker label"), selection: $viewModel.scope) {
            Text("All", bundle: #bundle, comment: "Scope picker: every package kind").tag(DiscoverSearchScope.all)
            Text("Formulae", bundle: #bundle, comment: "Scope picker: formulae only").tag(DiscoverSearchScope.formulae)
            Text("Casks", bundle: #bundle, comment: "Scope picker: casks only").tag(DiscoverSearchScope.casks)
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
            .accessibilityLabel(String(localized: "Discover packages", bundle: #bundle, comment: "VoiceOver: the Discover results list"))
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
            String(localized: "No formulae match", bundle: #bundle, comment: "Discover empty formulae section")
        case .cask:
            String(localized: "No casks match", bundle: #bundle, comment: "Discover empty casks section")
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
