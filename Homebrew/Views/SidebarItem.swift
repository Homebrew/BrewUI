//
//  SidebarItem.swift
//  Homebrew
//
//  Created by Graeme Arthur on 17/6/2026.
//

import SwiftUI

/// Primary navigation items for the main window sidebar.
enum SidebarItem: String, CaseIterable, Hashable, Identifiable {
    case installed
    case upgrades
    case discover
    case doctor
    case configuration

    var id: String {
        rawValue
    }

    var title: LocalizedStringKey {
        switch self {
        case .installed: "Installed"
        case .upgrades: "Upgrades"
        case .discover: "Discover"
        case .doctor: "Doctor"
        case .configuration: "Configuration"
        }
    }
}

extension FocusedValues {
    @Entry var sidebarSelection: Binding<SidebarItem>?
}

/// View menu commands for navigating the main window sidebar (⌘1–⌘5).
public struct SidebarCommands: Commands {
    @FocusedValue(\.sidebarSelection) private var selection

    public init() {}

    public var body: some Commands {
        CommandGroup(after: .sidebar) {
            ForEach(Array(SidebarItem.allCases.enumerated()), id: \.element) { index, item in
                Button(item.title) {
                    selection?.wrappedValue = item
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
            }
            .disabled(selection == nil)
        }
    }
}
