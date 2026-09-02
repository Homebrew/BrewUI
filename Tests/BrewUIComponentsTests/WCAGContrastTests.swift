//
//  WCAGContrastTests.swift
//  BrewUIComponentsTests
//

import Foundation
import Testing

/// Verifies the contrast arithmetic against values published in WCAG 2.1.
struct WCAGContrastTests {
    @Test func `black on white is the maximum ratio`() {
        #expect(abs(SRGBColor.black.contrastRatio(against: .white) - 21) < 0.001)
    }

    @Test func `a colour against itself is the minimum ratio`() throws {
        let amber = try #require(SRGBColor(hex: "#E8971C"))
        #expect(abs(amber.contrastRatio(against: amber) - 1) < 0.001)
    }

    @Test func `contrast is symmetric`() throws {
        let amber = try #require(SRGBColor(hex: "#E8971C"))
        let ratio = amber.contrastRatio(against: .white)
        #expect(abs(ratio - SRGBColor.white.contrastRatio(against: amber)) < 0.001)
    }

    @Test func `relative luminance matches the WCAG definition at the sRGB primaries`() {
        // The luminance coefficients are exactly the weights applied to fully saturated primaries.
        #expect(abs(SRGBColor(red: 1, green: 0, blue: 0).relativeLuminance - 0.2126) < 0.000_1)
        #expect(abs(SRGBColor(red: 0, green: 1, blue: 0).relativeLuminance - 0.7152) < 0.000_1)
        #expect(abs(SRGBColor(red: 0, green: 0, blue: 1).relativeLuminance - 0.0722) < 0.000_1)
    }

    @Test func `mid grey on white is the widely published ratio`() throws {
        let grey = try #require(SRGBColor(hex: "#767676"))
        // #767676 is the canonical "darkest grey that still passes AA on white" example.
        #expect(abs(grey.contrastRatio(against: .white) - 4.54) < 0.01)
    }

    @Test func `a translucent foreground is measured after compositing`() {
        let halfBlack = SRGBColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        let composited = halfBlack.composited(over: .white)

        #expect(composited.alpha == 1)
        #expect(abs(halfBlack.contrastRatio(against: .white) - composited.contrastRatio(against: .white)) < 0.001)
        #expect(halfBlack.contrastRatio(against: .white) < SRGBColor.black.contrastRatio(against: .white))
    }

    @Test func `a translucent background is composited onto white before measuring`() {
        let tint = SRGBColor(red: 0, green: 0, blue: 0, alpha: 0.2)
        let opaqueTint = tint.composited(over: .white)

        #expect(abs(SRGBColor.black.contrastRatio(against: tint) - SRGBColor.black.contrastRatio(against: opaqueTint)) < 0.001)
    }

    @Test func `hex parsing round-trips`() throws {
        let colour = try #require(SRGBColor(hex: "#3CB371"))
        #expect(colour.hexDescription == "#3CB371")
        #expect(SRGBColor(hex: "3CB371") == colour)
        #expect(SRGBColor(hex: "#3CB37") == nil)
        #expect(SRGBColor(hex: "not a colour") == nil)
    }
}

struct BrewColorAssetTests {
    @Test func `reads a universal colour set in both appearances`() throws {
        // TextOnBrand is deliberately identical in both appearances.
        let light = try BrewColorAsset.color("TextOnBrand", .light)
        let dark = try BrewColorAsset.color("TextOnBrand", .dark)

        #expect(light == dark)
        #expect(light.hexDescription == "#1A1A1A")
    }

    @Test func `resolves the dark entry of an appearance-aware colour set`() throws {
        let light = try BrewColorAsset.color("TextPrimary", .light)
        let dark = try BrewColorAsset.color("TextPrimary", .dark)

        #expect(light.relativeLuminance < dark.relativeLuminance)
    }

    @Test func `preserves alpha on translucent colour sets`() throws {
        let border = try BrewColorAsset.color("BorderDefault", .light)

        #expect(abs(border.alpha - 0.08) < 0.001)
    }

    @Test func `throws a descriptive error for an unknown colour set`() {
        #expect(throws: BrewColorAsset.LoadError.self) {
            try BrewColorAsset.color("NoSuchColour", .light)
        }
    }

    /// The reader resolves an exact match or the universal entry, so a colour set that declared
    /// `dark` without `highContrastDark` would fall through to the light value.
    @Test func `every colour set that varies by luminosity declares a high-contrast dark value`() throws {
        for name in try BrewColorAsset.allNames() {
            let declared = try BrewColorAsset.declaredAppearances(name)
            if declared.contains(.dark) {
                #expect(
                    declared.contains(.highContrastDark),
                    "\(name) declares a dark value but no high-contrast dark value",
                )
            }
        }
    }

    @Test func `enumerates every colour set in the catalogue`() throws {
        let names = try BrewColorAsset.allNames()

        #expect(names.contains("BrandPrimary"))
        #expect(names.contains("TextTertiary"))
        #expect(names == names.sorted())
        for name in names {
            for appearance in BrewColorAsset.Appearance.allCases {
                #expect(throws: Never.self) { try BrewColorAsset.color(name, appearance) }
            }
        }
    }
}
