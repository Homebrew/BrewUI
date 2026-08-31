//
//  UpgradesPackagesView.swift
//  BrewFeatureInstalled
//

import BrewAccessibilityID
import BrewCore
import BrewUIComponents
import SwiftUI

/// Middle column of the Upgrades tab: header, batch Upgrade All, list of outdated packages,
/// and a friendly empty state when nothing is outdated.
struct UpgradesPackagesView: View {
    @Bindable var viewModel: UpgradesViewModel
    @FocusState.Binding var focus: SearchFocusTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            UpgradesHeaderView(viewModel: viewModel)

            if viewModel.totalOutdatedCount > 0 {
                scopePicker
                Divider()
            }

            AsyncContentView(
                state: viewModel.state,
                onRetry: { Task { await viewModel.refresh() } },
                loaded: { content in
                    if content.packages.isEmpty {
                        if viewModel.totalOutdatedCount > 0 {
                            noSearchMatchesState
                        } else {
                            allCaughtUpState
                        }
                    } else {
                        upgradesList(content)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                },
            )
        }
        .accessibilityElement(children: .contain)
        .axid(.upgradesScreen)
        .task {
            await viewModel.load()
        }
    }

    /// Kind filter shown whenever there is outdated inventory to narrow. Filters client-side; never refetches.
    private var scopePicker: some View {
        Picker("Scope", selection: $viewModel.scope) {
            Text("All").tag(InstalledPackageScope.all)
            Text("Formulae").tag(InstalledPackageScope.formulae)
            Text("Casks").tag(InstalledPackageScope.casks)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, BrewSpacing.lg)
        .padding(.vertical, BrewSpacing.md)
    }

    private func upgradesList(_ content: InstalledPackagesContent) -> some View {
        ScrollViewReader { proxy in
            List {
                ForEach(content.packages) { package in
                    row(for: package)
                }
            }
            .listStyle(.inset)
            .accessibilityLabel("Outdated packages")
            .axid(.upgradesList)
            .onAppear {
                scrollToSelection(viewModel.activeSelectedPackageID, in: content, with: proxy)
            }
            .focused($focus, equals: .list)
            .onChange(of: viewModel.activeSelectedPackageID) { _, selectedID in
                scrollToSelection(selectedID, in: content, with: proxy)
            }
            .onChange(of: content.packages.map(\.id)) { _, _ in
                scrollToSelection(viewModel.activeSelectedPackageID, in: content, with: proxy)
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
                viewModel.clearSelection()
            }
        }
    }

    private func row(for package: InstalledBrewPackage) -> some View {
        InstalledListRowRoot(package: package)
            .id(package.id)
            .contentShape(Rectangle())
            .listRowBackground(
                RoundedRectangle(
                    cornerRadius: BrewRadius.lg,
                    style: .continuous,
                )
                .fill(
                    viewModel.activeSelectedPackageID == package.id ? Color.brewBrandTint : Color.clear,
                )
                .padding(.horizontal, BrewSpacing.sm),
            )
            .onTapGesture {
                // Needed to suppress the default ugly blue macOS highlight state
                viewModel.setSelection(package.id)
            }
            .axid(.upgradesRow(token: package.name))
    }

    private func scrollToSelection(
        _ selectedID: InstalledBrewPackage.ID?,
        in content: InstalledPackagesContent,
        with proxy: ScrollViewProxy,
    ) {
        guard let selectedID, content.packages.contains(where: { $0.id == selectedID }) else {
            return
        }
        withAnimation(.brewFast) {
            proxy.scrollTo(selectedID, anchor: .center)
        }
    }

    /// No action of its own: re-checking now lives in the header, where it is reachable whether or not
    /// this state is on screen.
    private var allCaughtUpState: some View {
        centeredEmptyState(
            title: "✅ You're all caught up",
            subtitle: allCaughtUpSubtitle,
            accessibilityLabel: "All packages are up to date",
        )
    }

    /// Shown when the active filters (scope and/or search) hide every outdated package but upgrades
    /// still exist in the inventory — distinct from the "all caught up" state.
    private var noSearchMatchesState: some View {
        centeredEmptyState(
            title: "No matching upgrades",
            subtitle: noSearchMatchesSubtitle,
            actionTitle: "Show all upgrades",
            accessibilityLabel: noSearchMatchesSubtitle,
        ) {
            viewModel.resetFilters()
        }
    }

    private func centeredEmptyState(
        title: LocalizedStringKey,
        subtitle: String,
        actionTitle: LocalizedStringKey? = nil,
        accessibilityLabel: String,
        action: (() -> Void)? = nil,
    ) -> some View {
        VStack(spacing: BrewSpacing.md) {
            Spacer(minLength: 0)
            Text(title)
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
            Text(subtitle)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle) }
                    .controlSize(.regular)
                    .padding(.top, BrewSpacing.sm)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(BrewSpacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var allCaughtUpSubtitle: String {
        let total = viewModel.totalInstalledCount
        switch total {
        case 0:
            return String(
                localized: "No installed packages to check.",
                comment: "Upgrades empty state when nothing is installed",
            )
        case 1:
            return String(
                localized: "Your installed package is at its latest version.",
                comment: "Upgrades empty state for a single installed package",
            )
        default:
            return String(
                localized: "All \(total) packages are at their latest versions.",
                comment: "Upgrades empty state with total installed count",
            )
        }
    }

    private var noSearchMatchesSubtitle: String {
        let hidden = viewModel.totalOutdatedCount
        if hidden == 1 {
            return String(
                localized: "1 outdated package is hidden by the current filters.",
                comment: "Upgrades filter-empty state with a single hidden outdated package",
            )
        }
        return String(
            localized: "\(hidden) outdated packages are hidden by the current filters.",
            comment: "Upgrades filter-empty state with multiple hidden outdated packages",
        )
    }
}

#if DEBUG
    import BrewRepositoryInterfaces

    #Preview("Upgrades list - loaded") {
        let viewModel = UpgradesViewModel(
            repository: PreviewSupport.makeInstalledPackagesRepository(),
            brewCommandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
        SearchFocusPreviewHost { focus in
            UpgradesPackagesView(viewModel: viewModel, focus: focus)
        }
        .environment(\.brewCommandCenter, PreviewSupport.commandCenter)
        .task {
            await viewModel.load()
        }
        .frame(minWidth: 360, minHeight: 500)
    }

    #Preview("Upgrades list - filtered to nothing") {
        let viewModel = UpgradesViewModel(
            repository: PreviewSupport.makeInstalledPackagesRepository(),
            brewCommandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
        SearchFocusPreviewHost { focus in
            UpgradesPackagesView(viewModel: viewModel, focus: focus)
        }
        .environment(\.brewCommandCenter, PreviewSupport.commandCenter)
        .task {
            await viewModel.load()
            viewModel.searchQuery = "no-such-package"
        }
        .frame(minWidth: 360, minHeight: 500)
    }

    #Preview("Upgrades list - empty") {
        let viewModel = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: [
                PreviewSupport.currentCask,
            ]),
            brewCommandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
        SearchFocusPreviewHost { focus in
            UpgradesPackagesView(viewModel: viewModel, focus: focus)
        }
        .environment(\.brewCommandCenter, PreviewSupport.commandCenter)
        .task {
            await viewModel.load()
        }
        .frame(minWidth: 360, minHeight: 500)
    }
#endif
