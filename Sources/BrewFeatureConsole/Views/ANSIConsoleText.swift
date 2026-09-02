//
//  ANSIConsoleText.swift
//  BrewFeatureConsole
//

import AppKit
import BrewCore
import BrewUIComponents
import SwiftUI

/// Renders output lines into the attributed text the console's text view displays.
///
/// Colours are named on the SwiftUI token palette and bridged with `NSColor(_:)`, which keeps the
/// asset's light/dark variants — the design system stays the source even though the drawing is AppKit's.
enum ANSIConsoleText {
    static let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    static let boldFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .bold)

    private static let lineSpacing = BrewSpacing.xxs

    /// Newline-terminated to match ``ConsoleTranscript/text(of:)``, whose offsets address this text.
    static func attributed(for line: BrewCommandOutputLine) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let fallback = defaultColor(for: line.stream)
        for span in line.spans {
            result.append(NSAttributedString(
                string: span.text,
                attributes: attributes(
                    color: span.style.foreground.map(color(for:)) ?? fallback,
                    bold: span.style.bold,
                ),
            ))
        }
        result.append(NSAttributedString(string: "\n", attributes: attributes(color: fallback, bold: false)))
        return result
    }

    static func attributed(for lines: [BrewCommandOutputLine]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for line in lines {
            result.append(attributed(for: line))
        }
        return result
    }

    static func defaultColor(for stream: BrewCommandOutputLine.Stream) -> Color {
        switch stream {
        case .stdout:
            .brewTextPrimary
        case .stderr:
            .brewStatusError
        }
    }

    /// Bright variants reuse their base hue, since the display palette doesn't distinguish them.
    static func color(for ansiColor: ANSIColor) -> Color {
        switch ansiColor {
        case .black, .brightBlack:
            .brewTextSecondary
        case .red, .brightRed:
            .brewStatusError
        case .green, .brightGreen:
            .brewStatusSuccess
        case .yellow, .brightYellow:
            .brewStatusWarning
        case .blue, .brightBlue:
            .brewStatusInfo
        case .magenta, .brightMagenta:
            .purple
        case .cyan, .brightCyan:
            .cyan
        case .white, .brightWhite:
            .brewTextPrimary
        }
    }

    private static func attributes(color: Color, bold: Bool) -> [NSAttributedString.Key: Any] {
        [
            .font: bold ? boldFont : font,
            .foregroundColor: NSColor(color),
            .paragraphStyle: paragraphStyle,
        ]
    }

    private static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        return style
    }()
}
