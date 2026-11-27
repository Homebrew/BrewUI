import AppKit
import SwiftUI

public extension View {
    /// 分组标题与短分隔线使用正文边距，保留原生吸顶。
    func brewPlainListSectionHeader() -> some View {
        padding(.horizontal, BrewLayout.paneContentInset - BrewSpacing.lg)
            .background(PlainPinnedHeaderStyle())
    }
}

private struct PlainPinnedHeaderStyle: NSViewRepresentable {
    func makeNSView(context _: Context) -> PinnedHeaderAppearanceView {
        PinnedHeaderAppearanceView()
    }

    func updateNSView(_ view: PinnedHeaderAppearanceView, context _: Context) {
        view.refreshAppearance()
    }

    static func dismantleNSView(_ view: PinnedHeaderAppearanceView, coordinator _: ()) {
        view.restoreRow()
    }
}

/// 以原生行的实际位置判断吸顶，避免把已改写的绘制标记当成状态源。
/// 仅调整分组绘制；列表继续拥有吸顶、滚动和选择。
private final class PinnedHeaderAppearanceView: NSView {
    private let pinnedBackdrop = SectionBackdrop(frame: .zero)
    private let leadingEnd = SectionBackdrop(frame: .zero)
    private let trailingEnd = SectionBackdrop(frame: .zero)
    private weak var row: NSTableRowView?
    private weak var table: NSTableView?
    private weak var clip: NSClipView?
    private var floatingObservation: NSKeyValueObservation?
    private var isApplying = false
    private var isUpdateScheduled = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            restoreRow()
        } else {
            refreshAppearance()
        }
    }

    override func layout() {
        super.layout()
        attachToRow()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    func refreshAppearance() {
        attachToRow()
        scheduleUpdate()
    }

    func attachToRow() {
        guard window != nil else { return }
        var ancestor = superview
        while let current = ancestor {
            if let candidate = current as? NSTableRowView,
               candidate.isGroupRowStyle,
               let candidateTable = owningTable(for: candidate),
               let scroll = candidateTable.enclosingScrollView,
               scroll.contentView.postsBoundsChangedNotifications
            {
                if candidate !== row || candidateTable !== table {
                    restoreRow()
                    row = candidate
                    table = candidateTable
                    clip = scroll.contentView
                    floatingObservation = candidate.observe(\.isFloating, options: [.new]) { [weak self] _, change in
                        guard change.newValue == true else { return }
                        // AppKit 在主线程同步修改行状态，KVO 沿用同一线程。
                        // swiftlint:disable:next assume_isolated
                        MainActor.assumeIsolated { self?.applyAppearance() }
                    }
                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(clipBoundsDidChange(_:)),
                        name: NSView.boundsDidChangeNotification,
                        object: scroll.contentView,
                    )
                }
                applyAppearance()
                return
            }
            ancestor = current.superview
        }
        restoreRow()
    }

    private func owningTable(for candidate: NSTableRowView) -> NSTableView? {
        if let table, owns(candidate, in: table) { return table }
        // 吸顶行由 AppKit 移至列表旁的浮动容器，不能依赖父视图就是表格。
        // 按公开的行身份验证归属，不匹配 SwiftUI 私有视图名称。
        var ancestor = candidate.superview
        while let current = ancestor {
            if let owner = findTable(in: current, owning: candidate) { return owner }
            ancestor = current.superview
        }
        return nil
    }

    private func findTable(in view: NSView, owning candidate: NSTableRowView) -> NSTableView? {
        if let table = view as? NSTableView, owns(candidate, in: table) { return table }
        for child in view.subviews {
            if let owner = findTable(in: child, owning: candidate) { return owner }
        }
        return nil
    }

    private func owns(_ candidate: NSTableRowView, in table: NSTableView) -> Bool {
        let index = table.row(for: candidate)
        return index >= 0 && index < table.numberOfRows
            && table.rowView(atRow: index, makeIfNecessary: false) === candidate
    }

    @objc private func clipBoundsDidChange(_: Notification) {
        attachToRow()
        // 滚动通知发生后，等原生列表完成分组行换位再复核一次。
        scheduleUpdate()
    }

    private func scheduleUpdate() {
        guard !isUpdateScheduled else { return }
        isUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isUpdateScheduled = false
            attachToRow()
        }
    }

    private var isPinned: Bool? {
        guard let row, let table, let clip else { return nil }
        let index = table.row(for: row)
        guard index >= 0, index < table.numberOfRows else { return nil }
        let naturalY = table.rect(ofRow: index).minY
        let actualY = row.convert(row.bounds, to: table).minY
        let visibleTop = table.convert(clip.bounds, from: clip).minY
        let pixel = 1 / (window?.backingScaleFactor ?? 1)
        return table.floatsGroupRows
            && (abs(actualY - naturalY) > pixel || abs(actualY - visibleTop) <= pixel)
    }

    private func applyAppearance() {
        guard let row, !isApplying else { return }
        isApplying = true
        defer { isApplying = false }
        updateSeparatorEnds(in: row)
        guard isPinned == true else {
            pinnedBackdrop.removeFromSuperview()
            return
        }
        // 浮动绘制包含遮挡背景。去掉它时，保留不透明背景防止内容透字。
        pinnedBackdrop.place(in: row, frame: row.bounds, autoresizing: [.width, .height], position: .below)
        if row.isFloating { row.isFloating = false }
    }

    private func updateSeparatorEnds(in row: NSTableRowView) {
        // 原生分组线不读取行分隔线的对齐指南。只遮去超出正文边距的线端。
        let inset = BrewLayout.paneContentInset
        let thickness: CGFloat = 1
        let y = row.isFlipped ? row.bounds.maxY - thickness : row.bounds.minY
        let verticalMargin: NSView.AutoresizingMask = row.isFlipped ? .minYMargin : .maxYMargin
        leadingEnd.place(
            in: row, frame: NSRect(x: row.bounds.minX, y: y, width: inset, height: thickness),
            autoresizing: verticalMargin, position: .above,
        )
        trailingEnd.place(
            in: row, frame: NSRect(x: row.bounds.maxX - inset, y: y, width: inset, height: thickness),
            autoresizing: [verticalMargin, .minXMargin], position: .above,
        )
    }

    func restoreRow() {
        pinnedBackdrop.removeFromSuperview()
        leadingEnd.removeFromSuperview()
        trailingEnd.removeFromSuperview()
        floatingObservation?.invalidate()
        floatingObservation = nil
        if let clip {
            NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: clip)
        }
        if let row, let isPinned { row.isFloating = isPinned }
        row = nil
        table = nil
        clip = nil
    }
}

/// NSBox 的窗口背景支持系统桌面染色；直接填充 CGColor 会丢失染色。
private final class SectionBackdrop: NSBox {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        boxType = .custom
        titlePosition = .noTitle
        borderWidth = 0
        fillColor = .windowBackgroundColor
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func place(in row: NSTableRowView, frame: NSRect, autoresizing: NSView.AutoresizingMask, position: NSWindow.OrderingMode) {
        self.frame = frame
        autoresizingMask = autoresizing
        if superview !== row {
            row.addSubview(self, positioned: position, relativeTo: nil)
        }
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}
