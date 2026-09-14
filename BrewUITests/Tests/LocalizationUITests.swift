import BrewAccessibilityID
import BrewUITestContract
import XCTest

final class LocalizationUITests: BrewUITestCase {
    @MainActor
    func testDeferredLanguageKeepsCurrentWindowAndSearch() throws {
        let installed = launch(.installedBasic)
        let app = installed.app
        let pid = try XCTUnwrap(BrewApp.processIdentifier)
        installed.search(for: "wget").assertHasPackage("wget")
        let parentFrame = app.windows.firstMatch.frame
        selectLanguage("zh-Hans", in: app)
        let later = app.buttons["Next Launch"]
        XCTAssertTrue(later.waitForExistence(timeout: BrewUITestTimeout.default))
        let name = Locale(identifier: "zh-Hans").localizedString(forIdentifier: "zh-Hans") ?? "zh-Hans"
        let dialog = app.dialogs["Switch to \(name)?"]
        XCTAssertTrue(dialog.exists)
        XCTAssertEqual(dialog.frame.midX, parentFrame.midX, accuracy: 2)
        XCTAssertEqual(dialog.frame.midY, parentFrame.midY, accuracy: 2)
        later.click()
        XCTAssertEqual(app.buttons[AXID.sidebarItem(.installed).rawValue].label, "Installed")
        installed.searchField.assertValue("wget")
        XCTAssertEqual(BrewApp.processIdentifier, pid)
    }

    @MainActor
    func testNextLaunchAppliesLanguageToNativeAndAppCommands() throws {
        let app = launch(.installedBasic).app
        selectLanguage("zh-Hans", in: app)
        XCTAssertTrue(app.buttons["Next Launch"].waitForExistence(timeout: BrewUITestTimeout.default))
        app.buttons["Next Launch"].click()
        app.terminate()
        // Tests do not write the real app defaults domain, so the harness forwards the isolated domain's saved native language as a launch argument.
        let domain = try XCTUnwrap(app.launchEnvironment[BrewUITestingEnvironmentKey.languagePreferencesDomain])
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        let savedLanguage = try XCTUnwrap(defaults.stringArray(forKey: "AppleLanguages")?.first)
        XCTAssertEqual(savedLanguage, "zh-Hans")
        app.launchArguments += ["-AppleLanguages", "(\(savedLanguage))"]
        app.launch()
        let windowMenu = app.menuBars.menuBarItems["窗口"]
        XCTAssertTrue(windowMenu.waitForExistence(timeout: BrewUITestTimeout.launch))
        windowMenu.click()
        // Minimize All comes from the framework, not an application-declared replacement command.
        XCTAssertTrue(app.menuItems["全部最小化"].exists)
        XCTAssertTrue(app.menuItems["全部缩放"].exists)
        app.typeKey(.escape, modifierFlags: [])
        app.buttons[AXID.sidebarItem(.configuration).rawValue].click()
        XCTAssertTrue(app.menuBars.menuBarItems["窗口"].exists)
        XCTAssertTrue(app.menuBars.menuBarItems["调试"].exists)
    }

    @MainActor
    func testRunningOperationDisablesImmediateReopen() throws {
        let app = try track(BrewApp.launch(
            scenario: .discoverSearch,
            commandDelays: ["install_--formula_ripgrep": 45],
        ))
        let installed = InstalledScreen(app: app).waitUntilLoaded(timeout: BrewUITestTimeout.launch)
        let pid = try XCTUnwrap(BrewApp.processIdentifier)
        let console = installed.sidebar.goToDiscover().search(for: "ripgrep")
            .openDetail(for: "ripgrep").install().console
        console.assertOutputContains("Pouring ripgrep")
        selectLanguage("zh-Hans", in: app)
        let reopen = app.buttons["Reopen Now"]
        XCTAssertTrue(reopen.waitForExistence(timeout: BrewUITestTimeout.default))
        XCTAssertFalse(reopen.isEnabled)
        app.buttons["Next Launch"].click()
        XCTAssertEqual(BrewApp.processIdentifier, pid)
        console.assertSucceeded(timeout: 60)
        installed.sidebar.goToInstalled().assertHasPackage("ripgrep")
        XCTAssertEqual(BrewApp.processIdentifier, pid)
    }

    @MainActor
    private func selectLanguage(_ language: String, in app: XCUIApplication) {
        // SwiftUI `Menu` inside Commands does not publish AXID onto the NSMenuItem.
        // Match the visible Homebrew → Language titles from the current launch language.
        let appMenu = app.menuBars.menuBarItems["Homebrew"]
        XCTAssertTrue(appMenu.waitForExistence(timeout: BrewUITestTimeout.default))
        appMenu.click()
        let menu = app.menuItems["Language"]
        XCTAssertTrue(menu.waitForExistence(timeout: BrewUITestTimeout.default))
        menu.hover()
        let name = Locale(identifier: language).localizedString(forIdentifier: language) ?? language
        let option = app.menuItems[name]
        XCTAssertTrue(option.waitForExistence(timeout: BrewUITestTimeout.default))
        option.click()
    }
}
