/*
 * [INPUT]: 依赖 SwiftUI FocusedValues 的窗口动作与显式 AppLocalization 快照
 * [OUTPUT]: 提供SearchCommands及对应焦点动作环境
 * [POS]: 原生菜单展示边界；语言由应用注入，动作仍路由至当前焦点窗口
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  SearchCommands.swift
//  BrewKit
//
//

import SwiftUI

public struct SearchCommands: Commands {
    @FocusedValue(\.focusSearchField) private var focusSearchField

    private let localization: AppLocalization

    public init(localization: AppLocalization = AppLocalization()) {
        self.localization = localization
    }

    public var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button(localization.string("Find")) { focusSearchField?() }
                .keyboardShortcut("f") // ⌘F
                .disabled(focusSearchField == nil)
        }
    }
}

/// An action, not a `Binding<Bool>`: re-setting an already-`true` binding moves nothing.
public struct FocusSearchFieldAction {
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
    @Entry var focusSearchField: FocusSearchFieldAction?
}
