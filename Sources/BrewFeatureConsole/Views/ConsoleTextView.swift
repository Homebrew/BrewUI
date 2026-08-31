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

/// The console output as one selectable text document.
///
/// A row per line gave every line its own selection scope: dragging across lines selected nothing, ⌘A
/// had no document to select, the gaps between rows weren't text at all, and the pointer alternated
/// between an arrow and an I-beam depending on which of those it was over. An `NSTextView` is a single
/// document, so selection, ⌘A and ⌘C behave the way they do in Terminal and the I-beam covers the whole
/// output area.
///
/// New output is applied as the minimal edit (see ``ConsoleTranscript``) so a selection made while a
/// command is running survives it, and the view only re-pins to the bottom when it was already there —
/// scrolling up to read during a long install isn't fought.
struct ConsoleTextView: NSViewRepresentable {
    let lines: [BrewCommandOutputLine]

    /// Which job is on screen. Switching tabs is a new document rather than an edit of this one.
    let jobID: CommandJobID

    /// Read as a stored dependency, not off `context.environment`, so a light/dark flip is guaranteed to
    /// re-invoke ``updateNSView(_:context:)`` and repaint the transcript in the new appearance.
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
        // Copying a console selection should put plain text on the pasteboard, not RTF.
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
        if coordinator.jobID != jobID || coordinator.colorScheme != colorScheme {
            // A different job is a different document, and a light/dark flip restyles every line: both
            // are a re-render of everything, so the transcript starts over with the empty storage.
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
            with: ANSIConsoleText.attributed(for: edit.lines),
        )
        textView.selectedRanges = ConsoleTextSelection
            .clamped(selection, toLength: storage.length)
            .map { NSValue(range: $0) }

        textView.pinToBottomIfFollowing()
    }

    /// Holds what the text view currently shows, so the next update can be expressed as a diff against it.
    final class Coordinator {
        var transcript = ConsoleTranscript()
        var jobID: CommandJobID?
        var colorScheme: ColorScheme?
    }
}

/// Text view that follows the end of the document while the user is parked at the bottom of it.
///
/// Following is given up when the user scrolls away and taken back when they scroll to the end again —
/// reading back through a long install isn't interrupted by the next line arriving. The pin runs on
/// layout as well as after each edit because SwiftUI hands over the first batch of output before the
/// scroll view has any size at all, and a scroll issued then goes nowhere.
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

    override func layout() {
        super.layout()
        pinToBottomIfFollowing()
    }

    /// Growing the document doesn't move the clip view, so this only ever fires for a scroll — which is
    /// exactly the gesture that decides whether the user still wants to be at the end.
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

/// Re-applying the selection after a streaming edit, because replacing characters underneath the text
/// view can leave ranges pointing past the end of the document.
enum ConsoleTextSelection {
    /// Ranges are clamped rather than dropped, so a selection made above the edit survives it intact.
    /// `NSTextView` rejects an empty set of ranges — with nothing left selected it wants a caret — so the
    /// result always holds at least one range.
    static func clamped(_ ranges: [NSRange], toLength length: Int) -> [NSRange] {
        let clamped = ranges.map { range -> NSRange in
            let location = min(range.location, length)
            return NSRange(location: location, length: min(range.length, length - location))
        }
        let selected = clamped.filter { $0.length > 0 }
        return selected.isEmpty ? [clamped.first ?? NSRange(location: 0, length: 0)] : selected
    }
}
