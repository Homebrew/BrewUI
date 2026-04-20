import SwiftUI

// MARK: - Brew Design System — Typography (§3)

// Two-family split: SF Pro for prose, SF Mono for code/commands.
// Uses system font styles for Dynamic Type support.

extension Font {
    // MARK: Display & Headings

    /// App name, empty state headings — 28pt SF Pro Display.
    static let brewLargeTitle: Font = .largeTitle

    /// Page/section title — 22pt SF Pro Display.
    static let brewTitle1: Font = .title

    /// Panel header — 17pt SF Pro Display Semibold.
    static let brewTitle2: Font = .title2.weight(.semibold)

    /// Sub-section header — 15pt SF Pro Display Semibold.
    static let brewTitle3: Font = .title3.weight(.semibold)

    // MARK: Body & Labels

    /// Standard body text — 13pt SF Pro Text.
    static let brewBody: Font = .body

    /// Secondary info rows — 12pt SF Pro Text.
    static let brewCallout: Font = .callout

    /// List row labels, form labels — SF Pro Text subheadline.
    static let brewSubheadline: Font = .subheadline

    /// Metadata, timestamps, version strings — 11pt SF Pro Text.
    static let brewCaption: Font = .caption

    /// Smallest caption — 10pt SF Pro Text.
    static let brewCaption2: Font = .caption2

    // MARK: Code / Command

    /// Terminal/command output — 12pt SF Mono.
    static let brewCode: Font = .system(size: 12, design: .monospaced)

    /// Inline code references — 11pt SF Mono.
    static let brewCodeSmall: Font = .system(size: 11, design: .monospaced)

    /// Command verb highlight (e.g. `brew install`) — 12pt SF Mono Semibold.
    static let brewCodeBold: Font = .system(size: 12, weight: .semibold, design: .monospaced)
}

// MARK: - View modifiers for common typographic styles

extension View {
    /// Applies the standard code/terminal text style: monospaced font + code default colour.
    func brewCodeStyle() -> some View {
        font(.brewCode)
            .foregroundStyle(Color.brewCodeDefault)
            .lineSpacing(6) // 18pt line height - 12pt font ≈ 6pt extra leading
    }

    /// Applies the command verb style: bold monospaced + amber command colour.
    func brewCommandStyle() -> some View {
        font(.brewCodeBold)
            .foregroundStyle(Color.brewCodeCommand)
    }
}
