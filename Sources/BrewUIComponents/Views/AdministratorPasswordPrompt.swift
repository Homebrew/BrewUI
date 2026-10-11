import AppKit
import Foundation

/// An unprivileged BrewUI prompt. Only sudo validates the returned password.
@MainActor
public final class AdministratorPasswordPrompt {
    let alert = NSAlert()
    let passwordField = NSSecureTextField()

    public init() {
        alert.messageText = String(localized: "BrewUI administrator authentication", bundle: #bundle, comment: "Askpass: title identifying BrewUI as the requester")
        alert.informativeText = String(
            localized: "Homebrew needs administrator permission to continue. Enter your password for sudo.",
            bundle: #bundle,
            comment: "Askpass: explains why Homebrew requests an administrator password",
        )
        alert.addButton(withTitle: String(localized: "Authenticate", bundle: #bundle, comment: "Askpass: submit the password to sudo"))
        alert.addButton(withTitle: String(localized: "Cancel", bundle: #bundle, comment: "Askpass: cancel administrator authentication"))
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = "\u{1b}"
        let label = String(localized: "Administrator password", bundle: #bundle, comment: "Askpass: secure password field label")
        passwordField.placeholderString = label
        passwordField.setAccessibilityLabel(label)
        passwordField.frame.size = NSSize(width: BrewLayout.inspectorWidth, height: passwordField.intrinsicContentSize.height)
        alert.accessoryView = passwordField
        alert.window.initialFirstResponder = passwordField
    }

    /// Blocks until submission or cancellation; the caller must keep stdout private for sudo.
    public func run() -> String? {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.activate(ignoringOtherApps: true)
        return response(for: alert.runModal())
    }

    func response(for result: NSApplication.ModalResponse) -> String? {
        defer { passwordField.stringValue = "" }
        guard result == .alertFirstButtonReturn, !passwordField.stringValue.isEmpty else {
            return nil
        }
        return passwordField.stringValue
    }
}
