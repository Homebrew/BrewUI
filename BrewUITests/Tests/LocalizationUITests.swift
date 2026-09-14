import BrewAccessibilityID
import XCTest

final class LocalizationUITests: BrewUITestCase {
    @MainActor
    func testNativeMenuTitlesSurviveReturningToWindow() {
        let app = launch(.installedBasic).app
        selectLanguage("zh-Hans", in: app)
        for destination in [AXID.SidebarDestination.configuration, .installed] {
            let fileMenu = app.menuBars.menuBarItems["文件"]
            XCTAssertTrue(fileMenu.waitForExistence(timeout: BrewUITestTimeout.default))
            fileMenu.click()
            app.typeKey(.escape, modifierFlags: [])
            app.buttons[AXID.sidebarItem(destination).rawValue].click()
            for title in ["文件", "编辑", "显示", "窗口", "帮助"] {
                XCTAssertTrue(app.menuBars.menuBarItems[title].exists, "Menu reverted after focusing the window: \(title)")
            }
        }
        selectLanguage("en", in: app)
        XCTAssertTrue(app.menuBars.menuBarItems["File"].waitForExistence(timeout: BrewUITestTimeout.default))
    }

    @MainActor
    func testStandardCommandLabelsSwitchInPlace() {
        let app = launch(.installedBasic).app
        for (language, about, file, close) in [
            ("zh-Hans", "关于 Homebrew", "文件", "关闭"),
            ("zh-Hant", "關於 Homebrew", "檔案", "關閉"),
            ("en", "About Homebrew", "File", "Close"),
        ] {
            selectLanguage(language, in: app)
            app.menuBars.menuBarItems.element(boundBy: 1).click()
            XCTAssertTrue(app.menuItems[about].waitForExistence(timeout: BrewUITestTimeout.default))
            app.typeKey(.escape, modifierFlags: [])
            app.menuBars.menuBarItems[file].click()
            XCTAssertTrue(app.menuItems[close].waitForExistence(timeout: BrewUITestTimeout.default))
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    @MainActor
    func testConfigurationWindowTitleChangesWithoutNavigation() {
        let installed = launch(.installedBasic)
        let app = installed.app
        app.buttons[AXID.sidebarItem(.configuration).rawValue].click()
        XCTAssertTrue(app.windows["Configuration"].waitForExistence(timeout: BrewUITestTimeout.default))

        selectLanguage("zh-Hans", in: app)
        XCTAssertTrue(app.windows["配置"].waitForExistence(timeout: BrewUITestTimeout.default))

        selectLanguage("en", in: app)
        XCTAssertTrue(app.windows["Configuration"].waitForExistence(timeout: BrewUITestTimeout.default))
    }

    @MainActor
    func testSwitchingLanguageKeepsSearchAndProcessAlive() throws {
        let installed = launch(.installedBasic)
        let app = installed.app
        let pid = try XCTUnwrap(BrewApp.processIdentifier)
        installed.search(for: "wget").assertHasPackage("wget")

        selectLanguage("zh-Hans", in: app)
        let sidebar = app.buttons[AXID.sidebarItem(.installed).rawValue]
        XCTAssertTrue(sidebar.waitForExistence(timeout: BrewUITestTimeout.default))
        XCTAssertEqual(sidebar.label, "已安装")
        installed.searchField.assertValue("wget")
        XCTAssertEqual(BrewApp.processIdentifier, pid)

        selectLanguage("en", in: app)
        XCTAssertEqual(sidebar.label, "Installed")
        installed.searchField.assertValue("wget")
        installed.assertHasPackage("wget")
        XCTAssertEqual(BrewApp.processIdentifier, pid)
    }

    @MainActor
    func testLanguageSwitchDoesNotInterruptAnInstallingPackage() throws {
        let app = try track(BrewApp.launch(
            scenario: .discoverSearch,
            commandDelays: ["install_--formula_ripgrep": 45],
        ))
        let installed = InstalledScreen(app: app).waitUntilLoaded(timeout: BrewUITestTimeout.launch)
        let pid = try XCTUnwrap(BrewApp.processIdentifier)
        let console = installed.sidebar.goToDiscover().search(for: "ripgrep")
            .openDetail(for: "ripgrep").install().console
        console.assertOutputContains("Pouring ripgrep")
        console.collapse()
        console.status.assertContains("running")

        selectLanguage("zh-Hans", in: app)
        console.status.assertContains("正在运行")
        XCTAssertEqual(BrewApp.processIdentifier, pid)

        selectLanguage("en", in: app)
        console.assertSucceeded(timeout: 60)
        installed.sidebar.goToInstalled().assertHasPackage("ripgrep")
        XCTAssertEqual(BrewApp.processIdentifier, pid)
    }

    @MainActor
    private func selectLanguage(_ language: String, in app: XCUIApplication) {
        app.menuBars.menuBarItems.element(boundBy: 1).click()
        // 原生 NSMenu 不保留 SwiftUI Menu/Toggle 的 accessibilityIdentifier，按本测试覆盖的菜单语言定位。
        let menu = app.menuItems.matching(NSPredicate(format: "label IN %@", ["Language", "语言", "語言"])).firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: BrewUITestTimeout.default))
        menu.hover()
        let name = Locale(identifier: language).localizedString(forIdentifier: language) ?? language
        let option = app.menuItems[name]
        XCTAssertTrue(option.waitForExistence(timeout: BrewUITestTimeout.default))
        option.click()
    }
}
