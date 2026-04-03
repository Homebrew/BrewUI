//
//  ContentView.swift
//  Brew
//
//  Created by Graeme Arthur on 6/3/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem = .installed

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
        .background(Color.brewWindowBase)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSidebarItem {
        case .installed:
            InstalledShellView()
        }
    }
}

#Preview {
    ContentView()
}
