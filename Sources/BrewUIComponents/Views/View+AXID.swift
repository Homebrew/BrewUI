//
//  View+AXID.swift
//  BrewUIComponents
//

import BrewAccessibilityID
import SwiftUI

public extension View {
    /// Attaches a stable, test-visible identity to a view.
    ///
    /// Always prefer this over `accessibilityIdentifier(_:)` with a literal: the raw string lives in
    /// exactly one place (``AXID``), which both the app and the UI-test target link.
    /// This is orthogonal to `accessibilityLabel` — labels stay for VoiceOver, identifiers for tests.
    func axid(_ id: AXID) -> some View {
        accessibilityIdentifier(id.rawValue)
    }
}
