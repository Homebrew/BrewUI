//
//  RefreshCommands.swift
//  BrewUIComponents
//

import SwiftUI

/// ⌘R for the whole window. The window publishes what refreshing means via ``FocusedValues/refreshAll``.
public struct RefreshCommands: Commands {
    @FocusedValue(\.refreshAll) private var refreshAll

    public init() {}

    public var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button("Refresh") { refreshAll?() }
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
