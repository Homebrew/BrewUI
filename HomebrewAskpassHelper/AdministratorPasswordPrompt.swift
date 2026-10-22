import AppKit
import Foundation

/// The helper is `Homebrew.app/Contents/Helpers/<executable>`. Prompt copy lives in the app catalog.
enum AskpassAppBundle {
    static func locate() -> Bundle? {
        guard let executable = Bundle.main.executableURL else {
            return nil
        }
        let appURL = executable
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard appURL.pathExtension == "app" else {
            return nil
        }
        return Bundle(url: appURL)
    }

    static var bundle: Bundle {
        locate() ?? .main
    }
}

/// An unprivileged prompt. Only sudo validates the returned password.
@MainActor
final class AdministratorPasswordPrompt {
    private static let passwordFieldWidth: CGFloat = 240

    private let alert = NSAlert()
    private let passwordField = NSSecureTextField()

    init() {
        let bundle = AskpassAppBundle.bundle
        alert.messageText = String(
            localized: "Homebrew wants to make changes.",
            bundle: bundle,
            comment: "Askpass: primary message, standard macOS authorization wording",
        )
        alert.informativeText = String(
            localized: "Enter your password to allow this.",
            bundle: bundle,
            comment: "Askpass: explains that the password allows the change",
        )
        alert.addButton(withTitle: String(
            localized: "Authenticate",
            bundle: bundle,
            comment: "Askpass: submit the administrator password",
        ))
        alert.addButton(withTitle: String(
            localized: "Cancel",
            bundle: bundle,
            comment: "Askpass: cancel administrator authentication",
        ))
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = "\u{1b}"
        let label = String(localized: "Administrator password", bundle: bundle, comment: "Askpass: secure password field label")
        passwordField.placeholderString = label
        passwordField.setAccessibilityLabel(label)
        passwordField.frame.size = NSSize(width: Self.passwordFieldWidth, height: passwordField.intrinsicContentSize.height)
        alert.accessoryView = passwordField
        alert.window.initialFirstResponder = passwordField
    }

    /// Blocks until submission or cancellation; the caller must keep stdout private for sudo.
    func run() -> String? {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.activate()
        return response(for: alert.runModal())
    }

    private func response(for result: NSApplication.ModalResponse) -> String? {
        defer { passwordField.stringValue = "" }
        guard result == .alertFirstButtonReturn, !passwordField.stringValue.isEmpty else {
            return nil
        }
        return passwordField.stringValue
    }
}
