//
//  BrewColorTokenContrastTests.swift
//  BrewUIComponentsTests
//

import Foundation
import Testing

/// AA is asserted in the **high-contrast** appearances only. The standard palette is the Homebrew
/// palette as designed and several of its pairings sit below 4.5:1 on purpose; it is held instead to
/// the monotonicity invariant below.
struct BrewColorTokenContrastTests {
    /// Neutral text runs everywhere, including the recessed surface and a selected row's brand tint.
    private nonisolated static let neutralBackgrounds = TokenContrastRequirement.contentSurfaces + [
        "SurfaceRecessed",
        "BrandTint",
    ]

    /// Status text never lands on the recessed surface.
    private nonisolated static let statusBackgrounds = TokenContrastRequirement.contentSurfaces + ["BrandTint"]

    nonisolated static let requirements = [
        TokenContrastRequirement("TextPrimary", on: neutralBackgrounds + [
            "StatusSuccessSubtle",
            "StatusWarningSubtle",
            "StatusErrorSubtle",
            "StatusInfoSubtle",
        ]),
        TokenContrastRequirement("TextSecondary", on: neutralBackgrounds + [
            "StatusSuccessSubtle",
            "StatusWarningSubtle",
            "StatusErrorSubtle",
            "StatusInfoSubtle",
        ]),
        TokenContrastRequirement("TextTertiary", on: neutralBackgrounds),

        // Each status is drawn on its own subtle tint, never on another status's.
        TokenContrastRequirement("StatusSuccess", on: statusBackgrounds + ["StatusSuccessSubtle"]),
        TokenContrastRequirement("StatusWarning", on: statusBackgrounds + ["StatusWarningSubtle"]),
        TokenContrastRequirement("StatusError", on: statusBackgrounds + ["StatusErrorSubtle"]),
        TokenContrastRequirement("StatusInfo", on: statusBackgrounds + ["StatusInfoSubtle"]),
        TokenContrastRequirement("TextLink", on: statusBackgrounds + ["StatusInfoSubtle"]),

        TokenContrastRequirement("TextBrand", on: statusBackgrounds),

        // ANSI colours; the console draws on an app surface, not the terminal surface.
        TokenContrastRequirement("TextMagenta", on: TokenContrastRequirement.contentSurfaces),
        TokenContrastRequirement("TextCyan", on: TokenContrastRequirement.contentSurfaces),
    ]

    /// Not appearance-adaptive: always light text on the near-black terminal surface.
    nonisolated static let terminalForegrounds = [
        "CodeDefault",
        "CodeCommand",
        "CodeArgument",
        "CodeOutput",
        "CodeError",
    ]

