//
//  PaneActions.swift
//  BrewUIComponents
//

import SwiftUI

/// Published per-pane via `focusedSceneValue(\.activePaneActions, …)` and consumed by the global
/// View-menu commands so `Cmd+R`, `Cmd+F`, `Cmd+Return`, `Cmd+Backspace`, `Cmd+C` dispatch into
/// whichever pane is currently focused. Closures are optional — the menu items disable themselves
/// when an action isn't applicable in the active pane.
public struct PaneActions {
    public var primaryAction: (() -> Void)?
    public var primaryActionTitle: String?
    public var destructiveAction: (() -> Void)?
    public var destructiveActionTitle: String?
    public var refresh: (() -> Void)?
    public var focusSearch: (() -> Void)?
    public var clearSelection: (() -> Void)?
    public var copySelectionName: (() -> Void)?

    public init(
        primaryAction: (() -> Void)? = nil,
        primaryActionTitle: String? = nil,
        destructiveAction: (() -> Void)? = nil,
        destructiveActionTitle: String? = nil,
        refresh: (() -> Void)? = nil,
        focusSearch: (() -> Void)? = nil,
        clearSelection: (() -> Void)? = nil,
        copySelectionName: (() -> Void)? = nil,
    ) {
        self.primaryAction = primaryAction
        self.primaryActionTitle = primaryActionTitle
        self.destructiveAction = destructiveAction
        self.destructiveActionTitle = destructiveActionTitle
        self.refresh = refresh
        self.focusSearch = focusSearch
        self.clearSelection = clearSelection
        self.copySelectionName = copySelectionName
    }
}

public extension FocusedValues {
    /// The pane-scoped action set published by the currently focused feature column. `nil` when no
    /// pane has registered (e.g. the Configuration tab, or before first appearance).
    @Entry var activePaneActions: PaneActions?
}
