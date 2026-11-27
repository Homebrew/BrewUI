import AppKit
import SwiftUI

/// A stable AppKit search field for the window toolbar. SwiftUI's `.searchable` changes its
/// internal toolbar representation while a feature changes, which briefly duplicates its glyph.
struct ToolbarSearchField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let prompt: String
    let focusRequest: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        field.setAccessibilityLabel(prompt)
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderString = prompt
        field.setAccessibilityLabel(prompt)

        if !isFocused,
           let window = field.window,
           window.firstResponder === field.currentEditor() || window.firstResponder === field
        {
            window.makeFirstResponder(nil)
        }

        guard context.coordinator.focusRequest != focusRequest else {
            return
        }
        context.coordinator.focusRequest = focusRequest
        Task { @MainActor in
            field.window?.makeFirstResponder(field.currentEditor() ?? field)
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: ToolbarSearchField
        var focusRequest = 0

        init(_ parent: ToolbarSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else {
                return
            }
            parent.text = field.stringValue
        }

        func controlTextDidBeginEditing(_: Notification) {
            parent.isFocused = true
        }

        func controlTextDidEndEditing(_: Notification) {
            parent.isFocused = false
        }
    }
}
