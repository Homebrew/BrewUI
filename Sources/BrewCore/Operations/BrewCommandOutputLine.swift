//
//  BrewCommandOutputLine.swift
//  BrewCore
//

import Foundation

/// One line of subprocess output, attributed to a stream (`ARCHITECTURE.md` — command execution; transparency).
public struct BrewCommandOutputLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let stream: Stream
    public let text: String
    public let timestamp: Date

    public enum Stream: Equatable, Sendable {
        case stdout
        case stderr
    }

    public init(stream: Stream, text: String, timestamp: Date = Date(), id: UUID = UUID()) {
        self.id = id
        self.stream = stream
        self.text = text
        self.timestamp = timestamp
    }
}
