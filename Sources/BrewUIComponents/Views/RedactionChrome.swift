//
//  RedactionChrome.swift
//  BrewUIComponents
//

import SwiftUI

public extension View {
    /// Hides decorative chrome while a placeholder is on screen, keeping its layout.
    ///
    /// `.redacted(reason: .placeholder)` greys out text and images but leaves `Shape` alone, so a
    /// stroked border would stay crisp and coloured around redacted content.
    func brewHiddenWhenRedacted() -> some View {
        modifier(BrewHiddenWhenRedacted())
    }
}

private struct BrewHiddenWhenRedacted: ViewModifier {
    @Environment(\.redactionReasons) private var redactionReasons

    func body(content: Content) -> some View {
        content.opacity(redactionReasons.contains(.placeholder) ? 0 : 1)
    }
}
