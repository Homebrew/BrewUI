//
//  TerminalLineAssembler.swift
//  BrewCore
//

import Foundation

/// A line of terminal output after every overwrite has been applied.
public struct TerminalLine: Equatable, Sendable {
    public let spans: [ANSISpan]

    public init(spans: [ANSISpan]) {
        self.spans = spans
    }

    /// Visible content with styling dropped, for export and parsing.
    public var text: String {
        spans.map(\.text).joined()
    }
}

public enum TerminalLineEvent: Equatable, Sendable {
    case committed(TerminalLine)
    /// `rowOffset` counts back from the most recently reported row: 0 is the row still being written.
    case revised(TerminalLine, rowOffset: Int)
}

/// Applies terminal overwrite semantics to a byte stream: `\r`, `\b`, `\n`, `ESC[K`, the column moves
/// `ESC[G/C/D`, the row moves `ESC[F/A/B`, and SGR. ``windowDepth`` committed rows stay addressable so
/// Homebrew's download block — N rows, last one newline-less, rewound with `ESC[<n>F` — revises in place.
/// Sequences needing a real screen buffer (`ESC[H`, `ESC[J`, scroll regions, alt screen) are ignored.
public struct TerminalLineAssembler: Sendable {
    private struct Cell: Equatable {
        var character: Character
        var style: ANSIStyle
    }

    /// `serial` survives the row moving through the window, so revisions coalesce per row.
    private struct Row {
        var cells: [Cell] = []
        let serial: Int
        var wasReported = false
    }

    private static let escape: Unicode.Scalar = "\u{1B}"

    /// Well past any real width; caps what a malformed `ESC[999999999C` makes the next write pad.
    private static let maxColumn = 4096

    /// Mirrors `PseudoTerminal.defaultRows`, which lives in `BrewCLI` and cannot be referenced here.
    public static let defaultWindowDepth = 40

    private let windowDepth: Int
    /// Committed rows still open to revision, oldest first.
    private var window: [Row] = []
    private var pending: Row
    private var column = 0
    /// 0 targets ``pending``; n targets the nth row back in ``window``.
    private var rowCursor = 0
    private var style = ANSIStyle.default
    private var nextSerial = 1
    /// Serials touched since the last report, so one chunk yields at most one revision per row.
    private var dirty: Set<Int> = []

    public init(windowDepth: Int = TerminalLineAssembler.defaultWindowDepth) {
        self.windowDepth = max(0, windowDepth)
        pending = Row(serial: 0)
    }

    public var hasPendingLine: Bool {
        !pending.cells.isEmpty
    }

    public var pendingLine: TerminalLine {
        TerminalLine(spans: Self.spans(from: pending.cells))
    }

    /// One revision per row per chunk rather than per write: a progress bar writes far faster than a UI
    /// needs to repaint.
    public mutating func consume(_ input: String) -> [TerminalLineEvent] {
        guard !input.isEmpty else {
            return []
        }

        var events: [TerminalLineEvent] = []
        let scalars = Array(input.unicodeScalars)
        var index = 0

        while index < scalars.count {
            let scalar = scalars[index]

            switch scalar {
            case "\n":
                if rowCursor > 0 {
                    // Mid-block: steps down onto the next row rather than opening one.
                    rowCursor -= 1
                    column = 0
                } else {
                    events.append(.committed(TerminalLine(spans: Self.spans(from: pending.cells))))
                    dirty.remove(pending.serial)
                    commitPending()
                }
                index += 1
            case "\r":
                column = 0
                index += 1
            case "\u{08}":
                column = max(0, column - 1)
                index += 1
            case Self.escape:
                let (next, control) = ANSIParser.scanEscape(scalars, from: index)
                if let control {
                    apply(control)
                }
                index = next
            default:
                // Other C0 controls (bell, tabs) carry no visible content.
                if scalar.value < 0x20 {
                    index += 1
                    continue
                }
                write(Character(scalar))
                index += 1
            }
        }

        events += revisionEvents()
        return events
    }

    /// Settles the row still being drawn; rows in the window were already reported.
    public mutating func flush() -> TerminalLine? {
        defer {
            window = []
            rowCursor = 0
            column = 0
            dirty = []
        }
        guard !pending.cells.isEmpty else {
            return nil
        }
        let line = TerminalLine(spans: Self.spans(from: pending.cells))
        pending = Row(serial: nextSerial)
        nextSerial += 1
        return line
    }

    // MARK: - Rows

    private mutating func commitPending() {
        var committed = pending
        committed.wasReported = true
        window.append(committed)
        if window.count > windowDepth {
            window.removeFirst(window.count - windowDepth)
        }
        pending = Row(serial: nextSerial)
        nextSerial += 1
        column = 0
    }

    private mutating func withTargetRow<T>(_ body: (inout Row) -> T) -> T {
        let index = window.count - rowCursor
        guard rowCursor > 0, window.indices.contains(index) else {
            return body(&pending)
        }
        return body(&window[index])
    }

