import BrewAccessibilityID
import XCTest

final class ServicesUITests: BrewUITestCase {
    @MainActor
    func testReadOnlyInventoryAndStatusFilters() {
        let app = launch(.servicesBasic).app
        app.typeKey("2", modifierFlags: .command)
        BrewUIElement(app, .serviceRow(name: "redis")).assertExists()
        BrewUIElement(app, .serviceRow(name: "unbound")).assertExists()

        app.radioButtons["Running"].click()
        BrewUIElement(app, .serviceRow(name: "redis")).assertExists()
        BrewUIElement(app, .serviceRow(name: "unbound")).assertDoesNotExist()
        app.radioButtons["Stopped"].click()
        BrewUIElement(app, .serviceRow(name: "redis")).assertDoesNotExist()
        BrewUIElement(app, .serviceRow(name: "unbound")).assertExists()
        BrewUIElement(app, .serviceRow(name: "postgresql@17")).assertExists()
        BrewUIButton(app, .servicesRefreshButton).tap()
        BrewUIElement(app, .serviceRow(name: "unbound")).assertExists()
        app.radioButtons["All"].click()
        BrewUIElement(app, .serviceRow(name: "redis")).assertExists()
        XCTAssertFalse(app.buttons["Start"].exists)
        XCTAssertFalse(app.buttons["Stop"].exists)
        XCTAssertFalse(app.switches.firstMatch.exists)
    }

    @MainActor
    func testFilteringPreservesTheDetailPaneWidth() throws {
        let app = launch(.servicesBasic).app
        BrewUIButton(app, .sidebarItem(.services)).tap()
        BrewUIElement(app, .serviceRow(name: "redis")).waitToExist().element.click()
        let detail = BrewUIElement(app, .serviceDetail).waitToExist().element
        let divider = try XCTUnwrap(app.splitters.allElementsBoundByIndex.min {
            abs($0.frame.midX - detail.frame.minX) < abs($1.frame.midX - detail.frame.minX)
        })
        let dividerX = divider.frame.midX
        let windowWidth = app.windows.firstMatch.frame.width
        for scope in ["Stopped", "Running", "All"] {
            app.radioButtons[scope].click()
            XCTAssertEqual(divider.frame.midX, dividerX, accuracy: 2, "Divider moved for \(scope)")
            XCTAssertEqual(app.windows.firstMatch.frame.width, windowWidth, accuracy: 2)
        }
    }

    @MainActor
    func testReadOnlyDetailsShowLoginRegistrationAndPaths() {
        let app = launch(.servicesBasic).app
        BrewUIButton(app, .sidebarItem(.services)).tap()
        BrewUIElement(app, .serviceRow(name: "redis")).waitToExist().element.click()
        XCTAssertTrue(app.staticTexts["Schedulable"].exists)
        XCTAssertTrue(app.staticTexts["Yes"].waitForExistence(timeout: BrewUITestTimeout.default))
        XCTAssertTrue(app.staticTexts["/fixtures/redis.plist"].exists)
        XCTAssertTrue(app.staticTexts["/fixtures/redis-error.log"].exists)
        XCTAssertTrue(app.staticTexts["43210"].exists)
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Unknown"].waitForExistence(timeout: BrewUITestTimeout.default))
        BrewUIElement(app, .serviceRow(name: "postgresql@17")).element.click()
        XCTAssertTrue(app.staticTexts["No"].waitForExistence(timeout: BrewUITestTimeout.default))
        BrewUIElement(app, .serviceRow(name: "unbound")).element.click()
        XCTAssertTrue(app.staticTexts["78"].exists)
        XCTAssertTrue(app.staticTexts["No error log path reported."].exists)
    }
}
