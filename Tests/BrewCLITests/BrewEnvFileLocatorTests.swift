@testable import BrewCLI
import BrewCore
import Foundation
import Testing

struct BrewEnvFileLocatorTests {
    private static let home = "/Users/test"

    @Test func `XDG_CONFIG_HOME wins when present`() {
        let locator = BrewEnvFileLocator(
            environment: [
                "HOME": Self.home,
                "XDG_CONFIG_HOME": "/Users/test/.xdg",
                "HOMEBREW_XDG_CONFIG_HOME": "/Users/test/.homebrew-xdg",
            ],
            fileExists: { _ in false },
        )
        #expect(locator.preferredCreationPath().path == "/Users/test/.xdg/homebrew/brew.env")
    }

    @Test func `HOMEBREW_XDG_CONFIG_HOME branch used when XDG_CONFIG_HOME is unset`() {
        let locator = BrewEnvFileLocator(
            environment: [
                "HOME": Self.home,
                "HOMEBREW_XDG_CONFIG_HOME": "/Users/test/.homebrew-xdg",
            ],
            fileExists: { _ in false },
        )
        #expect(locator.preferredCreationPath().path == "/Users/test/.homebrew-xdg/homebrew/brew.env")
    }

    @Test func `default creation path is ~/.homebrew/brew.env`() {
        let locator = BrewEnvFileLocator(
            environment: ["HOME": Self.home],
            fileExists: { _ in false },
        )
        #expect(locator.preferredCreationPath().path == "/Users/test/.homebrew/brew.env")
    }

    @Test func `empty XDG_CONFIG_HOME falls through to HOMEBREW_XDG_CONFIG_HOME`() {
        let locator = BrewEnvFileLocator(
            environment: [
                "HOME": Self.home,
                "XDG_CONFIG_HOME": "",
                "HOMEBREW_XDG_CONFIG_HOME": "/Users/test/.homebrew-xdg",
            ],
            fileExists: { _ in false },
        )
        #expect(locator.preferredCreationPath().path == "/Users/test/.homebrew-xdg/homebrew/brew.env")
    }

    @Test func `empty HOMEBREW_XDG_CONFIG_HOME falls through to HOME default`() {
        let locator = BrewEnvFileLocator(
            environment: [
                "HOME": Self.home,
                "HOMEBREW_XDG_CONFIG_HOME": "",
            ],
            fileExists: { _ in false },
        )
        #expect(locator.preferredCreationPath().path == "/Users/test/.homebrew/brew.env")
    }

    @Test func `locate returns the resolved path when it exists`() {
        let path = "/Users/test/.homebrew/brew.env"
        let locator = BrewEnvFileLocator(
            environment: ["HOME": Self.home],
            fileExists: { $0 == path },
        )
        #expect(locator.locate().path == path)
        #expect(locator.existingPath()?.path == path)
    }

    @Test func `locate falls back to the preferred creation path when no file exists`() {
        let locator = BrewEnvFileLocator(
            environment: ["HOME": Self.home],
            fileExists: { _ in false },
        )
        #expect(locator.locate().path == "/Users/test/.homebrew/brew.env")
        #expect(locator.existingPath() == nil)
    }

    /// Integration check that ties the existing mocked probe-order assertions back to the real
    /// `FileManager.fileExists(atPath:)` callback the locator uses in production. Writes a real
    /// `brew.env` at the default path under a temp `$HOME` and confirms `locate()` finds it.
    @Test func `locate uses the real FileManager when no override is provided`() throws {
        let fileManager = FileManager.default
        let tempHome = fileManager.temporaryDirectory.appendingPathComponent(
            "brew-env-locator-\(UUID().uuidString)",
            isDirectory: true,
        )
        let envFile = tempHome.appendingPathComponent(".homebrew/brew.env")
        try fileManager.createDirectory(at: envFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("HOMEBREW_NO_ANALYTICS=1\n".utf8).write(to: envFile)
        defer { try? fileManager.removeItem(at: tempHome) }

        // Explicitly clear XDG_CONFIG_HOME so the default branch is exercised even on CI hosts that set it.
        let locator = BrewEnvFileLocator(environment: ["HOME": tempHome.path])

        #expect(locator.locate().path == envFile.path)
    }
}
