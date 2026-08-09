//
//  BrewCommandOutputLine.swift
//  BrewCore
//

import Foundation

/// One line of subprocess output, attributed to a stream (`ARCHITECTURE.md` — command execution; transparency).
///
/// A line is not always final when it first appears. Terminal-backed runs report a line while it is still
/// being drawn — a progress bar revises the same line hundreds of times before a newline settles it — so
/// ``isComplete`` tells consumers whether to expect the line to change again. Pipe-backed runs have no
/// redraws and only ever produce complete lines.
public struct BrewCommandOutputLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let stream: Stream
    public let text: String
    public let timestamp: Date

    /// The line's visible content split into styled runs, resolved once when the line is created rather
    /// than re-parsed on every render.
    public let spans: [ANSISpan]

    /// `false` while the line is still being drawn and may be revised; `true` once it is settled.
    public let isComplete: Bool

    public enum Stream: Equatable, Sendable {
        case stdout
        case stderr
    }

    public init(
        stream: Stream,
        text: String,
        timestamp: Date = Date(),
        id: UUID = UUID(),
        isComplete: Bool = true,
    ) {
        self.id = id
        self.stream = stream
        self.text = text
        self.timestamp = timestamp
        self.isComplete = isComplete
        spans = ANSIParser.parse(text)
    }

    /// Builds a line from an assembled terminal line, whose styling and overwrites are already resolved.
    public init(
        stream: Stream,
        line: TerminalLine,
        isComplete: Bool,
        timestamp: Date = Date(),
        id: UUID = UUID(),
    ) {
        self.id = id
        self.stream = stream
        text = line.text
        self.timestamp = timestamp
        self.isComplete = isComplete
        spans = line.spans
    }

    /// A copy carrying `other`'s identity, so a revision replaces its predecessor in place rather than
    /// reading as a new row to anything keyed on ``id``.
    public func adoptingIdentity(of other: BrewCommandOutputLine) -> BrewCommandOutputLine {
        BrewCommandOutputLine(copying: self, id: other.id)
    }

    private init(copying other: BrewCommandOutputLine, id: UUID) {
        self.id = id
        stream = other.stream
        text = other.text
        timestamp = other.timestamp
        isComplete = other.isComplete
        spans = other.spans
    }
}
