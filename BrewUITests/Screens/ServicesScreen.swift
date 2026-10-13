//
//  ServicesScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The read-only Services tab: the filtered service list and the selected service's details.
@MainActor
struct ServicesScreen: Screen {
    /// Segments in the order the status picker shows them, so tests pick one without its English title.
    enum Scope: Int {
        case all, running, stopped
    }

    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .servicesScreen)
    }

    var refreshButton: BrewUIButton {
        BrewUIButton(app, .servicesRefreshButton)
    }

    func row(_ name: String) -> BrewUIElement {
        BrewUIElement(app, .serviceRow(name: name), in: root.element)
    }

    func detailValue(_ field: AXID.ServiceDetailField) -> BrewUIStaticText {
        BrewUIStaticText(app, .serviceDetailValue(field), in: root.element)
    }

    @discardableResult
    func show(_ scope: Scope, file: StaticString = #filePath, line: UInt = #line) -> Self {
        let picker = BrewUIElement(app, .servicesScopePicker, in: root.element).waitToExist(file: file, line: line)
        picker.element.radioButtons.element(boundBy: scope.rawValue).click()
        return self
    }

    @discardableResult
    func select(_ name: String, file: StaticString = #filePath, line: UInt = #line) -> Self {
        row(name).waitToExist(file: file, line: line).element.click()
        return self
    }

    /// The list or the empty state: either proves `brew services` answered and decoded.
    @discardableResult
    func assertShowsInventory(
        timeout: TimeInterval = BrewUITestTimeout.command,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        let list = BrewUIElement(app, .servicesList, in: root.element).element
        let empty = BrewUIElement(app, .servicesEmptyState, in: root.element).element
        let shown = NSPredicate { _, _ in list.exists || empty.exists }
        let expectation = XCTNSPredicateExpectation(predicate: shown, object: nil)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected the services list or empty state within \(timeout)s.\n\(BrewUITestDiagnostics.report(for: app))",
            file: file,
            line: line,
        )
        return self
    }
}
