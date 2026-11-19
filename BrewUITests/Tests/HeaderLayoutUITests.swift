//
//  HeaderLayoutUITests.swift
//  BrewUITests
//

import AppKit
import BrewAccessibilityID
import BrewUITestContract
import XCTest

/// 用完整的原生窗口验收六页；只有窄窗用例要求精确宽度。
final class HeaderLayoutUITests: BrewUITestCase {
    private let freshWindow = [BrewUITestingEnvironmentKey.resetWindowState: "1"]

    @MainActor
    func testSectionSeparatorsShareTheTwentyPointContentGutters() throws {
        for dark in [false, true] {
            let environment = windowEnvironment(dark: dark)
            let arguments = ["-AppleLanguages", "(en-GB)"]
            let doctor = launch(.doctorHasIssues, environment: environment, arguments: arguments)
                .sidebar.goToDoctor().assertShowsIssue(containing: "deprecated or disabled")
            BrewApp.activate(doctor.app)
            try assertSectionSeparatorInsets(in: doctor.root.element, heading: "Warning", app: doctor.app)
            doctor.app.terminate()

            let discover = launch(.discoverSearch, environment: environment, arguments: arguments)
                .sidebar.goToDiscover().assertHasPackage("fd")
            BrewApp.activate(discover.app)
            try assertSectionSeparatorInsets(in: discover.root.element, heading: "Popular Formulae", app: discover.app)
            try assertSectionSeparatorInsets(in: discover.root.element, heading: "Popular Casks", app: discover.app)
            discover.app.terminate()
        }
    }

    @MainActor
    func testContentBoundaryDoesNotDarkenAtTheSplitIntersection() throws {
        for dark in [false, true] {
            let environment = windowEnvironment(dark: dark)
            let doctor = launch(.doctorHasIssues, environment: environment)
                .sidebar.goToDoctor().assertShowsIssue(containing: "deprecated or disabled")
            BrewApp.activate(doctor.app)
            try assertUniformContentBoundary(in: doctor.app)
            doctor.app.terminate()
        }
    }

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
        let installed = launch(.installedBasic, environment: freshWindow, arguments: arguments).assertHasPackage("wget")
        capture("Installed\(suffix)", app: installed.app, screen: .installedScreen)
        installed.sidebar.goToUpgrades().assertHasPackage("ripgrep")
        let upgradeHeading = BrewUIElement(installed.app, .paneHeaderSummary).waitToExist().element
        assertText(suffix.isEmpty ? "可用升級" : "Available", in: upgradeHeading)
        capture("Upgrades\(suffix)", app: installed.app, screen: .upgradesScreen)
        installed.sidebar.goToConfiguration().assertShowsEntry("HOMEBREW_VERSION")
        capture("Configuration\(suffix)", app: installed.app, screen: .configScreen)
        installed.app.terminate()

        let discover = launch(.discoverSearch, environment: freshWindow, arguments: arguments).sidebar.goToDiscover()
        discover.assertHasPackage("fd")
        capture("Discover\(suffix)", app: discover.app, screen: .discoverScreen)
        discover.app.terminate()

        let services = launch(.servicesBasic, environment: freshWindow, arguments: arguments).sidebar.goToServices()
        services.row("redis").waitToExist()
        capture("Services\(suffix)", app: services.app, screen: .servicesScreen)
        services.app.terminate()

