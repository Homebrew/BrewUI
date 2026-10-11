import AppKit
@testable import BrewUIComponents
import Testing

@MainActor
struct AdministratorPasswordPromptTests {
    @Test func `prompt uses secure labelled input and clears every response`() {
        let prompt = AdministratorPasswordPrompt()
        #expect(prompt.alert.accessoryView is NSSecureTextField)
        #expect(prompt.alert.buttons.map(\.title) == ["Authenticate", "Cancel"])
        #expect(prompt.passwordField.accessibilityLabel() == "Administrator password")
        prompt.passwordField.stringValue = "dummy password"
        #expect(prompt.response(for: .alertFirstButtonReturn) == "dummy password")
        #expect(prompt.passwordField.stringValue.isEmpty)
        #expect(prompt.response(for: .alertFirstButtonReturn) == nil)
        prompt.passwordField.stringValue = "discard me"
        #expect(prompt.response(for: .alertSecondButtonReturn) == nil)
        #expect(prompt.passwordField.stringValue.isEmpty)
    }
}
