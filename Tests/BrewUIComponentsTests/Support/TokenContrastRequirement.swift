//
//  TokenContrastRequirement.swift
//  BrewUIComponentsTests
//

import Foundation

/// One foreground token together with every background token it is placed on in the app.
///
/// Pairings are hand-maintained, not a cross-product: requiring success green to stay legible on the
/// error tint would cost real chroma for a combination no screen renders.
nonisolated struct TokenContrastRequirement {
    /// WCAG 2.1 AA for small text. Every style in `BrewFonts` is 17pt or smaller, so the 3:1
    /// large-text allowance never applies.
    static let minimumRatio = 4.5

    let foreground: String
    let backgrounds: [String]

    init(_ foreground: String, on backgrounds: [String]) {
        self.foreground = foreground
        self.backgrounds = backgrounds
    }

    /// Backgrounds every content surface shares.
    static let contentSurfaces = ["SurfaceElevated", "Surface", "WindowBase"]

    /// Translucent tints have no single rendered value, so they are measured over both panel
    /// surfaces and the worse of the two has to pass.
    static let tintBases = ["Surface", "SurfaceElevated"]

    /// Every rendered (foreground, background) pair, measured.
    func measurements(_ appearance: BrewColorAsset.Appearance) throws -> [(label: String, ratio: Double)] {
        let foregroundColor = try BrewColorAsset.color(foreground, appearance)
        var results: [(label: String, ratio: Double)] = []
        for background in backgrounds {
            let backgroundColor = try BrewColorAsset.color(background, appearance)
            if backgroundColor.alpha < 1 {
                for base in Self.tintBases {
                    let resolved = try backgroundColor.composited(over: BrewColorAsset.color(base, appearance))
                    results.append((
                        "\(foreground) on \(background) over \(base)",
                        foregroundColor.contrastRatio(against: resolved),
                    ))
                }
            } else {
                results.append((
                    "\(foreground) on \(background)",
                    foregroundColor.contrastRatio(against: backgroundColor),
                ))
            }
        }
        return results
    }
}
