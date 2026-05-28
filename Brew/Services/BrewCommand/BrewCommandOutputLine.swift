//
//  BrewCommandOutputLine.swift
//  Brew
//

import Foundation

/// One line of subprocess output, attributed to a stream (`ARCHITECTURE.md` — command execution; transparency).
nonisolated struct BrewCommandOutputLine: Identifiable, Equatable {
    let id: UUID
    let stream: Stream
    let text: String
    let timestamp: Date

    enum Stream: Equatable {
        case stdout
        case stderr
    }

    init(stream: Stream, text: String, timestamp: Date = Date(), id: UUID = UUID()) {
        self.id = id
        self.stream = stream
        self.text = text
        self.timestamp = timestamp
    }
}
