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
    /// Ended with a newline; will not change again.
    case committed(TerminalLine)
    /// Still being written; may change again before it commits.
    case revised(TerminalLine)
}

/// Applies terminal overwrite semantics to a byte stream.
///
/// A terminal is not an append-only transcript: a carriage return moves the cursor back to column zero
/// and what follows overwrites what was there. `curl` redraws its progress bar hundreds of times that
/// way, with no newline between redraws, so splitting on newlines alone collapses a whole download into
/// one enormous line holding every intermediate state.
///
/// Keeping the line as cells with a cursor makes an overwrite replace earlier content. Handles `\r`,
/// `\b`, `\n`, `ESC[K`, the within-line cursor moves `ESC[G`, `ESC[C` and `ESC[D`, and SGR. Cursor
/// movement *between* lines (`ESC[A` and friends, used for multi-line progress blocks) is consumed and
/// ignored: doing it properly needs a screen buffer rather than a line. Style carries across lines, as
/// it does in a real terminal.
public struct TerminalLineAssembler: Sendable {
    private struct Cell: Equatable {
        var character: Character
        var style: ANSIStyle
    }

    private static let escape: Unicode.Scalar = "\u{1B}"

    /// Well past any real terminal width. A malformed or hostile `ESC[999999999C` would otherwise ask
    /// for a column the next write has to pad every cell up to.
    private static let maxColumn = 4096

    private var cells: [Cell] = []
    private var column = 0
    private var style = ANSIStyle.default

    public init() {}

    public var hasPendingLine: Bool {
        !cells.isEmpty
    }

    public var pendingLine: TerminalLine {
        TerminalLine(spans: Self.spans(from: cells))
    }

    /// Returns the lines this chunk completed, plus one ``TerminalLineEvent/revised(_:)`` if the
    /// in-progress line changed. One revision per chunk rather than per write: a progress bar writes far
    /// faster than a UI needs to repaint.
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
                // Other C0 controls (bell, tabs) carry no visible content.
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

    /// Commits the in-progress line when the stream ends without a trailing newline.
    public mutating func flush() -> TerminalLine? {
        guard !cells.isEmpty else {
            return nil
        }
        let line = TerminalLine(spans: Self.spans(from: cells))
        cells = []
        column = 0
        return line
    }

    /// Pads with spaces if the cursor has moved past the end of the line.
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

    /// Returns whether the sequence changed the visible line. Moving the cursor never does on its own —
    /// the write that follows is what shows.
    private mutating func apply(_ control: ANSIParser.ControlSequence) -> Bool {
        switch control.finalByte {
        case "m":
            style = ANSIParser.apply(control.parameters, to: style)
            return false
        case "K":
            return eraseInLine(mode: Self.parameter(control, default: 0))
        case "G":
            // Absolute column, 1-based. Several progress renderers use this where `curl` uses `\r`, so
            // ignoring it would let a redraw append instead of overwrite.
            move(to: Self.parameter(control, default: 1) - 1)
            return false
        case "C":
            move(to: column + max(1, Self.parameter(control, default: 1)))
            return false
        case "D":
            move(to: column - max(1, Self.parameter(control, default: 1)))
            return false
        default:
            return false
        }
    }

    private mutating func move(to target: Int) {
        column = min(Self.maxColumn, max(0, target))
    }

    /// The first CSI parameter, or the sequence's documented default when it is absent or unreadable.
    private static func parameter(_ control: ANSIParser.ControlSequence, default fallback: Int) -> Int {
        guard let first = control.parameters.split(separator: ";").first, let value = Int(first) else {
            return fallback
        }
        return value
    }

    /// Erase to end of line (0, the default), to the start (1), or all of it (2). Erasing to the start
    /// blanks cells rather than removing them, so the cursor keeps its column. Blanks take the *current*
    /// style, which is what a terminal erases with — carrying the old one over would leave a stale
    /// background behind.
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
                cells[index] = Cell(character: " ", style: style)
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
