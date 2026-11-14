import AppKit
import BrewUIComponents
import SwiftUI
import Testing

@MainActor
struct DetailPaneContentTests {
    @Test(arguments: [44.0, 70.0, 104.0])
    func `the icon anchors the entire detail without changing centred content`(textHeight: CGFloat) {
        let content = VStack(alignment: .leading, spacing: BrewSpacing.xl) {
            HStack(alignment: .center, spacing: BrewSpacing.md) {
                Color.clear.frame(width: 44, height: 44).brewDetailTopAnchor()
                Color.clear.frame(width: 170, height: textHeight)
            }
            Color.clear.frame(height: 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brewDetailPaneContent()
        .frame(width: 300)
        let host = NSHostingView(rootView: content)
        host.layoutSubtreeIfNeeded()

        let iconInset = max(0, (textHeight - 44) / 2)
        let topPadding = max(0, firstActionTop - iconInset)
        let expectedHeight = max(44, textHeight) + BrewSpacing.xl * 2 + 30 + topPadding
        #expect(abs(host.fittingSize.height - expectedHeight) < 0.5)
    }

    @Test func `content without a logo uses the shared header inset`() {
        let content = Color.clear.frame(height: 40).brewDetailPaneContent().frame(width: 300)
        let host = NSHostingView(rootView: content)
        host.layoutSubtreeIfNeeded()

        #expect(abs(host.fittingSize.height - (40 + BrewSpacing.xl + firstActionTop)) < 0.5)
    }

    private var firstActionTop: CGFloat {
        let reference = NSHostingView(rootView: Text(verbatim: " ").font(.brewBody))
        return BrewSpacing.sm * 2 + reference.fittingSize.height / 2 - BrewLayout.headerActionHeight / 2
    }
}
