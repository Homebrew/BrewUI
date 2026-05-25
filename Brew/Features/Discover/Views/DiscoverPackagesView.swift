import SwiftUI

/// Middle column of the main window: Discover package list.
struct DiscoverPackagesView: View {
    @Bindable var viewModel: DiscoverViewModel
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            AsyncContentView(
                state: viewModel.activeState,
                onRetry: { Task { await viewModel.reloadActive() } },
                loaded: { packages in
                    DiscoverPackageSections(
                        packages: packages,
                        scope: viewModel.scope,
                        formulaeSectionTitle: viewModel.formulaeSectionTitle,
                        casksSectionTitle: viewModel.casksSectionTitle,
                        showsInstallMetrics: viewModel.showsInstallMetrics,
                        showsCallout: viewModel.showsTrendingCallout,
                        isSearching: viewModel.isSearching,
                        selectedPackageID: viewModel.selectedPackageID,
                        installedRepository: installedPackagesRepository,
                        onSelect: { viewModel.setSelection($0) },
                    )
                },
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .searchable(
            text: $viewModel.query,
            isPresented: $viewModel.isSearchSelected,
            placement: .toolbar,
            prompt: "Search the Homebrew catalogue",
        )
        .searchScopes($viewModel.scope) {
            Text("All").tag(DiscoverSearchScope.all)
            Text("Formulae").tag(DiscoverSearchScope.formulae)
            Text("Casks").tag(DiscoverSearchScope.casks)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text("Discover")
                .font(.brewTitle1)
                .foregroundStyle(Color.brewTextPrimary)
            headerSubtitle
        }
        .padding(BrewSpacing.lg)
    }

    private var headerSubtitle: some View {
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
}

/// Sectioned Discover list, split by package kind and filtered by the active scope. Renders an inline
/// empty-state message when a visible section has no rows (e.g. a scope filter that excludes everything).
private struct DiscoverPackageSections: View {
    let packages: [DiscoveryBrewPackage]
    let scope: DiscoverSearchScope
    let formulaeSectionTitle: String
    let casksSectionTitle: String
    let showsInstallMetrics: Bool
    let showsCallout: Bool
    let isSearching: Bool
    let selectedPackageID: BrewPackage.ID?
    let installedRepository: any InstalledPackageStatusReading
    let onSelect: (BrewPackage.ID?) -> Void

    /// Approximate catalogue size for the search-hint copy. Hardcoded for now; should eventually be
    /// sourced from the catalogue once a package-count property is exposed.
    private static let approximateCatalogueSize = "9,000+"

    private var showsFormulaeSection: Bool {
        scope != .casks
    }

    private var showsCasksSection: Bool {
        scope != .formulae
    }

    private var formulae: [DiscoveryBrewPackage] {
        showsFormulaeSection ? DiscoverViewModel.sortedSection(packages, kind: .formula) : []
    }

    private var casks: [DiscoveryBrewPackage] {
        showsCasksSection ? DiscoverViewModel.sortedSection(packages, kind: .cask) : []
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if showsCallout {
                    calloutRow
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                if showsFormulaeSection {
                    Section(formulaeSectionTitle) {
                        sectionContent(formulae, kind: .formula)
                    }
                }
                if showsCasksSection {
                    Section(casksSectionTitle) {
                        sectionContent(casks, kind: .cask)
                    }
                }
            }
            .listStyle(.plain)
            .accessibilityLabel("Discover packages")
            .onAppear {
                scrollToSelection(selectedPackageID, with: proxy)
            }
            .onChange(of: selectedPackageID) { _, selectedID in
                scrollToSelection(selectedID, with: proxy)
            }
            .onChange(of: packages.map(\.id)) { _, _ in
                scrollToSelection(selectedPackageID, with: proxy)
            }
            .onExitCommand {
                onSelect(nil)
            }
        }
    }

    private var calloutRow: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
            HStack(spacing: BrewSpacing.xs) {
                Text("Find a package")
                    .font(.brewBody.weight(.semibold))
                    .foregroundStyle(Color.brewTextPrimary)
                Text("(⌘F)")
                    .font(.brewCodeSmall)
                    .foregroundStyle(Color.brewTextTertiary)
            }
            Text("Search across all \(Self.approximateCatalogueSize) formulae and casks — or browse trending below.")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, BrewSpacing.sm)
        .accessibilityElement(children: .combine)
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
                    .onTapGesture {
                        onSelect(package.id)
                    }
                    .listRowBackground(
                        selectedPackageID == package.id ? Color.brewBrandTint : Color.clear,
                    )
            }
        }
    }

    private func listRow(_ package: DiscoveryBrewPackage) -> some View {
        DiscoverListRowView(
            viewModel: DiscoverListRowViewModel(
                discoveryPackage: package,
                installedRepository: installedRepository,
                showsInstallMetrics: showsInstallMetrics,
            ),
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
        switch (kind, isSearching) {
        case (.formula, true):
            String(localized: "No matching formulae", comment: "Discover empty formulae section, searching")
        case (.cask, true):
            String(localized: "No matching casks", comment: "Discover empty casks section, searching")
        case (.formula, false):
            String(localized: "No formulae to show", comment: "Discover empty formulae section")
        case (.cask, false):
            String(localized: "No casks to show", comment: "Discover empty casks section")
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
