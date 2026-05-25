import SwiftUI

/// Middle column of the main window: Discover package list.
struct DiscoverPackagesView: View {
    @Bindable var viewModel: DiscoverViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            scopePicker
            Divider()
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
                        selectedPackageID: viewModel.selectedPackageID,
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
            prompt: "Search packages — try “node”, “ffmpeg”, “docker”",
        )
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
            Text(viewModel.paneHeading)
                .font(.brewTitle1)
                .foregroundStyle(Color.brewTextPrimary)
            Text(viewModel.subtitleText)
                .font(.brewSubheadline)
                .foregroundStyle(
                    viewModel.isSubtitleError ? Color.brewStatusError : Color.brewTextSecondary,
                )
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
    let packages: [DiscoveryBrewPackage]
    let scope: DiscoverSearchScope
    let formulaeSectionTitle: String
    let casksSectionTitle: String
    let showsInstallMetrics: Bool
    let selectedPackageID: BrewPackage.ID?
    let onSelect: (BrewPackage.ID?) -> Void

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
        DiscoverListRowRoot(
            discoveryPackage: package,
            showsInstallMetrics: showsInstallMetrics,
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
