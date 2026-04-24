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
        } detail: {
            detailContent
        }
        .frame(
            minWidth: BrewLayout.minWindowWidth,
            minHeight: BrewLayout.minWindowHeight,
        )
        .background(.bar)
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSidebarItem {
        case .installed:
            InstalledShellView(viewModel: installedViewModel)
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
