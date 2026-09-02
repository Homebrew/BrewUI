//
//  BrewSymbols.swift
//  BrewUIComponents
//

import SwiftUI

public extension View {
    /// Styles a two-layer `exclamationmark.*.fill` warning symbol: monochrome yellow normally, with
    /// the inner mark knocked out in near-black under high contrast.
    func brewWarningGlyphStyle() -> some View {
        modifier(BrewWarningGlyphStyle())
    }
}

private struct BrewWarningGlyphStyle: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if contrast == .increased {
            // Palette layer 1 is the mark, layer 2 the enclosure — pinned by `WarningGlyphTests`.
            content
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.brewTextOnBrand, Color.brewStatusWarningBold)
        } else {
            content
                .foregroundStyle(Color.brewStatusWarningBold)
        }
    }
}
