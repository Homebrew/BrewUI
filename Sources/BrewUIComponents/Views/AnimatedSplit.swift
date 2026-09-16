//
//  AnimatedSplit.swift
//  Brew
//

import AppKit
import SwiftUI

/// Vertical split that hosts two SwiftUI views with a draggable handle between them, where the bottom
/// pane collapses to a fixed height. Hand-rolled instead of `NSSplitView` so we get full control over
/// both the drag (handled by native `NSView` mouse tracking for direct, gesture-pipeline-free updates) and
/// the collapse/expand animation (frame interpolation via `NSAnimationContext` — `NSSplitView`'s
/// animator path doesn't keep the divider chrome in sync, and `withAnimation` doesn't bridge into
/// either anyway).
public struct AnimatedSplit<Top: View, Bottom: View>: NSViewRepresentable {
    let collapsed: Bool
    let collapsedHeight: CGFloat
    @Binding var expandedHeight: CGFloat
    let minExpandedHeight: CGFloat
    let maxExpandedHeight: CGFloat
    /// Space the top pane keeps when the two cannot both be satisfied. The bottom pane yields to it.
    let minTopHeight: CGFloat
    let animation: NSAnimationContextSpec?
    @ViewBuilder let top: () -> Top
    @ViewBuilder let bottom: () -> Bottom

    public init(
        collapsed: Bool,
        collapsedHeight: CGFloat,
        expandedHeight: Binding<CGFloat>,
        minExpandedHeight: CGFloat,
        maxExpandedHeight: CGFloat,
        minTopHeight: CGFloat = 0,
        animation: NSAnimationContextSpec?,
        @ViewBuilder top: @escaping () -> Top,
        @ViewBuilder bottom: @escaping () -> Bottom,
    ) {
        self.collapsed = collapsed
        self.collapsedHeight = collapsedHeight
        _expandedHeight = expandedHeight
        self.minExpandedHeight = minExpandedHeight
        self.maxExpandedHeight = maxExpandedHeight
        self.minTopHeight = minTopHeight
        self.animation = animation
        self.top = top
        self.bottom = bottom
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(expandedHeight: $expandedHeight)
    }

    public func makeNSView(context: Context) -> AnimatedSplitView {
        let topHost = NSHostingView(rootView: top())
        let bottomHost = NSHostingView(rootView: bottom())
        // Don't let the hosting views impose their SwiftUI content's intrinsic size on the layout —
        // we set every frame manually. Without this the expanded pane snaps back to its content's
        // intrinsic height after a collapse/expand cycle instead of honouring the requested height.
        topHost.sizingOptions = []
        bottomHost.sizingOptions = []
        let view = AnimatedSplitView(
            top: topHost,
            bottom: bottomHost,
            initialBottomHeight: collapsed ? collapsedHeight : expandedHeight,
            collapsed: collapsed,
            collapsedHeight: collapsedHeight,
            minExpandedHeight: minExpandedHeight,
            maxExpandedHeight: maxExpandedHeight,
            minTopHeight: minTopHeight,
            onExpandedHeightChange: context.coordinator.persistExpandedHeight,
        )
        context.coordinator.topHost = topHost
        context.coordinator.bottomHost = bottomHost
        context.coordinator.previousCollapsed = collapsed
        return view
    }

    public func updateNSView(_ nsView: AnimatedSplitView, context: Context) {
        context.coordinator.expandedHeight = $expandedHeight
        if let topHost = context.coordinator.topHost as? NSHostingView<Top> {
            topHost.rootView = top()
        }
        if let bottomHost = context.coordinator.bottomHost as? NSHostingView<Bottom> {
            bottomHost.rootView = bottom()
        }

        nsView.collapsedHeight = collapsedHeight
        nsView.minExpandedHeight = minExpandedHeight
        nsView.maxExpandedHeight = maxExpandedHeight
        nsView.minTopHeight = minTopHeight

        let collapsedChanged = context.coordinator.previousCollapsed != collapsed
        context.coordinator.previousCollapsed = collapsed

        if collapsedChanged {
            let target = collapsed ? collapsedHeight : expandedHeight
            nsView.setBottomHeight(target, collapsed: collapsed, animation: animation)
        }
    }

    @MainActor
    public final class Coordinator {
        var expandedHeight: Binding<CGFloat>
        weak var topHost: NSView?
        weak var bottomHost: NSView?
        var previousCollapsed: Bool?

        init(expandedHeight: Binding<CGFloat>) {
            self.expandedHeight = expandedHeight
        }

        func persistExpandedHeight(_ height: CGFloat) {
            expandedHeight.wrappedValue = height
        }
    }
}

@MainActor
public final class AnimatedSplitView: NSView {
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
    var minTopHeight: CGFloat
    private(set) var collapsed: Bool
    private var bottomHeight: CGFloat
    private var dragStartHeight: CGFloat?
    private var isUserSized = false
    private let onExpandedHeightChange: (CGFloat) -> Void

