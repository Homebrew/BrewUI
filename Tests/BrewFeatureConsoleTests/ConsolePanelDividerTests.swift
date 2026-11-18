import AppKit
@testable import BrewFeatureConsole
import BrewUIComponents
import SwiftUI
import Testing

@MainActor
struct ConsolePanelDividerTests {
    @Test(arguments: [false, true], [1, 2])
    func `the toolbar divider keeps the native strength`(dark: Bool, scale: Int) throws {
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
        let previous = try render(reference(dividerOpacity: 0.4), size: size, dark: dark, scale: scale)
        let x = native.pixelsWide / 2
        let row = Int(BrewLayout.consoleToolbarHeight) * scale
        let band = (row - 2 * scale) ... (row + 2 * scale)

        // 用旧版作为反例，不为系统分隔线规定最低色差。
        let nativeBand = try band.map { try components(native, x: x, y: $0) }
        let previousBand = try band.map { try components(previous, x: x, y: $0) }
        let actualBand = try band.map { try components(actual, x: x, y: $0) }
        try #require(nativeBand != previousBand, "The render must distinguish the native divider from its previous 40% opacity")
        #expect(actualBand == nativeBand)
    }

    private func render(_ content: some View, size: NSSize, dark: Bool, scale: Int) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, dark ? .dark : .light))
        renderer.scale = CGFloat(scale)
        return try NSBitmapImageRep(cgImage: #require(renderer.cgImage))
    }

    private func components(_ bitmap: NSBitmapImageRep, x: Int, y: Int) throws -> [CGFloat] {
        let colour = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        return [colour.redComponent, colour.greenComponent, colour.blueComponent]
    }
}
