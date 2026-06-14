//
//  InstalledPackagesView.swift
//  Brew
//

import AppKit
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Middle column of the main window: “Installed” chrome and the package list.
struct InstalledPackagesView: View {
    @Bindable var viewModel: InstalledViewModel
    @FocusState private var field: PaneField?

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
            placement: .toolbar,
            prompt: "Search Installed Packages",
        )
        .searchFocused($field, equals: .search)
        .focusedSceneValue(\.activePaneActions, paneActions)
    }

    private var paneActions: PaneActions {
        PaneActions(
            refresh: { Task { await viewModel.refresh() } },
            focusSearch: { field = .search },
            clearSelection: {
                if field == .search {
                    viewModel.searchQuery = ""
                    field = .list
                } else {
                    viewModel.clearSelection()
                }
            },
            copySelectionName: viewModel.copyableSelectedPackageName().map { name in
                { Self.copyToPasteboard(name) }
            },
        )
    }

    private static func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
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
            .listStyle(.inset)
            .accessibilityLabel("Installed packages")
            .keyboardListNavigation(viewModel)
            .focused($field, equals: .list)
            .onAppear {
                scrollToSelection(viewModel.activeSelectedPackageID, in: content, with: proxy)
                if field == nil {
                    field = .list
                }
            }
            .onChange(of: viewModel.activeSelectedPackageID) { _, selectedID in
                scrollToSelection(selectedID, in: content, with: proxy)
            }
            .onChange(of: content.packages.map(\.id)) { _, _ in
                scrollToSelection(viewModel.activeSelectedPackageID, in: content, with: proxy)
            }
            .onExitCommand {
                if field == .search {
                    viewModel.searchQuery = ""
                    field = .list
                } else {
                    viewModel.clearSelection()
                }
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
