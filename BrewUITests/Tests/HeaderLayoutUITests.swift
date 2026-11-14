//
//  HeaderLayoutUITests.swift
//  BrewUITests
//

import BrewAccessibilityID
import BrewUITestContract
import XCTest

/// 同一窗口尺寸下保留六页截图，检查页头精简后仍能访问列表和操作。
final class HeaderLayoutUITests: BrewUITestCase {
    @MainActor
    func testHeaderScreenshots() {
        captureTour(arguments: ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_TW"], suffix: "")
    }

    @MainActor
    func testEnglishHeaderScreenshots() {
        captureTour(arguments: ["-AppleLanguages", "(en-GB)", "-AppleLocale", "en_GB"], suffix: " English")
    }

    @MainActor
    private func captureTour(arguments: [String], suffix: String) {
        let environment = [BrewUITestingEnvironmentKey.resetWindowState: "1"]
        let installed = launch(.installedBasic, environment: environment, arguments: arguments).assertHasPackage("wget")
        setComparisonWindowSize(installed.app)
        capture("Installed\(suffix)", app: installed.app, screen: .installedScreen)
        installed.sidebar.goToUpgrades().assertHasPackage("ripgrep")
        let upgradeHeading = BrewUIElement(installed.app, .paneHeaderSummary).waitToExist().element
        XCTAssertEqual(upgradeHeading.value as? String, suffix.isEmpty ? "可用升級" : "Available upgrades")
        capture("Upgrades\(suffix)", app: installed.app, screen: .upgradesScreen)
        installed.sidebar.goToConfiguration().assertShowsEntry("HOMEBREW_VERSION")
        capture("Configuration\(suffix)", app: installed.app, screen: .configScreen)
        installed.app.terminate()

        let discover = launch(.discoverSearch, environment: environment, arguments: arguments).sidebar.goToDiscover()
        discover.assertHasPackage("fd")
        setComparisonWindowSize(discover.app)
        capture("Discover\(suffix)", app: discover.app, screen: .discoverScreen)
        discover.app.terminate()

        let services = launch(.servicesBasic, environment: environment, arguments: arguments).sidebar.goToServices()
        services.row("redis").waitToExist()
        setComparisonWindowSize(services.app)
        capture("Services\(suffix)", app: services.app, screen: .servicesScreen)
        services.app.terminate()

        let doctor = launch(.doctorHasIssues, environment: environment, arguments: arguments).sidebar.goToDoctor()
        doctor.assertShowsIssue(containing: "deprecated or disabled")
        setComparisonWindowSize(doctor.app)
        capture("Doctor\(suffix)", app: doctor.app, screen: .doctorScreen)
    }

    @MainActor
    func testAllInstalledPackagesAreUpToDate() {
        captureUpToDate(arguments: ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_TW"], suffix: "")
        captureUpToDate(arguments: ["-AppleLanguages", "(en-GB)", "-AppleLocale", "en_GB"], suffix: " English")
    }

    @MainActor
    private func captureUpToDate(arguments: [String], suffix: String) {
        let upgrades = launch(
            .installedUpToDate,
            environment: [BrewUITestingEnvironmentKey.resetWindowState: "1"],
            arguments: arguments,
        ).assertHasPackage("wget").sidebar.goToUpgrades()
        let header = BrewUIElement(upgrades.app, .paneHeader, in: upgrades.root.element).waitToExist().element
        let headline = suffix.isEmpty ? "所有套件皆為最新版本" : "Everything is up to date"
        XCTAssertTrue(text(containing: headline, in: upgrades.app).waitForExistence(timeout: BrewUITestTimeout.default))
        XCTAssertFalse(upgrades.root.element.staticTexts["brew upgrade"].exists)
        XCTAssertEqual(header.buttons.count, 1, "Only refresh remains when no upgrades are available")
        setComparisonWindowSize(upgrades.app)
        capture("Upgrades up to date\(suffix)", app: upgrades.app, screen: .upgradesScreen)
        upgrades.app.terminate()
    }

    @MainActor
    func testConfigurationGuidanceRemainsAboveTheData() {
        let config = launch(.installedBasic).sidebar.goToConfiguration().assertShowsEntry("HOMEBREW_VERSION")
        let heading = text(containing: "Homebrew environment & diagnostics", in: config.app)
        XCTAssertTrue(heading.exists)
        // macOS 将原有可选文字提示框暴露为 Info，而不是正文文本。
        let guidance = config.root.element.otherElements["Info"]
        XCTAssertTrue(guidance.waitForExistence(timeout: BrewUITestTimeout.default))
        let firstEntry = text(containing: "HOMEBREW_VERSION", in: config.app)
        XCTAssertLessThanOrEqual(guidance.frame.maxY, firstEntry.frame.minY)
    }

    @MainActor
    func testDoctorWarningGuidanceRemainsVisible() {
        let doctor = launch(.doctorHasIssues).sidebar.goToDoctor().assertShowsIssue(containing: "deprecated or disabled")
        let guidance = doctor.root.element.otherElements["Info"]
        XCTAssertTrue(guidance.waitForExistence(timeout: BrewUITestTimeout.default))
    }

    @MainActor
    func testDoctorKeepsActionsBesideStatusAndHelpInToolbar() {
        let doctor = launch(
            .doctorHasIssues,
            arguments: ["-AppleLanguages", "(en-GB)", "-AppleLocale", "en_GB"],
        ).sidebar.goToDoctor().assertShowsIssue(containing: "deprecated or disabled")
        setComparisonWindowSize(doctor.app)
        BrewApp.activate(doctor.app)
        let header = BrewUIElement(doctor.app, .paneHeader, in: doctor.root.element).waitToExist().element
        let summary = BrewUIElement(doctor.app, .paneHeaderSummary, in: header).element
        XCTAssertEqual(header.buttons.count, 2)
        for button in header.buttons.allElementsBoundByIndex {
            XCTAssertTrue(button.isHittable)
            XCTAssertLessThan(button.frame.minY, summary.frame.minY + 20, "Normal-width actions stay beside the status heading")
        }
        let severity = text(containing: "Severity: Warning", in: doctor.app)
        XCTAssertTrue(severity.exists)
        XCTAssertEqual(severity.frame.minY, header.buttons.firstMatch.frame.minY, accuracy: 2, "The detail badge follows the first action row")
        let info = BrewUIElement(doctor.app, .doctorPurposeInfo).waitToExist().element
        XCTAssertLessThan(info.frame.maxY, header.frame.minY, "Purpose guidance belongs to the native toolbar")
        capture("Doctor English", app: doctor.app, screen: .doctorScreen)
        doctor.sidebar.goToInstalled().assertRowCount(0)
        BrewUIElement(doctor.app, .doctorPurposeInfo).assertDoesNotExist()
    }

    @MainActor
    func testServiceCommandRemainsExpanded() {
        let services = launch(.servicesBasic).sidebar.goToServices()
        services.row("redis").waitToExist()
        let command = services.root.element.staticTexts["brew services info --all"]
        XCTAssertTrue(command.waitForExistence(timeout: BrewUITestTimeout.default))
    }

    @MainActor
    func testLongTranslationKeepsUpgradeActionsInsideThePane() {
        let upgrades = launch(
            .installedBasic,
            environment: [BrewUITestingEnvironmentKey.resetWindowState: "1"],
            arguments: ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"],
        ).sidebar.goToUpgrades().assertHasPackage("ripgrep")
        let window = upgrades.app.windows.firstMatch
        let originalFrame = window.frame
        defer {
            let compactFrame = window.frame
            _ = window.resizeWindow(by: CGVector(
                dx: originalFrame.width - compactFrame.width,
                dy: originalFrame.height - compactFrame.height,
            ))
        }
        _ = window.resizeWindow(by: CGVector(dx: -400, dy: -300))
        let header = BrewUIElement(upgrades.app, .paneHeader, in: upgrades.root.element).element
        XCTAssertEqual(header.buttons.count, 2)
        for button in header.buttons.allElementsBoundByIndex {
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.minX, header.frame.minX)
            XCTAssertLessThanOrEqual(button.frame.maxX, header.frame.maxX)
        }
        capture("Upgrades compact Spanish", app: upgrades.app, screen: .upgradesScreen)
    }

    @MainActor
    func testTraditionalChineseDarkHeaders() {
        let arguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_TW"]
        let environment = [BrewUITestingEnvironmentKey.darkAppearance: "1"]
        let services = launch(.servicesBasic, environment: environment, arguments: arguments).sidebar.goToServices()
        services.row("redis").waitToExist()
        capture("Services dark", app: services.app, screen: .servicesScreen)
        services.app.terminate()
        let doctor = launch(.doctorHasIssues, environment: environment, arguments: arguments).sidebar.goToDoctor()
            .assertShowsIssue(containing: "deprecated or disabled")
        capture("Doctor dark", app: doctor.app, screen: .doctorScreen)
    }

    @MainActor
    func testInstalledHeaderDoesNotRepeatThePageTitle() {
        let installed = launch(.installedBasic).assertHasPackage("iterm2")
        let summary = BrewUIElement(installed.app, .paneHeaderSummary).waitToExist().element
        let sidebar = BrewUIElement(installed.app, .sidebar).element
        XCTAssertEqual(summary.frame.minX - sidebar.frame.maxX, 20, accuracy: 1, "Content follows the native toolbar title gutter")
        let navigationItem = BrewUIElement(installed.app, .sidebarItem(.installed)).element
        XCTAssertEqual(summary.frame.midY, navigationItem.frame.midY, accuracy: 0.5, "Text boxes share their vertical centre, not their baseline")
        // 原生 List 将整行文字合并为一个元素，直接比较行的前缘。
        let firstRow = installed.list.row("iterm2").waitToExist().element
        XCTAssertEqual(firstRow.frame.minX, summary.frame.minX, accuracy: 1)
        let descriptions = installed.root.element.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@",
            "Your packages", "Your packages",
        ))
        XCTAssertEqual(descriptions.count, 0, "The window already identifies the Installed page")
    }

    @MainActor
    private func setComparisonWindowSize(_ app: XCUIApplication) {
        let window = app.windows.firstMatch
        let frame = window.frame
        _ = window.resizeWindow(by: CGVector(dx: 1000 - frame.width, dy: 732 - frame.height))
        XCTAssertEqual(window.frame.width, 1000, accuracy: 1)
        XCTAssertEqual(window.frame.height, 732, accuracy: 1)
    }

    @MainActor
    private func text(containing substring: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", substring, substring)).firstMatch
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication, screen: AXID? = nil) {
        let collapsedStatus = BrewUIElement(app, .consoleStatus).element
        if !collapsedStatus.exists {
            BrewUIButton(app, .consoleToggle).tap()
            XCTAssertTrue(collapsedStatus.waitForExistence(timeout: BrewUITestTimeout.default))
        }
        if let screen {
            let root = BrewUIElement(app, screen).element
            let summary = BrewUIElement(app, .paneHeaderSummary, in: root)
                .waitToExist().element
            XCTAssertGreaterThanOrEqual(summary.frame.height, 20, "Counts and status use the existing panel-heading style")
            let sidebar = BrewUIElement(app, .sidebar).element
            XCTAssertEqual(summary.frame.minX - sidebar.frame.maxX, 20, accuracy: 1, "Headings follow the native toolbar title gutter")
            let metrics = XCTAttachment(string: "screen: \(root.frame)\nsummary: \(summary.frame)")
            metrics.name = "Header geometry - \(name)"
            metrics.lifetime = .keepAlways
            add(metrics)
        }
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = "Header - \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
