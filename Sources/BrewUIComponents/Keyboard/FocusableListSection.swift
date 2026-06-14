//
//  FocusableListSection.swift
//  BrewUIComponents
//

import SwiftUI

/// Decision returned by ``nextFocus(after:in:canExpand:)`` and ``previousFocus(before:in:)``. Pure
/// data so callers can unit-test traversal without spinning up SwiftUI.
public enum FocusAdvance<ID: Equatable>: Equatable {
    case move(ID)
    case expand
    case stay
}

/// Determine the next focus target inside a sub-list. When the focused row is the last in
/// `orderedIDs` and `canExpand` is true, returns ``FocusAdvance/expand`` so the caller can expand a
/// collapsed section and then place focus on the now-visible row. Otherwise clamps with ``stay``.
public func nextFocus<ID: Equatable>(
    after current: ID?,
    in orderedIDs: [ID],
    canExpand: Bool,
) -> FocusAdvance<ID> {
    guard !orderedIDs.isEmpty else { return .stay }
    guard let current, let index = orderedIDs.firstIndex(of: current) else {
        return orderedIDs.first.map(FocusAdvance.move) ?? .stay
    }
    let nextIndex = orderedIDs.index(after: index)
    if nextIndex < orderedIDs.endIndex {
        return .move(orderedIDs[nextIndex])
    }
    return canExpand ? .expand : .stay
}

/// Determine the previous focus target inside a sub-list. Clamps at the first row.
public func previousFocus<ID: Equatable>(
    before current: ID?,
    in orderedIDs: [ID],
) -> FocusAdvance<ID> {
    guard !orderedIDs.isEmpty else { return .stay }
    guard let current, let index = orderedIDs.firstIndex(of: current) else {
        return orderedIDs.last.map(FocusAdvance.move) ?? .stay
    }
    guard index > orderedIDs.startIndex else { return .stay }
    return .move(orderedIDs[orderedIDs.index(before: index)])
}

public extension View {
    /// Install arrow-key navigation for a sub-list inside a focusable section. The caller owns the
    /// `@FocusState` and wires each row with ``focused(_:equals:)``; this modifier handles the
    /// Up/Down decisions against `orderedIDs`. Arrow keys are only consumed when one of the
    /// section's rows is currently focused, so the outer pane's arrow handling still works.
    ///
    /// - Parameter onDownPastLast: optional. Invoked when Down is pressed on the last row of a
    ///   collapsible section; should expand the section and return the row ID that focus should
    ///   land on next. Pass `nil` for sections that should clamp at the end.
    func focusableListSection<ID: Hashable>(
        orderedIDs: [ID],
        focusedRow: FocusState<ID?>.Binding,
        onDownPastLast: (() -> ID?)? = nil,
    ) -> some View {
        modifier(FocusableListSectionModifier(
            orderedIDs: orderedIDs,
            focusedRow: focusedRow,
            onDownPastLast: onDownPastLast,
        ))
    }
}

private struct FocusableListSectionModifier<ID: Hashable>: ViewModifier {
    let orderedIDs: [ID]
    let focusedRow: FocusState<ID?>.Binding
    let onDownPastLast: (() -> ID?)?

    func body(content: Content) -> some View {
        content
            .onKeyPress(.downArrow) {
                guard focusedRow.wrappedValue != nil else { return .ignored }
                switch nextFocus(
                    after: focusedRow.wrappedValue,
                    in: orderedIDs,
                    canExpand: onDownPastLast != nil,
                ) {
                case let .move(id):
                    focusedRow.wrappedValue = id
                case .expand:
                    guard let onDownPastLast, let nextID = onDownPastLast() else {
                        return .handled
                    }
                    // Defer so the newly-visible row exists before focus is assigned.
                    Task { @MainActor in
                        focusedRow.wrappedValue = nextID
                    }
                case .stay:
                    break
                }
                return .handled
            }
            .onKeyPress(.upArrow) {
                guard focusedRow.wrappedValue != nil else { return .ignored }
                if case let .move(id) = previousFocus(
                    before: focusedRow.wrappedValue,
                    in: orderedIDs,
                ) {
                    focusedRow.wrappedValue = id
                }
                return .handled
            }
    }
}
