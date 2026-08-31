//
//  WarningGlyphTests.swift
//  BrewUIComponentsTests
//

import AppKit
import Testing

/// `brewWarningGlyphStyle()` depends on an SF Symbols detail Apple owns: in the two-layer
/// `exclamationmark.*.fill` symbols, palette layer 1 is the mark and layer 2 the enclosure. If that
/// flipped, the modifier would render a yellow mark on a near-black enclosure. Rendering offscreen
/// and sampling pixels is the only way to check it.
struct WarningGlyphTests {
    @Test(arguments: ["exclamationmark.circle.fill", "exclamationmark.triangle.fill"])
    func `palette layer one is the inner mark, not the enclosure`(symbolName: String) throws {
        let rendered = try #require(Self.render(symbolName, palette: [.black, .systemYellow]))

        // The mark sits on the vertical centre line; the lower enclosure is clear of it.
        let mark = try #require(rendered.sample(0.50, 0.42))
        let enclosure = try #require(rendered.sample(0.50, 0.80))

        #expect(
            mark.relativeLuminance < enclosure.relativeLuminance / 4,
            "\(symbolName): mark \(mark.hexDescription) is not clearly darker than enclosure \(enclosure.hexDescription)",
        )
        #expect(
            mark.contrastRatio(against: enclosure) >= TokenContrastRequirement.minimumRatio,
            "\(symbolName): mark on enclosure is \(mark.contrastRatio(against: enclosure)):1",
        )
    }

    /// Only high contrast draws the mark separately; the standard palette renders monochrome.
    @Test func `the warning glyph colours clear AA against each other`() throws {
        for appearance in BrewColorAsset.Appearance.highContrast {
            let mark = try BrewColorAsset.color("TextOnBrand", appearance)
            let enclosure = try BrewColorAsset.color("StatusWarningBold", appearance)

            #expect(mark.contrastRatio(against: enclosure) >= TokenContrastRequirement.minimumRatio)
        }
    }

    // MARK: - Offscreen rendering

    private struct Rendered {
        let bitmap: NSBitmapImageRep

        /// Returns `nil` where the symbol is transparent, so a miss fails rather than reads as black.
        func sample(_ fractionX: Double, _ fractionY: Double) -> SRGBColor? {
            let x = Int(Double(bitmap.pixelsWide) * fractionX)
            let y = Int(Double(bitmap.pixelsHigh) * fractionY)
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), color.alphaComponent > 0.95 else {
                return nil
            }
            return SRGBColor(
                red: color.redComponent,
                green: color.greenComponent,
                blue: color.blueComponent,
                alpha: color.alphaComponent,
            )
        }
    }

    private static func render(_ symbolName: String, palette: [NSColor]) -> Rendered? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: palette))
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil),
              let image = symbol.withSymbolConfiguration(configuration)
        else {
            return nil
        }

        let size = image.size
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width.rounded()),
            pixelsHigh: Int(size.height.rounded()),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0,
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(origin: .zero, size: size))
        return Rendered(bitmap: bitmap)
    }
}