    /// The order `rowOffset` counts in. ``pending`` joins only once reported, or about to be.
    private func reportedRowsNewestFirst() -> [Row] {
        var rows: [Row] = []
        if pending.wasReported || dirty.contains(pending.serial) {
            rows.append(pending)
        }
        rows.append(contentsOf: window.reversed())
        return rows
    }

    /// Furthest back first, so the update reads top-down.
    private mutating func revisionEvents() -> [TerminalLineEvent] {
        guard !dirty.isEmpty else {
            return []
        }

        var events: [TerminalLineEvent] = []
        for (offset, row) in reportedRowsNewestFirst().enumerated().reversed() where dirty.contains(row.serial) {
            events.append(.revised(TerminalLine(spans: Self.spans(from: row.cells)), rowOffset: offset))
        }
        if dirty.contains(pending.serial) {
            pending.wasReported = true
        }
        dirty.removeAll(keepingCapacity: true)
        return events
    }

    // MARK: - Writing

    /// Pads with spaces if the cursor has moved past the end of the row.
    private mutating func write(_ character: Character) {
        let column = column
        let style = style
        let serial = withTargetRow { row -> Int in
            if column > row.cells.count {
                let padding = repeatElement(Cell(character: " ", style: style), count: column - row.cells.count)
                row.cells.append(contentsOf: padding)
            }
            let cell = Cell(character: character, style: style)
            if column < row.cells.count {
                row.cells[column] = cell
            } else {
                row.cells.append(cell)
            }
            return row.serial
        }
        dirty.insert(serial)
        self.column += 1
    }

    private mutating func apply(_ control: ANSIParser.ControlSequence) {
        switch control.finalByte {
        case "m":
            style = ANSIParser.apply(control.parameters, to: style)
        case "K":
            eraseInLine(mode: Self.parameter(control, default: 0))
        case "G":
            // Absolute column, 1-based. Some progress renderers use this where `curl` uses `\r`.
            move(to: Self.parameter(control, default: 1) - 1)
        case "C":
            move(to: column + max(1, Self.parameter(control, default: 1)))
        case "D":
            move(to: column - max(1, Self.parameter(control, default: 1)))
        case "F":
            // CPL: up n rows to column zero — how Homebrew's download block rewinds.
            moveRowCursor(by: max(1, Self.parameter(control, default: 1)))
            column = 0
        case "A":
            // CUU: up n rows, keeping the column.
            moveRowCursor(by: max(1, Self.parameter(control, default: 1)))
        case "B":
            moveRowCursor(by: -max(1, Self.parameter(control, default: 1)))
        default:
            break
        }
    }

    private mutating func move(to target: Int) {
        column = min(Self.maxColumn, max(0, target))
    }

    private mutating func moveRowCursor(by rows: Int) {
        let target = rowCursor + rows
        guard target > 0 else {
            rowCursor = 0
            return
        }
        // Nothing above the window to revise; ignoring degrades to appending rather than a wrong row.
        guard target <= window.count else {
            return
        }
        rowCursor = target
    }

    private static func parameter(_ control: ANSIParser.ControlSequence, default fallback: Int) -> Int {
        guard let first = control.parameters.split(separator: ";").first, let value = Int(first) else {
            return fallback
        }
        return value
    }

    /// Erase to end of line (0, the default), to the start (1), or all of it (2). Erasing to the start
    /// blanks cells rather than removing them, so the cursor keeps its column, and blanks take the
    /// current style, which is what a terminal erases with.
    private mutating func eraseInLine(mode: Int) {
        let column = column
        let style = style
        let touched = withTargetRow { row -> Int? in
            switch mode {
            case 0:
                guard column < row.cells.count else {
                    return nil
                }
                row.cells.removeSubrange(column...)
                return row.serial
            case 1:
                let end = min(column + 1, row.cells.count)
                guard end > 0 else {
                    return nil
                }
                for index in 0 ..< end {
                    row.cells[index] = Cell(character: " ", style: style)
                }
                return row.serial
            case 2:
                guard !row.cells.isEmpty else {
                    return nil
                }
                row.cells = []
                return row.serial
            default:
                return nil
            }
        }
        if let touched {
            dirty.insert(touched)
        }
    }

    /// Merges adjacent cells sharing a style.
    private static func spans(from cells: [Cell]) -> [ANSISpan] {
        var spans: [ANSISpan] = []
        var text = ""
        var currentStyle: ANSIStyle?

        for cell in cells {
            if let currentStyle, currentStyle != cell.style {
                spans.append(ANSISpan(text: text, style: currentStyle))
                text = ""
            }
            currentStyle = cell.style
            text.append(cell.character)
        }

        if let currentStyle, !text.isEmpty {
            spans.append(ANSISpan(text: text, style: currentStyle))
        }
        return spans
    }
}
