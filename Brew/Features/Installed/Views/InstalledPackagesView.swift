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
            .accessibilityLabel("Installed packages")
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

    private var loadingFormulaeRows: [InstalledBrewPackage] {
        [
            InstalledBrewPackage(
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
                outdated: false,
            ),
            InstalledBrewPackage(
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
                outdated: false,
            ),
            InstalledBrewPackage(
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

#Preview("Installed list - loaded") {
    let viewModel = AppPreviewSupport.makeInstalledViewModel()
    InstalledPackagesView(
        viewModel: viewModel,
    )
    .environment(\.brewCommandCenter, AppPreviewSupport.commandCenter)
    .task {
        await viewModel.load()
    }
    .frame(minWidth: 360, minHeight: 500)
}

#Preview("Installed list - empty") {
    let viewModel = AppPreviewSupport.makeInstalledViewModel(
        packages: AppPreviewSupport.emptyPackages,
    )
    InstalledPackagesView(
        viewModel: viewModel,
    )
    .environment(\.brewCommandCenter, AppPreviewSupport.commandCenter)
    .task {
        await viewModel.load()
    }
    .frame(minWidth: 360, minHeight: 500)
}
