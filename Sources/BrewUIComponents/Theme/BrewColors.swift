import SwiftUI

// MARK: - Brew Design System — Semantic Colour Tokens

// All colours are derived from the BrewUI Design System spec (Section 4).
// Use these tokens in views — never reference raw hex values directly.

public extension Color {
    // MARK: Backgrounds (§4.1)

    /// Root window background.
    static let brewWindowBase = Color("WindowBase", bundle: .module)

    /// Cards, panels, list backgrounds.
    static let brewSurface = Color("Surface", bundle: .module)

    /// Popovers, sheets, floating panels.
    static let brewSurfaceElevated = Color("SurfaceElevated", bundle: .module)

    /// Grouped table background, sidebar.
    static let brewSurfaceRecessed = Color("SurfaceRecessed", bundle: .module)

    /// Command console / log output — always near-black.
    static let brewTerminal = Color("Terminal", bundle: .module)

    // MARK: Text (§4.2)

    /// Main content text.
    static let brewTextPrimary = Color("TextPrimary", bundle: .module)

    /// Supporting text, subtitles.
    static let brewTextSecondary = Color("TextSecondary", bundle: .module)

    /// Placeholders, disabled labels.
    static let brewTextTertiary = Color("TextTertiary", bundle: .module)

    /// Hyperlinks, tappable secondary actions.
    static let brewTextLink = Color("TextLink", bundle: .module)

    /// Text placed on amber brand surfaces — always dark.
    static let brewTextOnBrand = Color("TextOnBrand", bundle: .module)

    /// Default terminal/code text — always light on dark terminal bg.
    static let brewCodeDefault = Color("CodeDefault", bundle: .module)

    /// brew command verbs in console.
    static let brewCodeCommand = Color("CodeCommand", bundle: .module)

    /// Formula/cask names in console.
    static let brewCodeArgument = Color("CodeArgument", bundle: .module)

    /// Standard stdout in console.
    static let brewCodeOutput = Color("CodeOutput", bundle: .module)

    /// stderr / error output in console.
    static let brewCodeError = Color("CodeError", bundle: .module)

    // MARK: Brand / Accent (§4.3)

    /// Primary brand amber — custom BrewUI components only.
    static let brewBrandPrimary = Color("BrandPrimary", bundle: .module)

    /// Hover state on custom brand elements.
    static let brewBrandPrimaryHover = Color("BrandPrimaryHover", bundle: .module)

    /// Pressed/active state on custom brand elements.
    static let brewBrandPrimaryPressed = Color("BrandPrimaryPressed", bundle: .module)

    /// Sidebar selected item background, package row highlight.
    static let brewBrandTint = Color("BrandTint", bundle: .module)

    // MARK: Semantic Status (§4.4)

    static let brewStatusSuccess = Color("StatusSuccess", bundle: .module)
    static let brewStatusSuccessSubtle = Color("StatusSuccessSubtle", bundle: .module)
    static let brewStatusWarning = Color("StatusWarning", bundle: .module)
    static let brewStatusWarningSubtle = Color("StatusWarningSubtle", bundle: .module)
    static let brewStatusError = Color("StatusError", bundle: .module)
    static let brewStatusErrorSubtle = Color("StatusErrorSubtle", bundle: .module)
    static let brewStatusInfo = Color("StatusInfo", bundle: .module)
    static let brewStatusInfoSubtle = Color("StatusInfoSubtle", bundle: .module)

    // MARK: Borders & Separators (§4.5)

    static let brewBorderDefault = Color("BorderDefault", bundle: .module)
    static let brewBorderStrong = Color("BorderStrong", bundle: .module)
    static let brewBorderBrand = Color("BorderBrand", bundle: .module)
    static let brewBorderSeparator = Color("BorderSeparator", bundle: .module)
}

// MARK: - ShapeStyle convenience for backgrounds

public extension ShapeStyle where Self == Color {
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
