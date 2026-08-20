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

/// An action rather than a `Binding<Bool>`: `.searchable(isPresented:)` tracks presentation, not
/// focus, and a macOS toolbar field stays presented after the cursor leaves it — so setting that
/// binding `true` again was no state change and moved nothing. Panes drive `.searchFocused` instead.
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
    /// Published by whichever pane owns a search field; invoked by ``SearchCommands`` on ⌘F.
    @Entry var focusSearchField: FocusSearchFieldAction?
}
