//
//  PaneField.swift
//  BrewUIComponents
//

import Foundation

/// Focus regions inside a feature pane. Each feature owns one `@FocusState var field: PaneField?`,
/// used to route `Cmd+F` to the search field, return Escape to the list, and gate which `.onKeyPress`
/// handlers fire (e.g. arrow keys behave differently when search has focus).
public enum PaneField: Hashable, Sendable {
    case search
    case list
    case detail
}
