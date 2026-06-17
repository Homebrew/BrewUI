//
//  InstalledPackagesView.swift
//  Brew
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Middle column of the main window: “Installed” chrome and the package list.
struct InstalledPackagesView: View {
    @Bindable var viewModel: InstalledViewModel
    @State private var searchPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Your packages")
                    .font(.brewTitle2)
                    .foregroundStyle(Color.brewTextPrimary)
                Text(viewModel.packageCountSubtitle)
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrewSpacing.lg)
            .accessibilityElement(children: .combine)
            .accessibilityHeading(.h1)

            AsyncContentView(
                state: viewModel.state,
                onRetry: { Task { await viewModel.refresh() } },
                loaded: { content in
                    installedList(content)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                },
            )
        }
        .searchable(
            text: $viewModel.searchQuery,
            isPresented: $searchPresented,
            placement: .toolbar,
            prompt: "Search Installed Packages",
        )
        .focusedSceneValue(\.searchPresented, $searchPresented)
    }

    private func installedList(_ content: InstalledPackagesContent) -> some View {
        ScrollViewReader { proxy in
            List(selection: Binding(
                get: { viewModel.activeSelectedPackageID },
                set: { newValue in
                    if let newValue {
                        viewModel.setSelection(newValue)
                    } else {
                        viewModel.clearSelection()
                    }
                },
            )) {
                if content.shouldShowFormulaeSection {
                    Section("Formulae") {
                        sectionContent(for: content.formulaPackages)
                    }
                }

                if content.shouldShowCasksSection {
                    Section("Casks") {
                        sectionContent(for: content.caskPackages)
                    }
                }
            }
            .listStyle(.inset)
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

    private func sectionContent(for packages: [InstalledBrewPackage]) -> some View {
        ForEach(packages) { package in
            listRow(for: package)
                .id(package.id)
                .contentShape(Rectangle())
                .listRowBackground(
                    viewModel.activeSelectedPackageID == package.id ? Color.brewBrandTint : Color.clear,
                )
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
}

#if DEBUG

    #Preview("Installed list - loaded") {
        let viewModel = InstalledViewModel(repository: PreviewSupport.makeInstalledPackagesRepository())
        InstalledPackagesView(
            viewModel: viewModel,
        )
        .environment(\.brewCommandCenter, PreviewSupport.commandCenter)
        .task {
            await viewModel.load()
        }
        .frame(minWidth: 360, minHeight: 500)
    }

    #Preview("Installed list - empty") {
        let viewModel = InstalledViewModel(
            repository: PreviewSupport.makeInstalledPackagesRepository(packages: PreviewSupport.emptyPackages),
        )
        InstalledPackagesView(
            viewModel: viewModel,
        )
        .environment(\.brewCommandCenter, PreviewSupport.commandCenter)
        .task {
            await viewModel.load()
        }
        .frame(minWidth: 360, minHeight: 500)
    }
#endif
