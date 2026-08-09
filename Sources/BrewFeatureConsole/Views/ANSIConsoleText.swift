//
//  ANSIConsoleText.swift
//  BrewFeatureConsole
//

import BrewCore
import BrewUIComponents
import SwiftUI

/// Spans without an explicit foreground fall back to `defaultColor` so an uncoloured line looks exactly
/// as it did before ANSI support. Bold spans get a bold monospaced font; every other run is left
/// fontless so it inherits the `Text`'s base font — setting a font on all runs would defeat that.
enum ANSIConsoleText {
    /// Renders the line's already-resolved spans. Resolution happens where the line is built — off the
    /// main actor, once — rather than being re-parsed on every render pass.
    static func attributed(for line: BrewCommandOutputLine, defaultColor: Color) -> AttributedString {
        var result = AttributedString()
        for span in line.spans {
            var piece = AttributedString(span.text)
            piece.foregroundColor = span.style.foreground.map(color(for:)) ?? defaultColor
            if span.style.bold {
                piece.font = .system(.body, design: .monospaced).weight(.bold)
            }
            result.append(piece)
        }
        return result
    }

    /// Maps a terminal-palette colour onto a SwiftUI colour. Semantic system colours are used so the
    /// output adapts to light/dark and stays legible on the console surface; bright variants reuse the
    /// same hue since the display palette doesn't distinguish them.
    private static func color(for ansiColor: ANSIColor) -> Color {
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
}
