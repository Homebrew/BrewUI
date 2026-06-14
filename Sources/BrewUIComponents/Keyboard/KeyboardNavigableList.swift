//
//  KeyboardNavigableList.swift
//  BrewUIComponents
//

import SwiftUI

public extension View {
    /// Install arrow-key navigation, plus an optional `Return` handler for the primary action, on the
    /// view this is applied to. The view becomes `focusable`; arrow keys call `selectPrevious` /
    /// `selectNext` on the supplied `ListNavigable`.
    ///
    /// Apply this to the list container (the `ScrollViewReader` / `List` parent) — not to individual
    /// rows. The caller is responsible for `@FocusState` binding (use ``focused(_:equals:)`` with a
    /// ``PaneField`` after this modifier if needed).
    func keyboardListNavigation(
        _ navigable: some ListNavigable,
        onPrimary: (() -> Void)? = nil,
    ) -> some View {
        modifier(KeyboardListNavigationModifier(
            selectPrevious: { navigable.selectPrevious() },
            selectNext: { navigable.selectNext() },
            selectFirst: { navigable.selectFirst() },
            selectLast: { navigable.selectLast() },
            onPrimary: onPrimary,
        ))
    }

    /// Forward `up`/`down` arrow key presses to the supplied list navigable when `isActive` is true.
    /// Used to wire the `.searchable` text field so arrow keys move the list selection while the user
    /// is typing — mirrors Mail/Finder behaviour.
    func forwardArrowKeysToList(
        _ navigable: some ListNavigable,
        isActive: Bool,
    ) -> some View {
        modifier(ArrowKeyForwardModifier(
            isActive: isActive,
            selectPrevious: { navigable.selectPrevious() },
            selectNext: { navigable.selectNext() },
        ))
    }
}

private struct KeyboardListNavigationModifier: ViewModifier {
    let selectPrevious: () -> Void
    let selectNext: () -> Void
    let selectFirst: () -> Void
    let selectLast: () -> Void
    let onPrimary: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .focusable(true)
            .onKeyPress(.upArrow) {
                selectPrevious()
                return .handled
            }
            .onKeyPress(.downArrow) {
                selectNext()
                return .handled
            }
            .onKeyPress(.home) {
                selectFirst()
                return .handled
            }
            .onKeyPress(.end) {
                selectLast()
                return .handled
            }
            .onKeyPress(.return) {
                guard let onPrimary else { return .ignored }
                onPrimary()
                return .handled
            }
    }
}

private struct ArrowKeyForwardModifier: ViewModifier {
    let isActive: Bool
    let selectPrevious: () -> Void
    let selectNext: () -> Void

    func body(content: Content) -> some View {
        content
            .onKeyPress(.upArrow) {
                guard isActive else { return .ignored }
                selectPrevious()
                return .handled
            }
            .onKeyPress(.downArrow) {
                guard isActive else { return .ignored }
                selectNext()
                return .handled
            }
    }
}
