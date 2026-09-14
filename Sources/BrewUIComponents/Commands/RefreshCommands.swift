/*
 * [INPUT]: 依赖 SwiftUI FocusedValues 的窗口动作与显式 AppLocalization 快照
 * [OUTPUT]: 提供RefreshCommands及对应焦点动作环境
 * [POS]: 原生菜单展示边界；语言由应用注入，动作仍路由至当前焦点窗口
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  RefreshCommands.swift
//  BrewUIComponents
//

import SwiftUI

/// ⌘R for the whole window. The window publishes what refreshing means via ``FocusedValues/refreshAll``.
public struct RefreshCommands: Commands {
    @FocusedValue(\.refreshAll) private var refreshAll

    private let localization: AppLocalization

    public init(localization: AppLocalization = AppLocalization()) {
        self.localization = localization
    }

    public var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button(localization.string("Refresh")) { refreshAll?() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(refreshAll == nil)
        }
    }
}

/// An action, not a `Binding<Bool>`: re-setting an already-`true` binding moves nothing.
public struct RefreshAllAction {
    private let handler: @MainActor () -> Void

    public init(_ handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }

    @MainActor
    public func callAsFunction() {
        handler()
    }
}

public extension FocusedValues {
    @Entry var refreshAll: RefreshAllAction?
}
