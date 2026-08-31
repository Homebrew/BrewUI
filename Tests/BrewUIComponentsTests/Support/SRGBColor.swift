//
//  SRGBColor.swift
//  BrewUIComponentsTests
//

import Foundation

/// An sRGB colour with straight (non-premultiplied) alpha, all channels in `0...1`.
nonisolated struct SRGBColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Parses `#RRGGBB` / `RRGGBB`.
    init?(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
        )
    }

    /// WCAG 2.1 relative luminance. Only meaningful for an opaque colour.
    var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.040_45 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    var hexDescription: String {
        func byte(_ channel: Double) -> Int {
            Int((channel * 255).rounded().clamped(to: 0 ... 255))
        }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    /// Source-over composite onto an opaque `background`.
    func composited(over background: SRGBColor) -> SRGBColor {
        SRGBColor(
            red: red * alpha + background.red * (1 - alpha),
            green: green * alpha + background.green * (1 - alpha),
            blue: blue * alpha + background.blue * (1 - alpha),
        )
    }

    /// WCAG 2.1 contrast ratio, `1...21`. Translucent inputs are composited first.
    func contrastRatio(against background: SRGBColor) -> Double {
        let opaqueBackground = background.alpha < 1 ? background.composited(over: .white) : background
        let foreground = alpha < 1 ? composited(over: opaqueBackground) : self
        let lighter = max(foreground.relativeLuminance, opaqueBackground.relativeLuminance)
        let darker = min(foreground.relativeLuminance, opaqueBackground.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    static let white = SRGBColor(red: 1, green: 1, blue: 1)
    static let black = SRGBColor(red: 0, green: 0, blue: 0)
}

private nonisolated extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
