//
//  ConsoleTextView.swift
//  BrewFeatureConsole
//

import AppKit
import BrewAccessibilityID
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// The console output as one selectable text document, so selection, ⌘A and ⌘C behave the way they do
/// in Terminal. New output is applied as ``ConsoleTranscript``'s minimal edit, which is what lets a
/// selection made mid-run survive it.
struct ConsoleTextView: NSViewRepresentable {
    let lines: [BrewCommandOutputLine]

    /// Switching tabs is a new document rather than an edit of this one.
    let jobID: CommandJobID

    let standardErrorIsNormalOutput: Bool

    /// Stored rather than read off `context.environment`, so a flip is guaranteed to re-invoke the update.
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context _: Context) -> NSScrollView {
        // TextKit 1 explicitly: non-contiguous layout keeps a long transcript cheap.
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = ConsoleOutputTextView(frame: .zero, textContainer: container)
        textView.isEditable = false
        textView.isSelectable = true
        // Plain text on the pasteboard, not RTF.
        textView.isRichText = false
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [NSView.AutoresizingMask.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude,
        )
        textView.textContainerInset = NSSize(width: BrewSpacing.lg, height: BrewSpacing.sm)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.setAccessibilityIdentifier(AXID.consoleOutput.rawValue)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ConsoleOutputTextView,
              let storage = textView.textStorage
        else {
            return
        }
        let coordinator = context.coordinator
        // A different job, or a restyle of every line, is a re-render rather than an edit.
        if coordinator.jobID != jobID || coordinator.colorScheme != colorScheme {
            coordinator.jobID = jobID
            coordinator.colorScheme = colorScheme
            coordinator.transcript = ConsoleTranscript()
            storage.setAttributedString(NSAttributedString())
        }

        guard let edit = coordinator.transcript.update(to: lines) else {
            return
        }
        let selection = textView.selectedRanges.map(\.rangeValue)
        storage.replaceCharacters(
            in: NSRange(location: edit.location, length: edit.length),
            with: ANSIConsoleText.attributed(
                for: edit.lines,
                standardErrorIsNormalOutput: standardErrorIsNormalOutput,
            ),
        )
        textView.selectedRanges = ConsoleTextSelection
            .clamped(selection, toLength: storage.length)
            .map { NSValue(range: $0) }

        textView.pinToBottomIfFollowing()
    }

    final class Coordinator {
        var transcript = ConsoleTranscript()
        var jobID: CommandJobID?
        var colorScheme: ColorScheme?
    }
}

/// Follows the end of the document while the user is parked at the bottom of it, giving that up when
/// they scroll away so reading back through a long install isn't interrupted.
final class ConsoleOutputTextView: NSTextView {
    /// How close to the end counts as "at the bottom".
    private static let bottomSlack: CGFloat = 4

    private var followsOutput = true

    private var isScrolledToBottom: Bool {
        guard let clipView = enclosingScrollView?.contentView else {
            return true
        }
        return clipView.documentVisibleRect.maxY >= frame.height - Self.bottomSlack
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let clipView = enclosingScrollView?.contentView else {
            return
        }
        clipView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipViewDidScroll),
            name: NSView.boundsDidChangeNotification,
            object: clipView,
        )
    }

    /// Pinning on layout too: SwiftUI hands over the first batch of output before the scroll view has
    /// any size, and a scroll issued then goes nowhere.
    override func layout() {
        super.layout()
        pinToBottomIfFollowing()
    }

    /// Growing the document doesn't move the clip view, so this only ever fires for a real scroll.
    @objc private func clipViewDidScroll() {
        followsOutput = isScrolledToBottom
    }

    func pinToBottomIfFollowing() {
        guard followsOutput, let scrollView = enclosingScrollView else {
            return
        }
        let clipView = scrollView.contentView
        let target = max(0, frame.height - clipView.bounds.height)
        // Guarded so a pin that changes nothing doesn't churn the scroll view on every layout pass.
        guard abs(clipView.bounds.origin.y - target) > 0.5 else {
            return
        }
        clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: target))
        scrollView.reflectScrolledClipView(clipView)
    }
}

/// Re-applying the selection after a streaming edit, which can leave ranges past the end of the document.
enum ConsoleTextSelection {
    /// Clamped rather than dropped, so a selection above the edit survives. `NSTextView` rejects an empty
    /// set of ranges, so the result always holds at least one.
    static func clamped(_ ranges: [NSRange], toLength length: Int) -> [NSRange] {
        let clamped = ranges.map { range -> NSRange in
            let location = min(range.location, length)
            return NSRange(location: location, length: min(range.length, length - location))
        }
        let selected = clamped.filter { $0.length > 0 }
        return selected.isEmpty ? [clamped.first ?? NSRange(location: 0, length: 0)] : selected
    }
}
