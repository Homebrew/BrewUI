//
//  ServicesScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The Services tab: the filtered service list, selected service's details and runtime controls.
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

    var runtimeButton: BrewUIButton {
        BrewUIButton(app, .serviceRuntimeButton, in: root.element)
    }

    var restartButton: BrewUIButton {
        BrewUIButton(app, .serviceRestartButton, in: root.element)
    }

    var actionError: BrewUIStaticText {
        BrewUIStaticText(app, .serviceActionError, in: root.element)
    }

    var actionRestriction: BrewUIStaticText {
        BrewUIStaticText(app, .serviceActionRestriction, in: root.element)
    }

    @discardableResult
    func performRuntimeAction(file: StaticString = #filePath, line: UInt = #line) -> Self {
        revealAction(runtimeButton, file: file, line: line)
        runtimeButton.tap(file: file, line: line)
        return self
    }

    @discardableResult
    func restart(file: StaticString = #filePath, line: UInt = #line) -> Self {
        revealAction(restartButton, file: file, line: line)
        restartButton.tap(file: file, line: line)
        return self
    }

    private func revealAction(_ button: BrewUIButton, file: StaticString, line: UInt) {
        button.waitToExist(file: file, line: line)
        // The expanded console can leave the action below the detail pane's visible area.
        if !button.element.isHittable {
            BrewUIElement(app, .serviceDetail, in: root.element).element.scroll(byDeltaX: 0, deltaY: -400)
        }
    }

    @discardableResult
    func assertRuntimeActionTitle(_ title: String, file: StaticString = #filePath, line: UInt = #line) -> Self {
        BrewUIStaticText(app, .serviceRuntimeButton, in: root.element)
            .assertContains(title, timeout: BrewUITestTimeout.command, file: file, line: line)
        return self
    }

    @discardableResult
    func assertRuntimeCommandContains(_ substring: String, file: StaticString = #filePath, line: UInt = #line) -> Self {
        assertCommandContains(substring, id: .serviceRuntimeCommand, file: file, line: line)
    }

    @discardableResult
    func assertRestartCommandContains(_ substring: String, file: StaticString = #filePath, line: UInt = #line) -> Self {
        assertCommandContains(substring, id: .serviceRestartCommand, file: file, line: line)
    }

    private func assertCommandContains(_ substring: String, id: AXID, file: StaticString, line: UInt) -> Self {
        let elements = root.element.descendants(matching: .any).matching(identifier: id.rawValue)
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", substring, substring)
        // SwiftUI can expose the card as a container or pass its identifier to flattened children.
        let directMatch = elements.matching(predicate).firstMatch
        let descendantMatch = elements.descendants(matching: .any).matching(predicate).firstMatch
        let shown = NSPredicate { _, _ in directMatch.exists || descendantMatch.exists }
        let expectation = XCTNSPredicateExpectation(predicate: shown, object: nil)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: BrewUITestTimeout.default),
            .completed,
            "Expected \(id.rawValue) to contain “\(substring)”",
            file: file,
            line: line,
        )
        return self
    }

    @discardableResult
    func assertActionsUnavailable(file: StaticString = #filePath, line: UInt = #line) -> Self {
        actionRestriction.waitToExist(file: file, line: line)
        for button in [runtimeButton, restartButton] {
            XCTAssertFalse(
                button.element.exists && button.element.isEnabled,
                "Expected \(button.id.rawValue) to be absent or disabled for a read-only service",
                file: file,
                line: line,
            )
        }
        return self
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
