//
//  SidebarItem.swift
//  Homebrew
//
//  Created by Graeme Arthur on 17/6/2026.
//

import BrewAccessibilityID
import SwiftUI

/// Primary navigation items for the main window sidebar.
enum SidebarItem: String, CaseIterable, Hashable, Identifiable {
    case installed
    case services
    case upgrades
    case discover
    case doctor
    case configuration

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .installed: String(localized: "Installed", bundle: #bundle, comment: "Sidebar: installed packages")
        case .services: String(localized: "Services", bundle: #bundle, comment: "Sidebar: read-only Homebrew service inventory")
        case .upgrades: String(localized: "Upgrades", bundle: #bundle, comment: "Sidebar: outdated packages")
        case .discover: String(localized: "Discover", bundle: #bundle, comment: "Sidebar: browse and search the catalog")
        case .doctor: String(localized: "Doctor", bundle: #bundle, comment: "Sidebar: brew doctor diagnostics")
        case .configuration: String(localized: "Configuration", bundle: #bundle, comment: "Sidebar: brew config and environment")
        }
    }

    var refreshesDoctorReport: Bool {
        switch self {
        case .doctor: true
        case .installed, .services, .upgrades, .discover, .configuration: false
        }
    }

    /// Test-facing identity for this destination. Kept as an explicit mapping rather than a
    /// `rawValue` bridge so renaming a case here can never silently repoint a UI test.
    var axDestination: AXID.SidebarDestination {
        switch self {
        case .installed: .installed
        case .services: .services
        case .upgrades: .upgrades
        case .discover: .discover
        case .doctor: .doctor
        case .configuration: .configuration
        }
    }
}

extension FocusedValues {
    @Entry var sidebarSelection: Binding<SidebarItem>?
}

/// View menu commands for navigating the main window sidebar (⌘1–⌘6).
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
