//
//  SearchCommands.swift
//  BrewKit
//
//

import SwiftUI

public struct SearchCommands: Commands {
    @FocusedValue(\.focusSearchField) private var focusSearchField

    public init() {}

    public var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Find") { focusSearchField?() }
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
