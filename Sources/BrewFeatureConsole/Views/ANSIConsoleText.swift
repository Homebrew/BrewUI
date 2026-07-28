//
//  ANSIConsoleText.swift
//  BrewFeatureConsole
//

import BrewCore
import BrewUIComponents
import SwiftUI

/// Builds the styled `AttributedString` the console renders for one output line, mapping the
/// terminal-palette colours parsed by ``ANSIParser`` onto SwiftUI colours.
///
/// Spans without an explicit foreground fall back to `defaultColor` (the stream's colour: red for
/// stderr, primary for stdout) so an uncoloured line looks exactly as it did before ANSI support.
/// Bold spans get a bold monospaced font; every other run inherits the `Text`'s base font.
enum ANSIConsoleText {
    static func attributed(for line: BrewCommandOutputLine, defaultColor: Color) -> AttributedString {
        var result = AttributedString()
        for span in ANSIParser.parse(line.text) {
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
