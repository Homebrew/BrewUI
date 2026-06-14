//
//  ListNavigable.swift
//  BrewUIComponents
//

import Foundation

/// Adopted by view models that drive an ordered, single-selection list. Provides default `selectNext` /
/// `selectPrevious` / `selectFirst` / `selectLast` that clamp at the ends — sections inside a pane
/// flow naturally (e.g. Formulae → Casks) but the global ends do not wrap.
@MainActor
public protocol ListNavigable: AnyObject {
    associatedtype RowID: Hashable

    /// Row identifiers in display order, flattened across any sections.
    var orderedVisibleRowIDs: [RowID] { get }

    /// The currently selected row, if any.
    var currentSelectionID: RowID? { get }

    /// Mutate the selection. Implementations should funnel through their existing selection setter so
    /// side-effects (scroll-into-view, search commit, etc.) continue to fire.
    func setSelection(_ id: RowID?)
}

public extension ListNavigable {
    /// Move to the next row. If nothing is selected, selects the first row. Clamps at the end.
    func selectNext() {
        let ids = orderedVisibleRowIDs
        guard !ids.isEmpty else { return }

        guard let current = currentSelectionID,
              let index = ids.firstIndex(of: current)
        else {
            setSelection(ids.first)
            return
        }

        let nextIndex = ids.index(after: index)
        guard nextIndex < ids.endIndex else { return }
        setSelection(ids[nextIndex])
    }

    /// Move to the previous row. If nothing is selected, selects the last row. Clamps at the start.
    func selectPrevious() {
        let ids = orderedVisibleRowIDs
        guard !ids.isEmpty else { return }

        guard let current = currentSelectionID,
              let index = ids.firstIndex(of: current)
        else {
            setSelection(ids.last)
            return
        }

        guard index > ids.startIndex else { return }
        setSelection(ids[ids.index(before: index)])
    }

    func selectFirst() {
        setSelection(orderedVisibleRowIDs.first)
    }

    func selectLast() {
        setSelection(orderedVisibleRowIDs.last)
    }
}
