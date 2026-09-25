import AppKit
import BrewAccessibilityID
import XCTest

final class LocalizationUITests: BrewUITestCase {
    @MainActor
    func testSimplifiedChineseAcrossFeatures() throws {
        let app = try track(BrewApp.launch(scenario: .installedBasic, language: "zh-Hans"))
        let installed = InstalledScreen(app: app).waitUntilLoaded(timeout: BrewUITestTimeout.launch)
        let sidebarItem = BrewUIButton(app, .sidebarItem(.installed)).waitToExist()
        XCTAssertEqual(sidebarItem.element.label, "已安装")
        assertText("4 个软件包", on: installed)

        let upgrades = installed.sidebar.goToUpgrades()
        assertText("2 个软件包可升级", on: upgrades)

        let doctor = upgrades.sidebar.goToDoctor()
        assertText("系统已准备就绪", on: doctor)
        XCTAssertTrue(doctor.root.element.buttons["重新运行"].waitForExistence(timeout: BrewUITestTimeout.default))

        let configuration = doctor.sidebar.goToConfiguration()
        XCTAssertTrue(configuration.root.element.buttons["复制报告"].waitForExistence(timeout: BrewUITestTimeout.command))
        assertText("构建设置", on: configuration)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Simplified Chinese configuration"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testChineseConfigurationCopiesEnglishReport() throws {
        let app = try track(BrewApp.launch(scenario: .installedBasic, language: "zh-Hans"))
        let installed = InstalledScreen(app: app).waitUntilLoaded(timeout: BrewUITestTimeout.launch)
        let configuration = installed.sidebar.goToConfiguration()
        assertText("构建设置", on: configuration)
        let copy = configuration.root.element.buttons["复制报告"]
        XCTAssertTrue(copy.waitForExistence(timeout: BrewUITestTimeout.command))
        copy.click()

        let report = try XCTUnwrap(NSPasteboard.general.string(forType: .string))
        XCTAssertTrue(report.contains("\n\nSystem\n"))
        XCTAssertTrue(report.contains("\n\nBuild settings\n"))
        XCTAssertFalse(report.contains("\n\n系统\n"))
        XCTAssertFalse(report.contains("\n\n构建设置\n"))
    }

    @MainActor
    func testSimplifiedChineseMissingHomebrewError() throws {
        let app = try track(BrewApp.launch(scenario: .brewNotFound, language: "zh-Hans"))
        let installed = InstalledScreen(app: app).waitUntilLoaded(timeout: BrewUITestTimeout.launch)
        installed.errorState.assertContains(
            "找不到 Homebrew。请先安装，或确认 brew 位于默认位置。",
            timeout: BrewUITestTimeout.command,
        )
    }

    @MainActor
    private func assertText(_ substring: String, on screen: some Screen, file: StaticString = #filePath, line: UInt = #line) {
        // macOS exposes combined SwiftUI text through value while label can be empty.
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", substring, substring)
        let match = screen.root.element.descendants(matching: .staticText).matching(predicate).firstMatch
        guard match.waitForExistence(timeout: BrewUITestTimeout.command) else {
            XCTFail(
                "Expected \(screen.root.id.rawValue) to contain “\(substring)”.\n\(BrewUITestDiagnostics.report(for: screen.app))",
                file: file,
                line: line,
            )
            return
        }
    }
}
