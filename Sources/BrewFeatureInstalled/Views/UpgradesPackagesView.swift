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
                        } else if viewModel.showsUpgradeCheckFailure {
                            upgradeCheckFailedState
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

    private var allCaughtUpState: some View {
        centeredEmptyState(
            title: viewModel.upToDateTitle,
            subtitle: viewModel.upToDateDetail,
            accessibilityLabel: viewModel.upToDateTitle,
        )
    }

    /// An empty list after a failed check means "unknown", not "up to date".
    private var upgradeCheckFailedState: some View {
        centeredEmptyState(
            title: UpgradesViewModel.upgradeCheckFailedTitle,
            subtitle: viewModel.upgradeCheckFailureDetail,
            actionTitle: "Try Again",
            accessibilityLabel: UpgradesViewModel.upgradeCheckFailedTitle,
            icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.brewTitle2)
                    .brewWarningGlyphStyle()
            },
            action: { Task { await viewModel.refresh() } },
        )
        .axid(.errorState)
    }

    /// Shown when the active filters (scope and/or search) hide every outdated package but upgrades
    /// still exist in the inventory — distinct from the "all caught up" state.
    private var noSearchMatchesState: some View {
        centeredEmptyState(
            title: String(
                localized: "No matching upgrades",
                comment: "Upgrades filter-empty state title",
            ),
            subtitle: noSearchMatchesSubtitle,
            actionTitle: "Show all upgrades",
            accessibilityLabel: noSearchMatchesSubtitle,
            action: { viewModel.resetFilters() },
        )
    }

    private func centeredEmptyState(
        title: String,
        subtitle: String,
        actionTitle: LocalizedStringKey? = nil,
        accessibilityLabel: String,
        @ViewBuilder icon: () -> some View = { EmptyView() },
        action: (() -> Void)? = nil,
    ) -> some View {
        VStack(spacing: BrewSpacing.md) {
            Spacer(minLength: 0)
            icon()
                .accessibilityHidden(true)
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

    #Preview("Upgrades list - check failed") {
        let viewModel = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(
                packages: [PreviewSupport.currentCask],
                refreshFailure: BrewCommandError.failed(
                    exitCode: 1,
                    stderr: "fatal: not a git repository (or any of the parent directories): .git",
                ),
            ),
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
