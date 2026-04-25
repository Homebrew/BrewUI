//
//  ContentView.swift
//  Brew
//
//  Created by Graeme Arthur on 6/3/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem = .installed
    @State private var installedViewModel: InstalledViewModel

    init() {
        _installedViewModel = State(
            initialValue: InstalledViewModel(repository: BrewInstalledPackagesRepository.live()),
        )
    }

    init(installedViewModel: InstalledViewModel) {
        _installedViewModel = State(initialValue: installedViewModel)
    }

    var body: some View {
        NavigationSplitView {
            ShellSidebarView(selection: $selectedSidebarItem)
                .navigationSplitViewColumnWidth(
                    min: BrewLayout.sidebarWidth,
                    ideal: BrewLayout.sidebarWidth,
                    max: BrewLayout.sidebarWidth + 40,
                )
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .frame(
            minWidth: BrewLayout.minWindowWidth,
            minHeight: BrewLayout.minWindowHeight,
        )
        .background(.bar)
        .task(id: selectedSidebarItem) {
            if selectedSidebarItem == .installed {
                await installedViewModel.load()
            }
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch selectedSidebarItem {
        case .installed:
            InstalledShellView(viewModel: installedViewModel)
                .navigationSplitViewColumnWidth(
                    min: BrewLayout.installedListColumnMinWidth,
                    ideal: BrewLayout.installedListColumnIdealWidth,
                    max: BrewLayout.installedListColumnMaxWidth,
                )
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch selectedSidebarItem {
        case .installed:
            Group {
                if let row = installedViewModel.selectedPackageRow {
                    InstalledPackageDetailView(row: row)
                } else {
                    InstalledPackageDetailPlaceholder()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationSplitViewColumnWidth(
                min: BrewLayout.inspectorWidth,
                ideal: BrewLayout.installedDetailColumnIdealWidth,
                max: BrewLayout.installedDetailColumnMaxWidth,
            )
        }
    }
}

#Preview {
    ContentView(
        installedViewModel: InstalledViewModel(
            previewFormulae: InstalledViewModelDummyData.formulae,
            previewCasks: InstalledViewModelDummyData.casks,
        ),
    )
}
