//
//  InstalledPackagesView.swift
//  Brew
//

import SwiftUI

/// Middle column of the main window: “Installed” chrome and the package list.
struct InstalledPackagesView: View {
    @Bindable var viewModel: InstalledViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Installed")
                    .font(.brewTitle1)
                    .foregroundStyle(Color.brewTextPrimary)
                Text(viewModel.packageCountSubtitle)
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrewSpacing.lg)
            .accessibilityElement(children: .combine)
            .accessibilityHeading(.h1)

            switch viewModel.state {
            case .loading:
                loadingSkeletonList
            case let .error(message):
                errorView(message)
            case let .loaded(content):
                installedList(content)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .searchable(
            text: $viewModel.searchQuery,
            isPresented: $viewModel.isSearchSelected,
            placement: .toolbar,
            prompt: "Search",
        )
    }

    private func installedList(_ content: InstalledPackagesContent) -> some View {
        List {
            if content.shouldShowFormulaeSection {
                Section("Formulae") {
                    ForEach(content.formulaPackages) { package in
                        listRow(for: package)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleSelection(for: package.id)
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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleSelection(for: package.id)
                            }
                            .listRowBackground(
                                viewModel.activeSelectedPackageID == package.id ? Color.brewBrandTint : Color.clear,
                            )
                    }
                }
            }
        }
        .listStyle(.plain)
        .accessibilityLabel("Installed packages")
        .onExitCommand {
            viewModel.clearSelection()
        }
    }

    private func listRow(for package: BrewPackage) -> some View {
        InstalledListRowRoot(package: package)
    }

    private var loadingSkeletonList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                InstalledSectionHeader(title: "Formulae", count: 3)
                ForEach(loadingFormulaeRows) { package in
                    InstalledListRowRoot(package: package)
                }
            }
            .padding(.horizontal, BrewSpacing.lg)
            .padding(.bottom, BrewSpacing.xl)
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityLabel("Loading package list")
    }

    private var loadingFormulaeRows: [BrewPackage] {
        [
            BrewPackage(
                name: "Placeholder Formula",
                kind: .formula,
                description: "Placeholder description text for loading row.",
                latestVersion: "0.0.0",
                installedVersions: ["0.0.0"],
                dependencies: [],
                outdated: false,
            ),
            BrewPackage(
                name: "Placeholder Formula",
                kind: .formula,
                description: "Placeholder description text for loading row.",
                latestVersion: "0.0.0",
                installedVersions: ["0.0.0"],
                dependencies: [],
                outdated: false,
            ),
            BrewPackage(
                name: "Placeholder Formula",
                kind: .formula,
                description: "Placeholder description text for loading row.",
                latestVersion: "0.0.0",
                installedVersions: ["0.0.0"],
                dependencies: [],
                outdated: false,
            ),
        ]
    }

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
