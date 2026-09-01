//
//  ConsoleTranscript.swift
//  BrewFeatureConsole
//

import BrewCore
import Foundation

/// The console body's output as one text document, plus the smallest edit that brings an already
/// rendered copy of it up to date.
///
/// Every change `brew` makes to the buffer lands in a suffix of it, so an update is "replace from the
/// first line that differs to the end" — re-rendering the whole thing per line would be quadratic over
/// a run and would drop the user's selection. Offsets are UTF-16, as `NSTextStorage` indexes.
struct ConsoleTranscript: Equatable {
    private(set) var lines: [BrewCommandOutputLine] = []

    /// Cached so an update doesn't re-measure the buffer.
    private var lengths: [Int] = []

    struct Edit: Equatable {
        let location: Int
        let length: Int
        let lines: [BrewCommandOutputLine]
    }

    /// The renderer must agree with this character-for-character, or the offsets address the wrong text.
    static func text(of line: BrewCommandOutputLine) -> String {
        line.spans.map(\.text).joined() + "\n"
    }

    var text: String {
        lines.map(Self.text(of:)).joined()
    }

    var length: Int {
        lengths.reduce(0, +)
    }

    /// The edit a rendered document needs to catch up, or `nil` when nothing changed.
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

    /// Identity is deliberately not compared: a redrawn progress row keeps its id and changes its text.
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