    init(
        top: NSView,
        bottom: NSView,
        initialBottomHeight: CGFloat,
        collapsed: Bool,
        collapsedHeight: CGFloat,
        minExpandedHeight: CGFloat,
        maxExpandedHeight: CGFloat,
        minTopHeight: CGFloat,
        onExpandedHeightChange: @escaping (CGFloat) -> Void = { _ in },
    ) {
        topHost = top
        bottomHost = bottom
        let handle = SplitDragHandleView()
        handleHost = handle
        let divider = NSHostingView(rootView: Color.brewBorderSeparator)
        divider.sizingOptions = []
        dividerHost = divider
        bottomHeight = initialBottomHeight
        self.collapsed = collapsed
        self.collapsedHeight = collapsedHeight
        self.minExpandedHeight = minExpandedHeight
        self.maxExpandedHeight = maxExpandedHeight
        self.minTopHeight = minTopHeight
        self.onExpandedHeightChange = onExpandedHeightChange
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(topHost)
        addSubview(bottomHost)
        addSubview(handleHost)
        addSubview(dividerHost)
        handle.onDragBegan = { [weak self] in self?.beginHandleDrag() }
        handle.onDragChanged = { [weak self] translationY in
            self?.updateHandleDrag(translationY: translationY)
        }
        handle.onDragEnded = { [weak self] in self?.endHandleDrag() }
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        nil
    }

    override public func layout() {
        super.layout()
        applyLayout(forBottomHeight: bottomHeight, animated: false)
    }

    func setBottomHeight(_ newHeight: CGFloat, collapsed: Bool, animation: NSAnimationContextSpec?) {
        self.collapsed = collapsed
        isUserSized = false
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
        // Recomputed per layout, so growing the window back restores the height that was asked for.
        let bottomH = fit(bottom, preservesTopMinimum: !isUserSized)
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
        clampedSplitBottomHeight(
            value,
            collapsed: collapsed,
            collapsedHeight: collapsedHeight,
            minExpanded: minExpandedHeight,
            maxExpanded: maxExpandedHeight,
        )
    }

    private func fit(_ value: CGFloat, preservesTopMinimum: Bool) -> CGFloat {
        fittedSplitBottomHeight(
            value,
            total: bounds.height,
            collapsed: collapsed,
            preservesTopMinimum: preservesTopMinimum,
            limits: SplitHeightLimits(
                collapsedHeight: collapsedHeight,
                minExpanded: minExpandedHeight,
                minTop: minTopHeight,
                chrome: (collapsed ? 0 : Self.handleThickness) + Self.dividerThickness,
            ),
        )
    }

    func beginHandleDrag() {
        guard !collapsed else {
            return
        }
        dragStartHeight = bottomHost.frame.height
        isUserSized = true
    }

    func updateHandleDrag(translationY: CGFloat) {
        guard let start = dragStartHeight else {
            return
        }
        // Non-flipped NSView: positive translation.y == cursor moved up == bottom pane grows.
        bottomHeight = clamp(start + translationY, collapsed: false)
        applyLayout(forBottomHeight: bottomHeight, animated: false)
    }

    func endHandleDrag() {
        guard dragStartHeight != nil else {
            return
        }
        dragStartHeight = nil
        onExpandedHeightChange(bottomHeight)
    }
}

private final class SplitDragHandleView: NSHostingView<SplitDragHandle> {
    var onDragBegan: () -> Void = {}
    var onDragChanged: (CGFloat) -> Void = { _ in }
    var onDragEnded: () -> Void = {}

    private var dragStartY: CGFloat?

    convenience init() {
        self.init(rootView: SplitDragHandle())
    }

    required init(rootView: SplitDragHandle) {
        super.init(rootView: rootView)
        sizingOptions = []
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let superview else {
            return nil
        }
        // AppKit supplies this point in the receiver's superview coordinate space.
        let localPoint = convert(point, from: superview)
        return bounds.contains(localPoint) ? self : nil
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartY = event.locationInWindow.y
        onDragBegan()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartY else {
            return
        }
        onDragChanged(event.locationInWindow.y - dragStartY)
    }

    override func mouseUp(with _: NSEvent) {
        guard dragStartY != nil else {
            return
        }
        dragStartY = nil
        onDragEnded()
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
    }
}

public struct NSAnimationContextSpec {
    let duration: CFTimeInterval
    let timingFunction: CAMediaTimingFunction?

    public init(duration: CFTimeInterval, timingFunction: CAMediaTimingFunction?) {
        self.duration = duration
        self.timingFunction = timingFunction
    }

    public static let brewFast = NSAnimationContextSpec(
        duration: 0.15,
        timingFunction: CAMediaTimingFunction(name: .easeOut),
    )
}

/// Resolves the bottom-pane height for a split request: collapsed snaps to the fixed collapsed
/// height; otherwise the proposed value is bounded to `[minExpanded, maxExpanded]`.
func clampedSplitBottomHeight(
    _ value: CGFloat,
    collapsed: Bool,
    collapsedHeight: CGFloat,
    minExpanded: CGFloat,
    maxExpanded: CGFloat,
) -> CGFloat {
    if collapsed {
        return collapsedHeight
    }
    return max(min(value, maxExpanded), minExpanded)
}

struct SplitHeightLimits {
    let collapsedHeight: CGFloat
    let minExpanded: CGFloat
    let minTop: CGFloat
    /// The handle and divider between them, which come out of the same budget.
    let chrome: CGFloat
}

/// The bottom pane is the accessory, so it is the one that gives way: it shrinks towards `minExpanded`
/// to keep `minTop` for the pane above, and only eats into that once it has nothing left to give.
func fittedSplitBottomHeight(
    _ value: CGFloat,
    total: CGFloat,
    collapsed: Bool,
    preservesTopMinimum: Bool = true,
    limits: SplitHeightLimits,
) -> CGFloat {
    let available = max(0, total - limits.chrome)
    guard !collapsed else {
        return min(limits.collapsedHeight, available)
    }
    let topMinimum = preservesTopMinimum ? limits.minTop : 0
    let yieldingToTop = min(value, max(0, available - topMinimum))
    return min(max(yieldingToTop, limits.minExpanded), available)
}
