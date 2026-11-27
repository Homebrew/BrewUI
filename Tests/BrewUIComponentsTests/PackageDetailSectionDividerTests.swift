import AppKit
import BrewUIComponents
import SwiftUI
import Testing

@MainActor
struct PackageDetailSectionDividerTests {
    @Test(arguments: [false, true])
    func `detail separators match the native divider on the same surface`(dark: Bool) throws {
        _ = NSApplication.shared
        let background = dark ? Color.black : Color.white
        let content = VStack(spacing: 0) {
            PackageDetailSectionDivider().frame(height: 8)
            Divider().frame(height: 8)
        }
        .frame(width: 64, height: 16)
        .background(background)
        .environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 64, height: 16), styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let x = bitmap.pixelsWide / 2
        let detail = try components(bitmap, x: x, y: bitmap.pixelsHigh / 4)
        let native = try components(bitmap, x: x, y: bitmap.pixelsHigh * 3 / 4)
        let surface = try components(bitmap, x: x, y: 0)

        #expect(zip(native, surface).contains { abs($0 - $1) > 4.0 / 255 }, "The reference must contain a visible native divider")
        #expect(zip(detail, native).allSatisfy { abs($0 - $1) <= 1.0 / 255 }, "Detail \(detail) must match native \(native)")
    }

    private func components(_ bitmap: NSBitmapImageRep, x: Int, y: Int) throws -> [CGFloat] {
        let colour = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        return [colour.redComponent, colour.greenComponent, colour.blueComponent]
    }
}
