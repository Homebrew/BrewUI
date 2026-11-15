import AppKit
import BrewUIComponents
import SwiftUI
import Testing

@MainActor
struct PaneHeaderAlignmentTests {
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
