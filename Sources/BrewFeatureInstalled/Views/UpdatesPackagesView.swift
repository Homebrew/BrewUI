//
//  UpdatesPackagesView.swift
//  BrewFeatureInstalled
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Middle column of the Updates tab: header, batch Update All, list of outdated packages,
/// and a friendly empty state when nothing is outdated.
struct UpdatesPackagesView: View {
    @Bindable var viewModel: UpdatesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            switch viewModel.state {
            case .loading:
                loadingSkeletonList
            case let .error(message):
                errorView(message)
            case let .loaded(content):
                if content.packages.isEmpty {
                    if viewModel.totalOutdatedCount > 0 {
                        noSearchMatchesState
                    } else {
                        allCaughtUpState
                    }
                } else {
                    updatesList(content)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .searchable(
            text: $viewModel.searchQuery,
            placement: .toolbar,
            prompt: "Search Updates",
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: BrewSpacing.md) {
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Available updates")
                    .font(.brewTitle2)
                    .foregroundStyle(Color.brewTextPrimary)
                Text(viewModel.outdatedSubtitle)
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityHeading(.h1)

            if viewModel.outdatedCount > 0 {
                Button {
                    viewModel.upgradeAll()
                } label: {
                    Text("Update All (\(viewModel.outdatedCount))")
                }
                .controlSize(.regular)
                .keyboardShortcut("u", modifiers: [.command, .shift])
                .disabled(viewModel.isUpgradingAny)
                .accessibilityLabel("Update all \(viewModel.outdatedCount) packages")
            }
        }
        .padding(BrewSpacing.lg)
    }

    private func updatesList(_ content: InstalledPackagesContent) -> some View {
        ScrollViewReader { proxy in
            List {
                if content.shouldShowFormulaeSection {
                    Section("Formulae") {
                        ForEach(content.formulaPackages) { package in
                            listRow(for: package)
                                .id(package.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.setSelection(package.id)
                                }
                                .listRowBackground(
                                    viewModel.activeSelectedPackageID == package.id ? Color.brewBrandTint : Color.clear,
                                )
                        }
                    }
                }

                if content.shouldShowCasksSection {
                    Section("Casks") {
                        ForEach(content.caskPackages) { package in
                            listRow(for: package)
                                .id(package.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.setSelection(package.id)
                                }
                                .listRowBackground(
                                    viewModel.activeSelectedPackageID == package.id ? Color.brewBrandTint : Color.clear,
                                )
                        }
                    }
                }
            }
            .listStyle(.plain)
            .accessibilityLabel("Outdated packages")
            .onAppear {
                scrollToSelection(viewModel.activeSelectedPackageID, in: content, with: proxy)
            }
            .onChange(of: viewModel.activeSelectedPackageID) { _, selectedID in
                scrollToSelection(selectedID, in: content, with: proxy)
            }
            .onChange(of: content.packages.map(\.id)) { _, _ in
                scrollToSelection(viewModel.activeSelectedPackageID, in: content, with: proxy)
            }
            .onExitCommand {
                viewModel.clearSelection()
            }
        }
    }

    private func listRow(for package: InstalledBrewPackage) -> some View {
        InstalledListRowRoot(package: package)
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
            title: "✅ You're all caught up",
            subtitle: allCaughtUpSubtitle,
            actionTitle: "Refresh",
            accessibilityLabel: "All packages are up to date",
        ) {
            Task { await viewModel.refresh() }
        }
    }

    /// Shown when the search filter hides every outdated package but updates
    /// still exist in the inventory — distinct from the "all caught up" state.
    private var noSearchMatchesState: some View {
        centeredEmptyState(
            title: "No matching updates",
            subtitle: noSearchMatchesSubtitle,
            actionTitle: "Show all updates",
            accessibilityLabel: noSearchMatchesSubtitle,
        ) {
            viewModel.searchQuery = ""
        }
    }

    private func centeredEmptyState(
        title: LocalizedStringKey,
        subtitle: String,
        actionTitle: LocalizedStringKey,
        accessibilityLabel: String,
        action: @escaping () -> Void,
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
            Button(action: action) { Text(actionTitle) }
                .controlSize(.regular)
                .padding(.top, BrewSpacing.sm)
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
                comment: "Updates empty state when nothing is installed",
            )
        case 1:
            return String(
                localized: "Your installed package is at its latest version.",
                comment: "Updates empty state for a single installed package",
            )
        default:
            return String(
                localized: "All \(total) packages are at their latest versions.",
                comment: "Updates empty state with total installed count",
            )
        }
    }

    private var noSearchMatchesSubtitle: String {
        let hidden = viewModel.totalOutdatedCount
        if hidden == 1 {
            return String(
                localized: "1 outdated package is hidden by the current search.",
                comment: "Updates search-empty state with a single hidden outdated package",
            )
        }
        return String(
            localized: "\(hidden) outdated packages are hidden by the current search.",
            comment: "Updates search-empty state with multiple hidden outdated packages",
        )
    }

    private var loadingSkeletonList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                InstalledSectionHeader(title: "Formulae", count: 2)
                ForEach(loadingFormulaeRows) { package in
                    InstalledListRowRoot(package: package)
                }
            }
            .padding(.horizontal, BrewSpacing.lg)
            .padding(.bottom, BrewSpacing.xl)
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityLabel("Loading available updates")
    }

    private var loadingFormulaeRows: [InstalledBrewPackage] {
        Array(repeating: Self.loadingPlaceholder, count: 2)
    }

    private static let loadingPlaceholder = InstalledBrewPackage(
        package: BrewPackage(
            name: "Placeholder Formula",
            displayName: "Placeholder Formula",
            kind: .formula,
            description: "Placeholder description text for loading row.",
            homepage: "",
            latestVersion: "0.0.0",
            dependencies: [],
        ),
        installedVersions: ["0.0.0"],
        outdated: true,
    )

    private func errorView(_ message: String) -> some View {
        Text(message)
            .font(.brewCallout)
            .foregroundStyle(Color.brewStatusError)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, BrewSpacing.lg)
            .padding(.bottom, BrewSpacing.sm)
            .accessibilityLabel(message)
    }
}

#if DEBUG

    #Preview("Updates list - loaded") {
        let viewModel = UpdatesViewModel(
            repository: PreviewSupport.makeInstalledPackagesRepository(),
            brewCommandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
        UpdatesPackagesView(viewModel: viewModel)
            .environment(\.brewCommandCenter, PreviewSupport.commandCenter)
            .task {
                await viewModel.load()
            }
            .frame(minWidth: 360, minHeight: 500)
    }

    #Preview("Updates list - empty") {
        let viewModel = UpdatesViewModel(
            repository: StubInstalledPackagesRepository(packages: [
                PreviewSupport.currentCask,
            ]),
            brewCommandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
        UpdatesPackagesView(viewModel: viewModel)
            .environment(\.brewCommandCenter, PreviewSupport.commandCenter)
            .task {
                await viewModel.load()
            }
            .frame(minWidth: 360, minHeight: 500)
    }
#endif
