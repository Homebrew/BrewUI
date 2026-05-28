import SwiftUI

// MARK: - Brew Design System — Semantic Colour Tokens

// All colours are derived from the BrewUI Design System spec (Section 4).
// Use these tokens in views — never reference raw hex values directly.

extension Color {
    // MARK: Backgrounds (§4.1)

    /// Root window background.
    static let brewWindowBase = Color("WindowBase")

    /// Cards, panels, list backgrounds.
    static let brewSurface = Color("Surface")

    /// Popovers, sheets, floating panels.
    static let brewSurfaceElevated = Color("SurfaceElevated")

    /// Grouped table background, sidebar.
    static let brewSurfaceRecessed = Color("SurfaceRecessed")

    /// Command console / log output — always near-black.
    static let brewTerminal = Color("Terminal")

    // MARK: Text (§4.2)

    /// Main content text.
    static let brewTextPrimary = Color("TextPrimary")

    /// Supporting text, subtitles.
    static let brewTextSecondary = Color("TextSecondary")

    /// Placeholders, disabled labels.
    static let brewTextTertiary = Color("TextTertiary")

    /// Hyperlinks, tappable secondary actions.
    static let brewTextLink = Color("TextLink")

    /// Text placed on amber brand surfaces — always dark.
    static let brewTextOnBrand = Color("TextOnBrand")

    /// Default terminal/code text — always light on dark terminal bg.
    static let brewCodeDefault = Color("CodeDefault")

    /// brew command verbs in console.
    static let brewCodeCommand = Color("CodeCommand")

    /// Formula/cask names in console.
    static let brewCodeArgument = Color("CodeArgument")

    /// Standard stdout in console.
    static let brewCodeOutput = Color("CodeOutput")

    /// stderr / error output in console.
    static let brewCodeError = Color("CodeError")

    // MARK: Brand / Accent (§4.3)

    /// Primary brand amber — custom BrewUI components only.
    static let brewBrandPrimary = Color("BrandPrimary")

    /// Hover state on custom brand elements.
    static let brewBrandPrimaryHover = Color("BrandPrimaryHover")

    /// Pressed/active state on custom brand elements.
    static let brewBrandPrimaryPressed = Color("BrandPrimaryPressed")

    /// Sidebar selected item background, package row highlight.
    static let brewBrandTint = Color("BrandTint")

    // MARK: Semantic Status (§4.4)

    static let brewStatusSuccess = Color("StatusSuccess")
    static let brewStatusSuccessSubtle = Color("StatusSuccessSubtle")
    static let brewStatusWarning = Color("StatusWarning")
    static let brewStatusWarningSubtle = Color("StatusWarningSubtle")
    static let brewStatusError = Color("StatusError")
    static let brewStatusErrorSubtle = Color("StatusErrorSubtle")
    static let brewStatusInfo = Color("StatusInfo")
    static let brewStatusInfoSubtle = Color("StatusInfoSubtle")

    // MARK: Borders & Separators (§4.5)

    static let brewBorderDefault = Color("BorderDefault")
    static let brewBorderStrong = Color("BorderStrong")
    static let brewBorderBrand = Color("BorderBrand")
    static let brewBorderSeparator = Color("BorderSeparator")
}

// MARK: - ShapeStyle convenience for backgrounds

extension ShapeStyle where Self == Color {
    /// Root window background.
    static var brewWindowBase: Color {
        .brewWindowBase
    }

    /// Cards, panels, list backgrounds.
    static var brewSurface: Color {
        .brewSurface
    }

    /// Popovers, sheets, floating panels.
    static var brewSurfaceElevated: Color {
        .brewSurfaceElevated
    }

    /// Grouped table background, sidebar.
    static var brewSurfaceRecessed: Color {
        .brewSurfaceRecessed
    }

    /// Command console background — always near-black.
    static var brewTerminal: Color {
        .brewTerminal
    }
}
