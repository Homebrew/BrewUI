import AppKit
import BrewUIComponents
import SwiftUI
import Testing

@MainActor
struct PaneHeaderAlignmentTests {
    @Test func `the default window can shrink to fit a 1024 point display`() {
        #expect(BrewLayout.defaultWindowWidth == 1080)
        #expect(BrewLayout.minWindowWidth < 1024)
    }

    @Test(arguments: [210.0, 300.0, 360.0, 430.0])
    func `the header wraps its title then its actions before putting actions below`(width: CGFloat) throws {
        let title = FrameReference()
        let first = FrameReference()
        let second = FrameReference()
        let content = PaneHeader {
            Text(verbatim: "Tillgängliga").font(.brewTitle2)
                .background(FrameProbe(reference: title))
                .brewPaneHeadingAnchor()
        } actions: {
            PaneHeaderActions {
                // 瑞典语三位数升级操作的原生尺寸，窄栏不应压缩这些按钮。
                Color.clear.frame(width: 159, height: 28).background(FrameProbe(reference: first))
                Color.clear.frame(width: 111, height: 28).background(FrameProbe(reference: second))
            }
        } metadata: {
            EmptyView()
        }
        .frame(width: width)
        let host = NSHostingView(rootView: content)
        host.setFrameSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let firstView = try #require(first.view)
        let secondView = try #require(second.view)
        let titleView = try #require(title.view)
        let firstFrame = firstView.convert(firstView.bounds, to: host)
        let secondFrame = secondView.convert(secondView.bounds, to: host)
        let titleFrame = titleView.convert(titleView.bounds, to: host)
        let lineHeight = NSHostingView(rootView: Text(verbatim: " ").font(.brewTitle2)).fittingSize.height
        let firstLineCentre = host.isFlipped ? titleFrame.minY + lineHeight / 2 : titleFrame.maxY - lineHeight / 2
        for frame in [firstFrame, secondFrame] {
            #expect(frame.minX >= 20 && frame.maxX <= width - 20)
        }
        if width <= 300 {
            #expect(firstFrame.maxX == secondFrame.maxX)
            #expect(abs(firstFrame.midY - secondFrame.midY) >= 28)
        } else {
            #expect(firstFrame.midY == secondFrame.midY)
            #expect(firstFrame.maxX < secondFrame.minX)
        }
        if width == 210 {
            #expect(abs(firstFrame.midY - firstLineCentre) > 14)
        } else {
            #expect(firstFrame.minX >= titleFrame.maxX + 7)
            #expect(abs(firstFrame.midY - firstLineCentre) <= 1)
        }
        if width == 360 {
            #expect(titleFrame.height > lineHeight)
        }
    }

    @Test(arguments: [false, true])
    func `only stacked buttons take the wider button's native width`(showsSecondAction: Bool) throws {
        var measuredWidths: [(first: CGFloat, second: CGFloat?)] = []
        for width in [430.0, 210.0] {
            let first = FrameReference()
            let second = FrameReference()
            let content = PaneHeader(wrapsSummary: true) {
                Text(verbatim: "Available").font(.brewTitle2)
            } actions: {
                PaneHeaderActions {
                    Button(action: {}, label: { Text(verbatim: "Upgrade All (20)") })
                        .buttonStyle(.borderedProminent)
                        .background(FrameProbe(reference: first))
                    if showsSecondAction {
                        Button(action: {}, label: { Image(systemName: "arrow.clockwise") })
                            .background(FrameProbe(reference: second))
                    }
                }
            }
            .frame(width: width)
            let host = NSHostingView(rootView: content)
            host.setFrameSize(host.fittingSize)
            host.layoutSubtreeIfNeeded()
            let firstView = try #require(first.view)
            measuredWidths.append((firstView.frame.width, second.view?.frame.width))
        }
        let wide = measuredWidths[0]
        let narrow = measuredWidths[1]
        #expect(narrow.first == wide.first)
        if showsSecondAction {
            #expect(try #require(wide.second) < wide.first)
            #expect(narrow.second == narrow.first)
        } else {
            #expect(narrow.second == nil)
        }
    }

    @Test(arguments: [300.0, 430.0, 700.0])
    func `headers and details use matching horizontal gutters`(width: CGFloat) throws {
        let heading = FrameReference()
        let action = FrameReference()
        let detail = FrameReference()
        let content = VStack(spacing: 0) {
            PaneHeader {
                Text(verbatim: "Available")
                    .font(.brewTitle2)
                    .background(FrameProbe(reference: heading))
            } actions: {
                Color.clear.frame(width: 60, height: BrewLayout.headerActionHeight)
                    .background(FrameProbe(reference: action))
            }
            Color.clear.frame(height: 40)
                .background(FrameProbe(reference: detail))
                .brewDetailPaneContent()
        }
        .frame(width: width)
        let host = NSHostingView(rootView: content)
        host.setFrameSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let headingView = try #require(heading.view)
        let actionView = try #require(action.view)
        let detailView = try #require(detail.view)
        let headingFrame = headingView.convert(headingView.bounds, to: host)
        let actionFrame = actionView.convert(actionView.bounds, to: host)
        let detailFrame = detailView.convert(detailView.bounds, to: host)

        #expect(headingFrame.minX == 20)
        #expect(width - actionFrame.maxX == 20)
        #expect(detailFrame.minX == 20)
        #expect(width - detailFrame.maxX == 20)
    }

