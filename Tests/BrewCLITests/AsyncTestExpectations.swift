//
//  AsyncTestExpectations.swift
//  BrewTests
//

import Foundation
import Testing

func waitUntil(
    _ comment: Comment? = nil,
    timeout: Duration = .seconds(5),
    poll: Duration = .milliseconds(10),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: @Sendable () async -> Bool,
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() {
            return
        }
        try await Task.sleep(for: poll)
    }
    guard await condition() else {
        Issue.record(comment ?? "Timed out after \(timeout)", sourceLocation: sourceLocation)
        return
    }
}

actor TestGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters = []
        for continuation in pending {
            continuation.resume()
        }
    }
}
