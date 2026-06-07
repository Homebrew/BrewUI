@testable import BrewCLI
import BrewCore
import Foundation
import Testing

struct BrewEnvFileLocatorTests {
    private static let home = "/Users/test"

    @Test func `HOMEBREW_USER_CONFIG_HOME wins when present`() {
        let locator = BrewEnvFileLocator(
            environment: [
                "HOME": Self.home,
                "HOMEBREW_USER_CONFIG_HOME": "/opt/cfg",
                "XDG_CONFIG_HOME": "/Users/test/.config",
            ],
            fileExists: { _ in false },
        )
        #expect(locator.preferredCreationPath().path == "/opt/cfg/brew.env")
    }

    @Test func `XDG_CONFIG_HOME is used when HOMEBREW_USER_CONFIG_HOME is unset`() {
        let locator = BrewEnvFileLocator(
            environment: ["HOME": Self.home, "XDG_CONFIG_HOME": "/Users/test/.xdg"],
            fileExists: { _ in false },
        )
        #expect(locator.preferredCreationPath().path == "/Users/test/.xdg/homebrew/brew.env")
    }

    @Test func `default creation path is ~/.config/homebrew/brew.env`() {
        let locator = BrewEnvFileLocator(
            environment: ["HOME": Self.home],
            fileExists: { _ in false },
        )
        #expect(locator.preferredCreationPath().path == "/Users/test/.config/homebrew/brew.env")
    }

    @Test func `legacy path is never selected as a creation target`() {
        let locator = BrewEnvFileLocator(
            environment: ["HOME": Self.home],
            fileExists: { _ in false },
        )
        #expect(locator.preferredCreationPath().path != "/Users/test/.homebrew/brew.env")
    }

    @Test func `locate returns the first existing probe path`() {
        let xdgPath = "/Users/test/.config/homebrew/brew.env"
        let locator = BrewEnvFileLocator(
            environment: ["HOME": Self.home],
            fileExists: { $0 == xdgPath },
        )
        #expect(locator.locate().path == xdgPath)
        #expect(locator.existingPath()?.path == xdgPath)
    }

    @Test func `locate finds the legacy path when it is the only one present`() {
        let legacy = "/Users/test/.homebrew/brew.env"
        let locator = BrewEnvFileLocator(
            environment: ["HOME": Self.home],
            fileExists: { $0 == legacy },
        )
        #expect(locator.locate().path == legacy)
    }

    @Test func `locate falls back to the preferred creation path when no file exists`() {
        let locator = BrewEnvFileLocator(
            environment: ["HOME": Self.home],
            fileExists: { _ in false },
        )
        #expect(locator.locate().path == "/Users/test/.config/homebrew/brew.env")
        #expect(locator.existingPath() == nil)
    }

    @Test func `existing modern XDG file wins over an existing legacy file`() {
        let xdg = "/Users/test/.config/homebrew/brew.env"
        let legacy = "/Users/test/.homebrew/brew.env"
        let locator = BrewEnvFileLocator(
            environment: ["HOME": Self.home],
            fileExists: { $0 == xdg || $0 == legacy },
        )
        #expect(locator.locate().path == xdg)
    }

    @Test func `empty HOMEBREW_USER_CONFIG_HOME is ignored`() {
        let locator = BrewEnvFileLocator(
            environment: ["HOME": Self.home, "HOMEBREW_USER_CONFIG_HOME": ""],
            fileExists: { _ in false },
        )
        #expect(locator.preferredCreationPath().path == "/Users/test/.config/homebrew/brew.env")
    }
}