    @Test(arguments: [false, true], [
        (240.0, "Available upgrades"),
        (700.0, "Available upgrades"),
        (240.0, "Everything is up to date"),
        (700.0, "Everything is up to date"),
        (240.0, "可用升級"),
        (700.0, "可用升級"),
        (240.0, "所有套件皆為最新版本"),
        (700.0, "所有套件皆為最新版本"),
    ])
    func `the heading and actions share the navigation text centre`(hasTimestamp: Bool, scenario: (CGFloat, String)) throws {
        let (width, headingText) = scenario
        let navigation = FrameReference()
        let heading = FrameReference()
        let action = FrameReference()
        let content = HStack(alignment: .top, spacing: 0) {
            Text(verbatim: "Installed")
                .font(.brewBody)
                .background(FrameProbe(reference: navigation))
                .padding(BrewSpacing.sm)
                .padding(.top, BrewSpacing.sm)
                .brewSidebarFirstRowInset()
            PaneHeader {
                VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                    Text(verbatim: headingText)
                        .font(.brewTitle2)
                        .background(FrameProbe(reference: heading))
                        .brewPaneHeadingAnchor()
                    if hasTimestamp {
                        Text(verbatim: "Last checked just now")
                            .font(.brewCaption)
                    }
                }
            } actions: {
                Color.clear
                    .frame(width: 100, height: BrewLayout.headerActionHeight)
                    .background(FrameProbe(reference: action))
            }
            .frame(width: width)
        }
        let host = NSHostingView(rootView: content)
        host.setFrameSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let navigationView = try #require(navigation.view)
        let headingView = try #require(heading.view)
        let navigationFrame = navigationView.convert(navigationView.bounds, to: host)
        let headingFrame = headingView.convert(headingView.bounds, to: host)
        // 原生视图按像素取整；奇偶高度的文字框最多相差半点。
        #expect(abs(navigationFrame.midY - headingFrame.midY) <= 0.5, "navigation \(navigationFrame), heading \(headingFrame)")
        if width == 700 {
            let actionView = try #require(action.view)
            let actionFrame = actionView.convert(actionView.bounds, to: host)
            #expect(abs(actionFrame.minY - 20) <= 0.5, "The centre pane's first row starts 20pt below the content boundary")
            #expect(abs(actionFrame.midY - headingFrame.midY) <= 0.5, "action \(actionFrame), heading \(headingFrame)")
        }
    }

    @Test(arguments: [44.0, 60.0])
    func `the logo top follows the heading while the hero remains centred`(textHeight: CGFloat) throws {
        let heading = FrameReference()
        let logo = FrameReference()
        let description = FrameReference()
        let content = HStack(alignment: .top, spacing: 0) {
            PaneHeader {
                Text(verbatim: "4 packages")
                    .font(.brewTitle2)
                    .background(FrameProbe(reference: heading))
            }
            .frame(width: 300)
            HStack(alignment: .center, spacing: BrewSpacing.md) {
                Color.clear.frame(width: 44, height: 44)
                    .background(FrameProbe(reference: logo))
                    .brewDetailTopAnchor()
                Color.clear.frame(width: 170, height: textHeight)
                    .background(FrameProbe(reference: description))
            }
            .brewDetailPaneContent()
            .frame(width: 300)
        }
        let host = NSHostingView(rootView: content)
        host.setFrameSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let headingView = try #require(heading.view)
        let logoView = try #require(logo.view)
        let descriptionView = try #require(description.view)
        let headingFrame = headingView.convert(headingView.bounds, to: host)
        let logoFrame = logoView.convert(logoView.bounds, to: host)
        let descriptionFrame = descriptionView.convert(descriptionView.bounds, to: host)
        #expect(abs(logoFrame.minY - headingFrame.minY) <= 0.5, "logo \(logoFrame), heading \(headingFrame)")
        #expect(abs(logoFrame.midY - descriptionFrame.midY) <= 0.5)
    }
}

@MainActor
private final class FrameReference {
    weak var view: NSView?
}

private struct FrameProbe: NSViewRepresentable {
    let reference: FrameReference

    func makeNSView(context _: Context) -> NSView {
        let view = NSView()
        reference.view = view
        return view
    }

    func updateNSView(_: NSView, context _: Context) {}
}