        let doctor = launch(.doctorHasIssues, environment: freshWindow, arguments: arguments).sidebar.goToDoctor()
        doctor.assertShowsIssue(containing: "deprecated or disabled")
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
            environment: freshWindow,
            arguments: arguments,
        ).assertHasPackage("wget").sidebar.goToUpgrades()
        let header = BrewUIElement(upgrades.app, .paneHeader, in: upgrades.root.element).waitToExist().element
        let headline = suffix.isEmpty ? "所有套件皆為最新版本" : "Everything is up to date"
        let state = BrewUIElement(upgrades.app, .upgradesUpToDate, in: upgrades.root.element).waitToExist().element
        assertText(headline, in: state)
        XCTAssertTrue(upgrades.root.element.staticTexts["brew upgrade"].exists, "The original command remains expanded in the up-to-date state")
        XCTAssertEqual(header.buttons.count, 1, "Only refresh remains when no upgrades are available")
        capture("Upgrades up to date\(suffix)", app: upgrades.app, screen: .upgradesScreen)
        upgrades.app.terminate()
    }

    @MainActor
    func testConfigurationGuidanceRemainsAboveTheData() {
        let config = launch(
            .installedBasic,
            environment: freshWindow,
            arguments: ["-AppleLanguages", "(en-GB)"],
        ).sidebar.goToConfiguration().assertShowsEntry("HOMEBREW_VERSION")
        let root = config.root.element
        let heading = BrewUIElement(config.app, .paneHeaderSummary, in: root).waitToExist().element
        assertText("Homebrew environment & diagnostics", in: heading)
        let guidance = BrewUIElement(config.app, .configGuidance, in: root).waitToExist().element
        let firstEntry = root.staticTexts["HOMEBREW_VERSION"]
        XCTAssertLessThanOrEqual(guidance.frame.maxY, firstEntry.frame.minY)
    }

    @MainActor
    func testDoctorWarningGuidanceRemainsVisible() {
        let doctor = launch(.doctorHasIssues, environment: freshWindow)
            .sidebar.goToDoctor().assertShowsIssue(containing: "deprecated or disabled")
        BrewUIElement(doctor.app, .doctorWarningGuidance, in: doctor.root.element).waitToExist()
    }

    @MainActor
    func testDoctorKeepsActionsBesideStatusWithoutExtraToolbarHelp() {
        let doctor = launch(
            .doctorHasIssues,
            environment: freshWindow,
            arguments: ["-AppleLanguages", "(en-GB)", "-AppleLocale", "en_GB"],
        ).sidebar.goToDoctor().assertShowsIssue(containing: "deprecated or disabled")
        BrewApp.activate(doctor.app)
        let header = BrewUIElement(doctor.app, .paneHeader, in: doctor.root.element).waitToExist().element
        let summary = BrewUIElement(doctor.app, .paneHeaderSummary, in: header).element
        XCTAssertEqual(header.buttons.count, 2)
        for button in header.buttons.allElementsBoundByIndex {
            XCTAssertTrue(button.isHittable)
            XCTAssertLessThan(button.frame.minY, summary.frame.minY + 20, "Normal-width actions stay beside the status heading")
        }
        let severity = BrewUIElement(doctor.app, .doctorDetailSeverity).waitToExist().element
        assertText("Severity: Warning", in: severity)
        XCTAssertEqual(severity.frame.minY, summary.frame.minY, accuracy: 1, "The detail badge follows the heading top, not the action row")
        BrewUIElement(doctor.app, .doctorPurposeInfo).assertDoesNotExist()
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
        checkCompactUpgrades(language: "es", locale: "es_ES", description: "Spanish")
        checkCompactUpgrades(language: "sv", locale: "sv_SE", description: "Swedish")
    }

    @MainActor
    private func checkCompactUpgrades(language: String, locale: String, description: String) {
        let upgrades = launch(
            .installedBasic,
            environment: freshWindow,
            arguments: ["-AppleLanguages", "(\(language))", "-AppleLocale", locale],
        ).sidebar.goToUpgrades().assertHasPackage("ripgrep")
        let window = upgrades.app.windows.firstMatch
        let originalWidth = window.frame.width
        defer {
            let widthChange = originalWidth - window.frame.width
            if abs(widthChange) > 1 {
                _ = window.resizeWindow(by: CGVector(dx: widthChange, dy: 0))
            }
            upgrades.app.terminate()
        }
        let widths: [CGFloat] = [min(1024, NSScreen.main?.visibleFrame.width ?? 1024), 820]
        for width in widths {
            let currentWidth = window.frame.width
            if abs(currentWidth - width) > 1 {
                _ = window.resizeWindow(by: CGVector(dx: width - currentWidth, dy: 0))
            }
            XCTAssertEqual(window.frame.width, width, accuracy: 1)
            BrewApp.activate(upgrades.app)
            let header = BrewUIElement(upgrades.app, .paneHeader, in: upgrades.root.element).element
            let summary = BrewUIElement(upgrades.app, .paneHeaderSummary, in: header).element
            let buttons = header.buttons.allElementsBoundByIndex
            XCTAssertEqual(buttons.count, 2)
            for button in buttons {
                XCTAssertTrue(button.isHittable)
                XCTAssertGreaterThanOrEqual(button.frame.minX, header.frame.minX)
                XCTAssertLessThanOrEqual(button.frame.maxX, header.frame.maxX)
            }
            if let firstButton = buttons.first {
                XCTAssertLessThan(firstButton.frame.minY, summary.frame.minY + 14, "The first action stays on the heading's first line")
            }
            if buttons.count == 2 {
                let first = buttons[0].frame
                let second = buttons[1].frame
                if abs(first.midY - second.midY) > 1 {
                    XCTAssertEqual(first.width, second.width, accuracy: 1, "Only vertically stacked buttons share a width")
                } else {
                    XCTAssertGreaterThan(first.width, second.width, "Horizontal buttons keep their native widths")
                }
            }
            capture("Upgrades compact \(description) \(Int(width))pt", app: upgrades.app, screen: .upgradesScreen)
        }
    }

    @MainActor
    func testTraditionalChineseDarkHeaders() {
        let arguments = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_TW"]
        let environment = windowEnvironment(dark: true)
        let services = launch(.servicesBasic, environment: environment, arguments: arguments).sidebar.goToServices()
        services.row("redis").waitToExist()
        capture("Services dark", app: services.app, screen: .servicesScreen)
        services.app.terminate()
        let doctor = launch(.doctorHasIssues, environment: environment, arguments: arguments).sidebar.goToDoctor()
            .assertShowsIssue(containing: "deprecated or disabled")
        capture("Doctor dark", app: doctor.app, screen: .doctorScreen)
    }

    @MainActor
    func testInstalledHeaderDoesNotRepeatThePageTitle() throws {
        let installed = launch(.installedBasic).assertHasPackage("iterm2")
        let summary = BrewUIElement(installed.app, .paneHeaderSummary).waitToExist().element
        let sidebar = BrewUIElement(installed.app, .sidebar).element
        XCTAssertEqual(summary.frame.minX - sidebar.frame.maxX, 20, accuracy: 1, "Content shares the symmetric pane inset")
        let navigationItem = BrewUIElement(installed.app, .sidebarItem(.installed)).element
        XCTAssertEqual(summary.frame.midY, navigationItem.frame.midY, accuracy: 0.5, "Text boxes share their vertical centre, not their baseline")
        let contentTop = try contentSplitter(in: installed.app).frame.minY
        XCTAssertEqual(summary.frame.midY - contentTop, 20 + 28 / 2, accuracy: 0.5, "The standard first row starts 20pt below the content boundary")
        // 原生 List 将整行文字合并为一个元素，直接比较行的前缘。
        let firstRow = installed.list.row("iterm2").waitToExist().element
        XCTAssertEqual(firstRow.frame.minX, summary.frame.minX, accuracy: 1)
        XCTAssertEqual(installed.root.element.frame.maxX - firstRow.frame.maxX, 20, accuracy: 1, "List content keeps the same trailing inset")
        let descriptions = installed.root.element.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@",
            "Your packages", "Your packages",
        ))
        XCTAssertEqual(descriptions.count, 0, "The window already identifies the Installed page")
    }

    @MainActor
    private func assertSectionSeparatorInsets(in pane: XCUIElement, heading: String, app: XCUIApplication) throws {
        let title = pane.descendants(matching: .staticText)
            .matching(NSPredicate(format: "label == %@ OR value == %@", heading, heading)).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: BrewUITestTimeout.default))
        let window = app.windows.firstMatch
        let screenshot = window.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Section separator gutters - \(heading)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: screenshot.pngRepresentation))
        let scale = try snapshotScale(bitmap, window: window)
        let left = Int((pane.frame.minX - window.frame.minX) * scale)
        let right = Int((pane.frame.maxX - window.frame.minX) * scale)
        let top = Int((title.frame.minY - window.frame.minY) * scale)
        let referenceOffset = max(1, Int(scale))
        var separator: ClosedRange<Int>?
        var separatorY = top
        // 在同一列比较线的上下背景，避免把侧栏阴影当成分隔线。
        for y in max(top, referenceOffset) ..< min(bitmap.pixelsHigh - referenceOffset, top + Int(40 * scale)) {
            func hasLineContrast(at x: Int) throws -> Bool {
                let line = try pixelComponents(bitmap, x: x, y: y)
                return try [y - referenceOffset, y + referenceOffset].allSatisfy { neighbourY in
                    let surface = try pixelComponents(bitmap, x: x, y: neighbourY)
                    return zip(line, surface).contains { abs($0 - $1) > 4.0 / 255 }
                }
            }
            guard try hasLineContrast(at: (left + right) / 2) else { continue }
            let columns = try (left ..< right).filter { x in
                try hasLineContrast(at: x)
            }
            guard columns.count > (right - left) * 4 / 5, let first = columns.first, let last = columns.last else { continue }
            separator = first ... last
            separatorY = y
            break
        }
        let actual = try XCTUnwrap(separator, "The section must retain its visible short separator")
        XCTAssertEqual(actual.lowerBound - left, Int(20 * scale), "\(heading): leading separator gutter must be 20pt")
        XCTAssertEqual(right - actual.upperBound - 1, Int(20 * scale), "\(heading): trailing separator gutter must be 20pt")
        // 采两端未被选中底色覆盖的留白，确保分组底面和端点与正文融合。
        for x in [left + Int(3 * scale), right - Int(3 * scale)] {
            let surface = try pixelComponents(bitmap, x: x, y: separatorY + Int(3 * scale))
            for y in [top, separatorY] {
                let sample = try pixelComponents(bitmap, x: x, y: y)
                let difference = zip(sample, surface).map { abs($0 - $1) }.max() ?? 0
                XCTAssertLessThanOrEqual(difference, 2.0 / 255, "\(heading): the section background must match its list")
            }
        }
    }

    @MainActor
    private func contentSplitter(in app: XCUIApplication) throws -> XCUIElement {
        let window = app.windows.firstMatch
        let sidebar = BrewUIElement(app, .sidebar).element
        let centre = (sidebar.frame.maxX + window.frame.maxX) / 2
        return try XCTUnwrap(window.splitters.allElementsBoundByIndex
            .filter { $0.frame.height > $0.frame.width }
            .min { abs($0.frame.midX - centre) < abs($1.frame.midX - centre) })
    }

    @MainActor
    private func assertUniformContentBoundary(in app: XCUIApplication) throws {
        let window = app.windows.firstMatch
        let splitter = try contentSplitter(in: app)
        let screenshot = window.screenshot()
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: screenshot.pngRepresentation))
        let scale = try snapshotScale(bitmap, window: window)
        let jointX = Int((splitter.frame.midX - window.frame.minX) * scale)
        let topY = Int((splitter.frame.minY - window.frame.minY) * scale)
        let referenceX = jointX - Int(8 * scale)
        let belowY = topY + Int(4 * scale)
        let reference = try pixelComponents(bitmap, x: referenceX, y: topY)
        let below = try pixelComponents(bitmap, x: referenceX, y: belowY)
        // 先证明采样位置确实有线，避免把两个相同的正文背景误判为通过。
        XCTAssertGreaterThan(zip(reference, below).map { abs($0 - $1) }.max() ?? 0, 4.0 / 255)
        for offset in 0 ..< max(1, Int(scale)) {
            let line = try pixelComponents(bitmap, x: referenceX, y: topY + offset)
            let joint = try pixelComponents(bitmap, x: jointX, y: topY + offset)
            for (actual, expected) in zip(joint, line) {
                XCTAssertEqual(actual, expected, accuracy: 1.0 / 255, "The split intersection must not apply the translucent separator twice")
            }
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Content boundary intersection"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func snapshotScale(_ bitmap: NSBitmapImageRep, window: XCUIElement) throws -> CGFloat {
        let size = window.frame.size
        let scale = (CGFloat(bitmap.pixelsHigh) / size.height).rounded()
        let fullWidth = abs(CGFloat(bitmap.pixelsWide) - size.width * scale) <= 1
        let fullHeight = abs(CGFloat(bitmap.pixelsHigh) - size.height * scale) <= 1
        // 若窗口被屏幕裁切，不把变短的截图宽度误用为坐标缩放比例。
        return try XCTUnwrap(
            fullWidth && fullHeight ? scale : nil,
            "Expected an unclipped window screenshot; got \(bitmap.pixelsWide) × \(bitmap.pixelsHigh) for \(size)",
        )
    }

    @MainActor
    private func pixelComponents(_ bitmap: NSBitmapImageRep, x: Int, y: Int) throws -> [CGFloat] {
        XCTAssertTrue((0 ..< bitmap.pixelsWide).contains(x) && (0 ..< bitmap.pixelsHigh).contains(y))
        let colour = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        return [colour.redComponent, colour.greenComponent, colour.blueComponent]
    }

    private func windowEnvironment(dark: Bool) -> [String: String] {
        var environment = freshWindow
        if dark {
            environment[BrewUITestingEnvironmentKey.darkAppearance] = "1"
        }
        return environment
    }

    @MainActor
    private func assertText(_ expected: String, in element: XCUIElement) {
        XCTAssertTrue(element.label == expected || element.value as? String == expected, "Expected ‘\(expected)’ in \(element)")
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication, screen: AXID? = nil) {
        BrewApp.activate(app)
        XCTAssertEqual(app.state, .runningForeground, "Capture the foreground app, never a covered window")
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
            XCTAssertEqual(summary.frame.minX - sidebar.frame.maxX, 20, accuracy: 1, "Headings share the symmetric pane inset")
            let metrics = XCTAttachment(string: "screen: \(root.frame)\nsummary: \(summary.frame)")
            metrics.name = "Header geometry - \(name)"
            metrics.lifetime = .keepAlways
            add(metrics)
        }
        let window = app.windows.firstMatch
        let screenshot = window.screenshot()
        XCTAssertNoThrow(try snapshotScale(XCTUnwrap(NSBitmapImageRep(data: screenshot.pngRepresentation)), window: window))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Header - \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
