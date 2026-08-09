//
//  BrewUITestDiagnostics.swift
//  BrewUITests
//

import XCTest

/// What the app looked like when an element wasn't found. "Expected installed.screen to exist within
/// 60s" is true and explains nothing: it cannot tell an app that never opened a window from one whose
/// identifiers are wrong, and those have nothing in common.
@MainActor
enum BrewUITestDiagnostics {
    static func report(for app: XCUIApplication) -> String {
        guard app.exists else {
            return "The app is not running — it exited or never launched."
        }

        // A backgrounded app keeps an empty accessibility tree, so every query fails for a reason
        // unrelated to the element asked for.
        guard app.state == .runningForeground else {
            return "The app is running but not in the foreground (state: \(app.state.rawValue))."
        }

        let windows = app.windows.count
        guard windows > 0 else {
            return """
            The app is running but has no window. Its scene never appeared, so no identifier can \
            resolve — look at launch, not at the identifier.
            """
        }

        // Verbose, but the only thing that answers "wrong identifier or wrong screen" without another
        // round trip.
        return """
        The app has \(windows) window(s). Identifiers currently in the tree:
        \(identifiers(in: app).joined(separator: "\n"))

        Full element tree:
        \(app.debugDescription)
        """
    }

    private static func identifiers(in app: XCUIApplication) -> [String] {
        let nonEmpty = NSPredicate(format: "identifier != ''")
        let matches = app.descendants(matching: .any).matching(nonEmpty)
        let found = (0 ..< matches.count).map { matches.element(boundBy: $0).identifier }
        return found.isEmpty ? ["(none — nothing in the tree carries an identifier)"] : Array(Set(found)).sorted()
    }
}
