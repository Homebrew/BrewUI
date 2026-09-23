import BrewCore
import BrewRepositoryInterfaces
@testable import BrewUIComponents
import Testing

@Suite("BrewErrorCopy")
struct BrewErrorCopyTests {
    private let fallback = "Something went wrong."

    @Test func `brew stderr is shown trimmed`() {
        let message = BrewErrorCopy.message(for: BrewCommandError.failed(exitCode: 1, stderr: "  blocked \n"), fallback: fallback)
        #expect(message == "blocked")
    }

    @Test func `empty stderr falls back to the generic brew failure line`() {
        let message = BrewErrorCopy.message(for: BrewCommandError.failed(exitCode: 1, stderr: "   "), fallback: fallback)
        #expect(message == "Homebrew command failed.")
    }

    @Test func `launch failures show the diagnostic as-is`() {
        let message = BrewErrorCopy.message(for: BrewCommandError.launchFailed(underlying: "spawn failed"), fallback: fallback)
        #expect(message == "spawn failed")
    }

    @Test func `a missing brew executable gets the install guidance line`() {
        let message = BrewErrorCopy.message(for: BrewLookupError.executableNotFound, fallback: fallback)
        #expect(message == "Could not find Homebrew. Install it or ensure brew is in the default location.")
    }

    @Test func `malformed brew output gets its own line`() {
        let error = BrewRepositoryError.malformedBrewOutput(command: "brew info --installed --json=v2")
        #expect(BrewErrorCopy.message(for: error, fallback: fallback) == "Homebrew returned output the app couldn’t read.")
    }

    @Test func `unknown errors use the caller's fallback`() {
        struct Unknown: Error {}
        #expect(BrewErrorCopy.message(for: Unknown(), fallback: fallback) == fallback)
    }

    @Test func `operation failures word the same way as thrown errors`() {
        let thrown = BrewErrorCopy.message(for: BrewLookupError.executableNotFound, fallback: fallback)
        #expect(BrewErrorCopy.message(for: .brewExecutableNotFound) == thrown)
    }

    @Test func `other operation failures show their description`() {
        #expect(BrewErrorCopy.message(for: .other(description: "friendly", diagnostic: "raw")) == "friendly")
    }
}
