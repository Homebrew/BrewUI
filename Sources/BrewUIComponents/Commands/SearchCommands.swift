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

/// What ⌘F does to the pane that publishes it.
///
/// An action rather than the `Binding<Bool>` this used to be. `.searchable(isPresented:)` tracks
/// *presentation*, not focus: a macOS toolbar search field stays presented after the cursor leaves
/// it, so writing `true` over an already-`true` binding was not a state change and SwiftUI did
/// nothing with it — ⌘F went dead once the field had been shown. Panes implement this by driving a
/// real `@FocusState` through `.searchFocused(_:)`, which cannot fall out of step with the cursor.
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
