//
//  AnimatedSplit.swift
//  Brew
//

import AppKit
import SwiftUI

/// Vertical split that hosts two SwiftUI views with a draggable handle between them, where the bottom
/// pane collapses to a fixed height. Hand-rolled instead of `NSSplitView` so we get full control over
/// both the drag (handled by `NSPanGestureRecognizer` for smooth, gesture-pipeline-free updates) and
/// the collapse/expand animation (frame interpolation via `NSAnimationContext` — `NSSplitView`'s
/// animator path doesn't keep the divider chrome in sync, and `withAnimation` doesn't bridge into
/// either anyway).
struct AnimatedSplit<Top: View, Bottom: View>: NSViewRepresentable {
    let collapsed: Bool
    let collapsedHeight: CGFloat
    let expandedHeight: CGFloat
    let minExpandedHeight: CGFloat
    let maxExpandedHeight: CGFloat
    let animation: NSAnimationContextSpec?
    @ViewBuilder let top: () -> Top
    @ViewBuilder let bottom: () -> Bottom

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AnimatedSplitView {
        let topHost = NSHostingView(rootView: top())
        let bottomHost = NSHostingView(rootView: bottom())
        let handleHost = NSHostingView(rootView: SplitDragHandle())
        let view = AnimatedSplitView(
            top: topHost,
            bottom: bottomHost,
            handle: handleHost,
            initialBottomHeight: collapsed ? collapsedHeight : expandedHeight,
            collapsed: collapsed,
            collapsedHeight: collapsedHeight,
            minExpandedHeight: minExpandedHeight,
            maxExpandedHeight: maxExpandedHeight,
        )
        context.coordinator.topHost = topHost
        context.coordinator.bottomHost = bottomHost
        context.coordinator.previousCollapsed = collapsed
        return view
    }

    func updateNSView(_ nsView: AnimatedSplitView, context: Context) {
        if let topHost = context.coordinator.topHost as? NSHostingView<Top> {
            topHost.rootView = top()
        }
        if let bottomHost = context.coordinator.bottomHost as? NSHostingView<Bottom> {
            bottomHost.rootView = bottom()
        }

        nsView.collapsedHeight = collapsedHeight
        nsView.minExpandedHeight = minExpandedHeight
        nsView.maxExpandedHeight = maxExpandedHeight

        let collapsedChanged = context.coordinator.previousCollapsed != collapsed
        context.coordinator.previousCollapsed = collapsed

        if collapsedChanged {
            let target = collapsed ? collapsedHeight : expandedHeight
            nsView.setBottomHeight(target, collapsed: collapsed, animation: animation)
        }
    }

    @MainActor
    final class Coordinator {
        weak var topHost: NSView?
        weak var bottomHost: NSView?
        var previousCollapsed: Bool?
    }
}

@MainActor
final class AnimatedSplitView: NSView {
    static let handleThickness: CGFloat = 6
    static let dividerThickness: CGFloat = 1

    let topHost: NSView
    let bottomHost: NSView
    let handleHost: NSView
    /// Always-visible hairline at the boundary between the two panes — including when collapsed, where
    /// the (hidden) handle would otherwise leave no separation between the panes.
    let dividerHost: NSView

    var collapsedHeight: CGFloat
    var minExpandedHeight: CGFloat
    var maxExpandedHeight: CGFloat
    private(set) var collapsed: Bool
    private var bottomHeight: CGFloat
    private var dragStartHeight: CGFloat?

    init(
        top: NSView,
        bottom: NSView,
        handle: NSView,
        initialBottomHeight: CGFloat,
        collapsed: Bool,
        collapsedHeight: CGFloat,
        minExpandedHeight: CGFloat,
        maxExpandedHeight: CGFloat,
    ) {
        topHost = top
        bottomHost = bottom
        handleHost = handle
        dividerHost = NSHostingView(rootView: Color.brewBorderSeparator)
        bottomHeight = initialBottomHeight
        self.collapsed = collapsed
        self.collapsedHeight = collapsedHeight
        self.minExpandedHeight = minExpandedHeight
        self.maxExpandedHeight = maxExpandedHeight
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(topHost)
        addSubview(bottomHost)
        addSubview(handleHost)
        addSubview(dividerHost)
        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        handleHost.addGestureRecognizer(pan)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        applyLayout(forBottomHeight: bottomHeight, animated: false)
    }

    func setBottomHeight(_ newHeight: CGFloat, collapsed: Bool, animation: NSAnimationContextSpec?) {
        self.collapsed = collapsed
        let target = clamp(newHeight, collapsed: collapsed)
        bottomHeight = target
        if let animation {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = animation.duration
                ctx.timingFunction = animation.timingFunction
                ctx.allowsImplicitAnimation = true
                applyLayout(forBottomHeight: target, animated: true)
            }
        } else {
            applyLayout(forBottomHeight: target, animated: false)
        }
    }

    private func applyLayout(forBottomHeight bottom: CGFloat, animated: Bool) {
        let total = bounds.height
        guard total > 0 else {
            return
        }
        let width = bounds.width
        let handleH = collapsed ? 0 : Self.handleThickness
        let dividerH = Self.dividerThickness
        let bottomH = max(0, min(bottom, total))
        let topH = max(0, total - bottomH - handleH - dividerH)

        // NSView coordinates are bottom-up by default: y=0 is the bottom edge. Stacking from the
        // bottom: bottom pane, handle grip, hairline divider, top pane.
        let bottomFrame = NSRect(x: 0, y: 0, width: width, height: bottomH)
        let handleFrame = NSRect(x: 0, y: bottomH, width: width, height: handleH)
        let dividerFrame = NSRect(x: 0, y: bottomH + handleH, width: width, height: dividerH)
        let topFrame = NSRect(x: 0, y: bottomH + handleH + dividerH, width: width, height: topH)

        if animated {
            bottomHost.animator().frame = bottomFrame
            handleHost.animator().frame = handleFrame
            dividerHost.animator().frame = dividerFrame
            topHost.animator().frame = topFrame
        } else {
            bottomHost.frame = bottomFrame
            handleHost.frame = handleFrame
            dividerHost.frame = dividerFrame
            topHost.frame = topFrame
        }
        handleHost.isHidden = collapsed
    }

    private func clamp(_ value: CGFloat, collapsed: Bool) -> CGFloat {
        if collapsed {
            return collapsedHeight
        }
        return max(min(value, maxExpandedHeight), minExpandedHeight)
    }

    @objc private func handlePan(_ recognizer: NSPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            dragStartHeight = bottomHeight
        case .changed:
            guard let start = dragStartHeight else {
                return
            }
            // Non-flipped NSView: positive translation.y == cursor moved up == bottom pane grows.
            let proposed = start + recognizer.translation(in: self).y
            bottomHeight = clamp(proposed, collapsed: false)
            applyLayout(forBottomHeight: bottomHeight, animated: false)
        case .ended, .cancelled, .failed:
            dragStartHeight = nil
        default:
            break
        }
    }
}

private struct SplitDragHandle: View {
    var body: some View {
        Rectangle()
            .fill(Color.brewBorderSeparator.opacity(0.5))
            .overlay {
                Capsule()
                    .fill(Color.brewBorderStrong)
                    .frame(width: 28, height: 2)
            }
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

struct NSAnimationContextSpec {
    let duration: CFTimeInterval
    let timingFunction: CAMediaTimingFunction?

    static let brewFast = NSAnimationContextSpec(
        duration: 0.15,
        timingFunction: CAMediaTimingFunction(name: .easeOut),
    )
}
