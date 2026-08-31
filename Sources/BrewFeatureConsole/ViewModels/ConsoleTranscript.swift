//
//  ConsoleTranscript.swift
//  BrewFeatureConsole
//

import BrewCore
import Foundation

/// The console body's output as one text document, plus the smallest edit that brings an already
/// rendered copy of it up to date.
///
/// The body renders the buffer as a single text view rather than a row per line, which makes "what
/// changed since the last render" the view's problem. Every change `brew` makes to the buffer —
/// appending a line, redrawing a progress row in place — lands in a suffix of it, so an update is
/// expressed as "replace from the first line that differs to the end". Re-rendering the whole buffer
/// instead would be quadratic over a run and would drop whatever the user had selected each time a
/// line arrived.
///
/// Offsets are UTF-16, which is what `NSTextStorage` indexes in.
struct ConsoleTranscript: Equatable {
    private(set) var lines: [BrewCommandOutputLine] = []

    /// Rendered length of each entry in ``lines``, cached so an update doesn't re-measure the buffer.
    private var lengths: [Int] = []

    /// A replacement of one UTF-16 range of the rendered document with freshly rendered lines.
    struct Edit: Equatable {
        let location: Int
        let length: Int
        let lines: [BrewCommandOutputLine]
    }

    /// The visible text of one line — ANSI escapes resolved away, newline-terminated.
    ///
    /// Every line carries its terminator, including the last, so offsets stay uniform and the caret can
    /// rest on the row below the output the way it does in a terminal. The renderer must agree with this
    /// character-for-character or the offsets below address the wrong text.
    static func text(of line: BrewCommandOutputLine) -> String {
        line.spans.map(\.text).joined() + "\n"
    }

    var text: String {
        lines.map(Self.text(of:)).joined()
    }

    /// UTF-16 length of ``text``.
    var length: Int {
        lengths.reduce(0, +)
    }

    /// Moves to `newLines`, returning the edit a rendered document needs to catch up, or `nil` when
    /// nothing changed.
    mutating func update(to newLines: [BrewCommandOutputLine]) -> Edit? {
        let common = commonPrefixCount(with: newLines)
        guard common < lines.count || common < newLines.count else {
            return nil
        }
        let location = lengths.prefix(common).reduce(0, +)
        let replacedLength = lengths.dropFirst(common).reduce(0, +)
        let replacement = Array(newLines[common...])
        lines = newLines
        lengths = Array(lengths.prefix(common)) + replacement.map { Self.text(of: $0).utf16.count }
        return Edit(location: location, length: replacedLength, lines: replacement)
    }

    /// Two lines render identically when their stream and raw text match — spans, colour and length all
    /// derive from those. Identity is deliberately not compared: a redrawn progress row keeps its id and
    /// changes only its text, and a line whose id changed but whose text didn't needs no repaint.
    private func commonPrefixCount(with newLines: [BrewCommandOutputLine]) -> Int {
        var index = 0
        while index < lines.count, index < newLines.count,
              lines[index].stream == newLines[index].stream,
              lines[index].text == newLines[index].text
        {
            index += 1
        }
        return index
    }
}
