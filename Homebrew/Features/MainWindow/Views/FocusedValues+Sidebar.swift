//
//  FocusedValues+Sidebar.swift
//  Brew
//

import SwiftUI

extension FocusedValues {
    /// Per-window binding to the sidebar's current selection. Published by ``MainWindowView`` via
    /// `focusedSceneValue` and consumed by ``SidebarCommands`` so `⌘1`–`⌘4` switch panes from anywhere.
    @Entry var selectedSidebarItem: Binding<SidebarItem>?
}
