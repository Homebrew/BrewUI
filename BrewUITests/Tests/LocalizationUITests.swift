import BrewAccessibilityID
import XCTest

final class LocalizationUITests: BrewUITestCase {
    @MainActor
    func testSimplifiedChineseAcrossFeatures() throws {
        let app = try track(BrewApp.launch(scenario: .installedBasic, language: "zh-Hans"))
        let installed = app.buttons[AXID.sidebarItem(.installed).rawValue]
        XCTAssertTrue(installed.waitForExistence(timeout: BrewUITestTimeout.launch))
        XCTAssertEqual(installed.label, "已安装")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "4 个软件包"))
            .firstMatch.waitForExistence(timeout: BrewUITestTimeout.command))

        app.buttons[AXID.sidebarItem(.upgrades).rawValue].click()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "2 个软件包可升级"))
            .firstMatch.waitForExistence(timeout: BrewUITestTimeout.command))

        app.buttons[AXID.sidebarItem(.doctor).rawValue].click()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "系统已准备就绪"))
            .firstMatch.waitForExistence(timeout: BrewUITestTimeout.command))
        XCTAssertTrue(app.buttons["重新运行"].exists)

        app.buttons[AXID.sidebarItem(.configuration).rawValue].click()
        XCTAssertTrue(app.buttons["复制报告"].waitForExistence(timeout: BrewUITestTimeout.command))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "构建设置")).firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Simplified Chinese configuration"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testSimplifiedChineseMissingHomebrewError() throws {
        let app = try track(BrewApp.launch(scenario: .brewNotFound, language: "zh-Hans"))
        let error = app.buttons[AXID.errorState.rawValue]
        XCTAssertTrue(error.waitForExistence(timeout: BrewUITestTimeout.command))
        XCTAssertEqual(error.label, "找不到 Homebrew。请先安装，或确认 brew 位于默认位置。")
    }
}
