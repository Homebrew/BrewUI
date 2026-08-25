/// The two regions of a searchable screen that compete for the keyboard.
public enum SearchFocusTarget: Hashable, Sendable {
    case list
    case searchField
}

/// Decides which region of a searchable screen holds the keyboard.
///
/// The list and the toolbar search field previously drove independent `@FocusState`s, so ⌘F could
/// resign the list in the same turn it asked a not-yet-presented search field to take over. Nothing
/// held the keyboard, and no further event re-fired, so the shortcut appeared dead until pressed
/// again. Routing both through one target makes that gap unrepresentable: a claim is only ever
/// handed over once the receiver can accept it.
public struct SearchFocusArbiter: Equatable, Sendable {
    public private(set) var target: SearchFocusTarget?
    public private(set) var isSearchFieldPresented: Bool

    /// ⌘F arrived before the field was in the toolbar, so the claim waits rather than being dropped.
    private(set) var isSearchFocusPending = false

    public init(
        target: SearchFocusTarget? = nil,
        isSearchFieldPresented: Bool = false,
    ) {
        self.target = target
        self.isSearchFieldPresented = isSearchFieldPresented
    }

    public mutating func requestSearchFocus() {
        guard isSearchFieldPresented else {
            isSearchFieldPresented = true
            isSearchFocusPending = true
            return
        }
        target = .searchField
        isSearchFocusPending = false
    }

    public mutating func searchFieldDidPresent() {
        isSearchFieldPresented = true
        guard isSearchFocusPending else {
            return
        }
        target = .searchField
        isSearchFocusPending = false
    }

    public mutating func searchFieldDidDismiss() {
        isSearchFieldPresented = false
        isSearchFocusPending = false
        if target == .searchField {
            target = .list
        }
    }

    public mutating func emptySearchFieldDidLoseFocus() {
        guard !isSearchFocusPending else {
            return
        }
        searchFieldDidDismiss()
    }

    public mutating func contentDidLoad() {
        guard target == nil, !isSearchFocusPending else {
            return
        }
        target = .list
    }

    public mutating func focusDidChange(to target: SearchFocusTarget?) {
        guard let target else {
            return
        }
        self.target = target
        if target == .searchField {
            isSearchFocusPending = false
        }
    }
}
