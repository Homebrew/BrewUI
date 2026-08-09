//
//  TerminalLineAssembler.swift
//  BrewCore
//

import Foundation

/// One line of terminal output as it currently stands, after every overwrite has been applied.
public struct TerminalLine: Equatable, Sendable {
    /// The visible content, split into runs that share a style.
    public let spans: [ANSISpan]

    public init(spans: [ANSISpan]) {
        self.spans = spans
    }

    /// The visible content with styling dropped — for export, parsing, and comparison.
    public var text: String {
        spans.map(\.text).joined()
    }
}

/// What consuming a chunk of terminal output produced.
public enum TerminalLineEvent: Equatable, Sendable {
    /// A line ended with a newline and will not change again.
    case committed(TerminalLine)
    /// The line currently being written changed. It may change again, or be committed later.
    case revised(TerminalLine)
}

/// Applies terminal overwrite semantics to a byte stream, turning it into lines that settle.
///
/// A terminal is not an append-only transcript: a carriage return moves the cursor back to the start of
/// the line and what follows overwrites what was there. Programs that draw progress use this constantly —
/// `curl` redraws its bar hundreds of times, every redraw separated by `\r` with no newline between them.
/// Split that stream on newlines alone and a whole download collapses into one enormous "line" holding
/// every intermediate state; render it verbatim and every redraw shows up as its own row.
///
/// This type keeps the line as a grid of cells with a cursor, exactly as a terminal does, so an overwrite
/// replaces earlier content instead of accumulating after it. It models what `brew` and the tools it
/// shells out to actually emit:
///   - `\r` returns the cursor to column zero
///   - `\b` steps it back one column
///   - `\n` commits the line and starts a new one
///   - `ESC[K` erases from the cursor to the end of the line (`0`), to the start (`1`), or all of it (`2`)
///   - SGR sequences set the style applied to cells written from then on
///
/// Cursor *movement* between lines (`ESC[A` and friends, used for multi-line progress displays) is not
/// modelled: those sequences are consumed and ignored, which leaves the affected lines as separate rows
/// rather than a redrawn block. Nothing Homebrew emits needs it today, and doing it properly means a
/// screen buffer rather than a line — a different data model, and a much bigger change.
///
/// Style deliberately carries across lines, matching a real terminal: a colour opened on one line stays
/// in effect until something resets it.
public struct TerminalLineAssembler: Sendable {
    /// A single character cell, carrying the style in effect when it was written.
    private struct Cell: Equatable {
        var character: Character
        var style: ANSIStyle
    }

    private static let escape: Unicode.Scalar = "\u{1B}"

    private var cells: [Cell] = []
    private var column = 0
    private var style = ANSIStyle.default

    public init() {}

    /// Whether anything has been written to the current, uncommitted line.
    public var hasPendingLine: Bool {
        !cells.isEmpty
    }

    /// The current, uncommitted line.
    public var pendingLine: TerminalLine {
        TerminalLine(spans: Self.spans(from: cells))
    }

    /// Consumes a chunk of output, returning the lines it completed and — if the in-progress line changed
    /// — a final ``TerminalLineEvent/revised(_:)`` carrying its current state.
    ///
    /// Coalescing the revision to one event per chunk is deliberate: a progress bar writes far faster than
    /// a UI needs to repaint, and one chunk is exactly one write as it reached us.
    public mutating func consume(_ input: String) -> [TerminalLineEvent] {
        guard !input.isEmpty else {
            return []
        }

        var events: [TerminalLineEvent] = []
        var pendingChanged = false
        let scalars = Array(input.unicodeScalars)
        var index = 0

        while index < scalars.count {
            let scalar = scalars[index]

            switch scalar {
            case "\n":
                events.append(.committed(TerminalLine(spans: Self.spans(from: cells))))
                cells = []
                column = 0
                pendingChanged = false
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
                    pendingChanged = apply(control) || pendingChanged
                }
                index = next
            default:
                // Other C0 controls (bell, tabs we do not expand) carry no visible content.
                if scalar.value < 0x20 {
                    index += 1
                    continue
                }
                write(Character(scalar))
                pendingChanged = true
                index += 1
            }
        }

        if pendingChanged {
            events.append(.revised(TerminalLine(spans: Self.spans(from: cells))))
        }
        return events
    }

    /// Commits whatever is left in the in-progress line, for use when the stream ends without a trailing
    /// newline. Returns nil when there is nothing pending.
    public mutating func flush() -> TerminalLine? {
        guard !cells.isEmpty else {
            return nil
        }
        let line = TerminalLine(spans: Self.spans(from: cells))
        cells = []
        column = 0
        return line
    }

    /// Writes one character at the cursor, padding with spaces if the cursor has been moved past the end
    /// of what is currently there.
    private mutating func write(_ character: Character) {
        if column > cells.count {
            cells.append(contentsOf: repeatElement(Cell(character: " ", style: style), count: column - cells.count))
        }
        let cell = Cell(character: character, style: style)
        if column < cells.count {
            cells[column] = cell
        } else {
            cells.append(cell)
        }
        column += 1
    }

    /// Applies a control sequence, returning whether it changed the visible line.
    private mutating func apply(_ control: ANSIParser.ControlSequence) -> Bool {
        switch control.finalByte {
        case "m":
            style = ANSIParser.apply(control.parameters, to: style)
            return false
        case "K":
            return eraseInLine(mode: Int(control.parameters) ?? 0)
        default:
            return false
        }
    }

    /// `ESC[K` — erase to the end of the line (0, the default), to the start (1), or the whole line (2).
    /// Erasing to the start blanks the cells rather than removing them, so the cursor keeps its column.
    private mutating func eraseInLine(mode: Int) -> Bool {
        switch mode {
        case 0:
            guard column < cells.count else {
                return false
            }
            cells.removeSubrange(column...)
            return true
        case 1:
            let end = min(column + 1, cells.count)
            guard end > 0 else {
                return false
            }
            for index in 0 ..< end {
                cells[index].character = " "
            }
            return true
        case 2:
            guard !cells.isEmpty else {
                return false
            }
            cells = []
            return true
        default:
            return false
        }
    }

    /// Merges adjacent cells that share a style into spans.
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
