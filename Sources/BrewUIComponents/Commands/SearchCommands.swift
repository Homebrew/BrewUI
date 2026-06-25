//
//  SearchCommands.swift
//  BrewKit
//
//

import SwiftUI

public struct SearchCommands: Commands {
    @FocusedValue(\.searchPresented) private var searchPresented

    public init() {}

    public var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Find") { searchPresented?.wrappedValue = true }
                .keyboardShortcut("f") // ⌘F
                .disabled(searchPresented == nil)
        }
    }
}

public extension FocusedValues {
    @Entry var searchPresented: Binding<Bool>?
}