    @Test(arguments: requirements, BrewColorAsset.Appearance.highContrast)
    func `text token meets WCAG AA in high contrast on every surface it is drawn on`(
        requirement: TokenContrastRequirement,
        appearance: BrewColorAsset.Appearance,
    ) throws {
        for measurement in try requirement.measurements(appearance) {
            #expect(
                measurement.ratio >= TokenContrastRequirement.minimumRatio,
                "\(measurement.label) (\(appearance.rawValue)) is \(String(format: "%.2f", measurement.ratio)):1",
            )
        }
    }

    /// Stops a tweak to a standard value overtaking its high-contrast counterpart.
    @Test(arguments: requirements)
    func `high contrast never reduces contrast`(requirement: TokenContrastRequirement) throws {
        for appearance in BrewColorAsset.Appearance.highContrast {
            let raised = try requirement.measurements(appearance)
            let standard = try requirement.measurements(appearance.standardContrast)

            for (high, base) in zip(raised, standard) {
                #expect(
                    high.ratio >= base.ratio - 0.001,
                    "\(base.label): high contrast \(high.ratio):1 is below standard \(base.ratio):1",
                )
            }
        }
    }

    @Test(arguments: terminalForegrounds, BrewColorAsset.Appearance.allCases)
    func `code token meets WCAG AA on the terminal surface`(
        token: String,
        appearance: BrewColorAsset.Appearance,
    ) throws {
        let foreground = try BrewColorAsset.color(token, appearance)
        let ratio = try foreground.contrastRatio(against: BrewColorAsset.color("Terminal", appearance))

        #expect(ratio >= TokenContrastRequirement.minimumRatio, "\(token) on Terminal is \(ratio):1")
    }

    /// These are fills, not foregrounds, so what has to hold is `TextOnBrand` knocked out of them.
    /// Asserting it is what lets them stay vivid.
    @Test(arguments: ["BrandPrimary", "BrandPrimaryHover", "BrandPrimaryPressed", "StatusWarningBold"])
    func `text knocked out of a filled brand surface meets WCAG AA`(fill: String) throws {
        for appearance in BrewColorAsset.Appearance.allCases {
            let onBrand = try BrewColorAsset.color("TextOnBrand", appearance)
            let ratio = try onBrand.contrastRatio(against: BrewColorAsset.color(fill, appearance))

            #expect(ratio >= TokenContrastRequirement.minimumRatio, "TextOnBrand on \(fill) is \(ratio):1")
        }
    }

    /// The chip is an outline — glyph and ring in the accent — so the bar is WCAG 1.4.11's 3:1 for
    /// non-text content, not 4.5:1. Asserting the weaker bar keeps the chip from constraining the
    /// palette; the accents clear 4.5 anyway as the kind badge's label colour.
    @Test(arguments: ["TextBrand", "StatusInfo"])
    func `the package kind icon chip reads against every row it sits on`(accent: String) throws {
        for appearance in BrewColorAsset.Appearance.highContrast {
            let ink = try BrewColorAsset.color(accent, appearance)

            for row in TokenContrastRequirement.contentSurfaces + ["BrandTint"] {
                for measured in try Self.rowSurfaces(row, appearance) {
                    #expect(
                        ink.contrastRatio(against: measured.color) >= 3,
                        "\(accent) chip on \(measured.label) is \(ink.contrastRatio(against: measured.color)):1",
                    )
                }
            }
        }
    }

    private nonisolated static func rowSurfaces(
        _ name: String,
        _ appearance: BrewColorAsset.Appearance,
    ) throws -> [(label: String, color: SRGBColor)] {
        let color = try BrewColorAsset.color(name, appearance)
        guard color.alpha < 1 else {
            return [(name, color)]
        }
        return try TokenContrastRequirement.tintBases.map { base in
            try ("\(name) over \(base)", color.composited(over: BrewColorAsset.color(base, appearance)))
        }
    }

    /// The knockout is white in standard light (1.95:1, as the badge has always looked), so AA holds
    /// in high contrast and in standard dark, where it is already near-black.
    @Test func `the upgrades count is legible on its capsule wherever the palette promises it`() throws {
        for appearance in BrewColorAsset.Appearance.highContrast + [.dark] {
            let knockout = try BrewColorAsset.color("TextOnWarning", appearance)
            let fill = try BrewColorAsset.color("StatusWarningBold", appearance)

            #expect(
                knockout.contrastRatio(against: fill) >= TokenContrastRequirement.minimumRatio,
                "TextOnWarning on StatusWarningBold (\(appearance.rawValue)) is \(knockout.contrastRatio(against: fill)):1",
            )
        }
    }

    /// Pulling tertiary up to AA squeezes it toward secondary; 1.3x is about the smallest gap that
    /// still reads as a level of emphasis at 11pt.
    @Test func `the neutral text ramp stays ordered and distinguishable`() throws {
        for appearance in BrewColorAsset.Appearance.allCases {
            let surface = try BrewColorAsset.color("Surface", appearance)
            let ratios = try ["TextPrimary", "TextSecondary", "TextTertiary"].map {
                try BrewColorAsset.color($0, appearance).contrastRatio(against: surface)
            }

            #expect(ratios == ratios.sorted(by: >), "\(appearance.rawValue) ramp is out of order: \(ratios)")
            for (stronger, weaker) in zip(ratios, ratios.dropFirst()) {
                #expect(stronger / weaker >= 1.3, "\(appearance.rawValue) ramp steps too close: \(stronger) vs \(weaker)")
            }
        }
    }
}
