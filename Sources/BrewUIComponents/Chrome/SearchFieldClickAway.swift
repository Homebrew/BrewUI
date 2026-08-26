import AppKit
import SwiftUI

public extension View {
    /// Runs `action` for a click anywhere in the app that did not land in the toolbar search field.
    ///
    /// Focus is not a good enough signal on its own: clicking a list row moves `@FocusState`, but
    /// clicking a header, a picker or empty space moves nothing, so the field would keep the keyboard
    /// with no way for the user to see why.
    func onClickOutsideSearchField(perform action: @escaping @MainActor () -> Void) -> some View {
        modifier(ClickOutsideSearchFieldModifier(action: action))
    }
}

private struct ClickOutsideSearchFieldModifier: ViewModifier {
    let action: @MainActor () -> Void

    @State private var monitor = OutsideSearchFieldClickMonitor()

    func body(content: Content) -> some View {
        content
            .onAppear { monitor.start(action) }
            .onDisappear { monitor.stop() }
    }
}

@MainActor
private final class OutsideSearchFieldClickMonitor {
    private var token: Any?

    func start(_ action: @escaping @MainActor () -> Void) {
        stop()
        token = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            if !SearchFieldClickAway.isInsideSearchField(event) {
                // AppKit delivers local monitors on the main thread; the closure's type can't say so.
                // swiftlint:disable:next assume_isolated
                MainActor.assumeIsolated { action() }
            }
            return event
        }
    }

    func stop() {
        if let token {
            NSEvent.removeMonitor(token)
        }
        token = nil
    }
}

/// Where a click landed relative to the toolbar search field.
enum SearchFieldClickAway {
    static func isInsideSearchField(_ event: NSEvent) -> Bool {
        isInsideSearchField(clickedView(for: event))
    }

    /// The field editor and the toolbar item's own chrome both sit under the `NSSearchField`, so the
    /// ancestor walk covers a click on the text, the magnifier and the cancel button alike.
    static func isInsideSearchField(_ view: NSView?) -> Bool {
        var node = view
        while let current = node {
            if current is NSSearchField {
                return true
            }
            node = current.superview
        }
        return false
    }

    /// Hit-tested from the theme frame rather than the content view: the search field lives in the
    /// window's title bar, which is not part of the content view's tree.
    private static func clickedView(for event: NSEvent) -> NSView? {
        guard let window = event.window else {
            return nil
        }
        let root = window.contentView?.superview ?? window.contentView
        return root?.hitTest(event.locationInWindow)
    }
}
