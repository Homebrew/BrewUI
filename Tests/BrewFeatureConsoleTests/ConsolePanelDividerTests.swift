import AppKit
@testable import BrewFeatureConsole
import BrewUIComponents
import SwiftUI
import Testing

@MainActor
struct ConsolePanelDividerTests {
    @Test(arguments: [false, true], [1, 2])
    func `the toolbar divider keeps the native strength`(dark: Bool, scale: Int) throws {
        _ = NSApplication.shared
        let harness = ConsoleJobsHarness()
        let size = NSSize(width: 600, height: 200)
        let panel = ConsolePanel(expanded: .constant(true), commandJobsRepository: harness.repository)
        func reference(dividerOpacity: Double) -> some View {
            VStack(spacing: 0) {
                ConsoleToolbar(expanded: .constant(true), viewModel: harness.viewModel)
                Divider().opacity(dividerOpacity)
                ConsoleBody(viewModel: harness.viewModel)
            }
            .background(Color.brewSurface)
        }
        let actual = try render(panel, size: size, dark: dark, scale: scale)
        let native = try render(reference(dividerOpacity: 1), size: size, dark: dark, scale: scale)
        let background = try render(reference(dividerOpacity: 0), size: size, dark: dark, scale: scale)
        let x = native.pixelsWide / 2
        let row = Int(BrewLayout.consoleToolbarHeight) * scale
        let band = (row - 2 * scale) ... (row + 2 * scale)
        var hasNativeDivider = false

        // 原生细线会按背板像素取整；比较整个交界带，不猜它落在哪一行。
        // 透明基准保留相同几何和两侧不同底色，只消除分隔线的绘制。
        for y in band {
            let expected = try components(native, x: x, y: y)
            let undrawn = try components(background, x: x, y: y)
            let measured = try components(actual, x: x, y: y)
            hasNativeDivider = hasNativeDivider || zip(expected, undrawn).contains { abs($0 - $1) > 4.0 / 255 }
            #expect(zip(measured, expected).allSatisfy { abs($0 - $1) <= 1.0 / 255 }, "Row \(y): console \(measured) must match native \(expected)")
        }
        #expect(hasNativeDivider, "The reference must contain a visible native divider")
    }

    private func render(_ content: some View, size: NSSize, dark: Bool, scale: Int) throws -> NSBitmapImageRep {
        let host = NSHostingView(rootView: content.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, dark ? .dark : .light))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width) * scale,
            pixelsHigh: Int(size.height) * scale,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0,
        ))
        bitmap.size = size
        host.cacheDisplay(in: host.bounds, to: bitmap)
        return bitmap
    }

    private func components(_ bitmap: NSBitmapImageRep, x: Int, y: Int) throws -> [CGFloat] {
        let colour = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        return [colour.redComponent, colour.greenComponent, colour.blueComponent]
    }
}
