import AppKit
@testable import BrewFeatureConsole
import BrewUIComponents
import SwiftUI
import Testing

@MainActor
struct ConsolePanelDividerTests {
    @Test(arguments: [false, true])
    func `the toolbar divider keeps the native strength`(dark: Bool) throws {
        _ = NSApplication.shared
        let harness = ConsoleJobsHarness()
        let toolbar = NSHostingView(rootView: ConsoleToolbar(expanded: .constant(true), viewModel: harness.viewModel))
        let toolbarHeight = toolbar.fittingSize.height
        let panel = ConsolePanel(expanded: .constant(true), commandJobsRepository: harness.repository)
            .frame(width: 600, height: 200)
        let bitmap = try render(panel, size: NSSize(width: 600, height: 200), dark: dark)
        let scale = CGFloat(bitmap.pixelsHigh) / 200
        let x = bitmap.pixelsWide / 2
        let y = Int(toolbarHeight * scale)
        // 保持内容、底面和尺寸一致，只以未修饰的系统线作为外观基准。
        let reference = VStack(spacing: 0) {
            ConsoleToolbar(expanded: .constant(true), viewModel: harness.viewModel)
            Divider()
            ConsoleBody(viewModel: harness.viewModel)
        }
        .frame(width: 600, height: 200)
        .background(Color.brewSurface)
        let nativeBitmap = try render(reference, size: NSSize(width: 600, height: 200), dark: dark)
        let native = try components(nativeBitmap, x: x, y: y)
        let actual = try components(bitmap, x: x, y: y)
        let background = try components(bitmap, x: x, y: y - Int(4 * scale))

        #expect(zip(native, background).contains { abs($0 - $1) > 4.0 / 255 }, "The reference must contain a visible native divider")
        #expect(zip(actual, native).allSatisfy { abs($0 - $1) <= 1.0 / 255 }, "Console \(actual) must match native \(native)")
    }

    private func render(_ content: some View, size: NSSize, dark: Bool) throws -> NSBitmapImageRep {
        let host = NSHostingView(rootView: content.environment(\.colorScheme, dark ? .dark : .light))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        return bitmap
    }

    private func components(_ bitmap: NSBitmapImageRep, x: Int, y: Int) throws -> [CGFloat] {
        let colour = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        return [colour.redComponent, colour.greenComponent, colour.blueComponent]
    }
}
