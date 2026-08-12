//
//  BrewCommandOutputLine.swift
//  BrewCore
//

import Foundation

/// One line of subprocess output, attributed to a stream (`ARCHITECTURE.md` — command execution).
///
/// Terminal-backed runs report a line while it is still being drawn, since a progress bar revises the
/// same line many times before a newline settles it. Pipe-backed runs only ever produce complete lines.
public struct BrewCommandOutputLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let stream: Stream
    public let text: String
    public let timestamp: Date

    /// Resolved once here rather than re-parsed on every render.
    public let spans: [ANSISpan]

    /// `false` while the line may still be revised.
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

    /// Styling and overwrites are already resolved by the assembler.
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

    /// So a revision replaces its predecessor in place for anything keyed on ``id``.
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
