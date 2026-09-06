//
//  RelativeTimeTextTests.swift
//  BrewUIComponentsTests
//

@testable import BrewUIComponents
import Foundation
import Testing

struct RelativeTimeTextTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private static func text(secondsAgo: TimeInterval) -> String {
        RelativeTimeText.string(for: now.addingTimeInterval(-secondsAgo), relativeTo: now)
    }

    @Test func `anything under a minute reads as just now`() {
        #expect(Self.text(secondsAgo: 0) == "just now")
        #expect(Self.text(secondsAgo: 59) == "just now")
    }

    @Test func `minutes, hours and days each get their own unit`() {
        #expect(Self.text(secondsAgo: 60) == "1 minute ago")
        #expect(Self.text(secondsAgo: 59 * 60) == "59 minutes ago")
        #expect(Self.text(secondsAgo: 60 * 60) == "1 hour ago")
        #expect(Self.text(secondsAgo: 23 * 3600) == "23 hours ago")
        #expect(Self.text(secondsAgo: 24 * 3600) == "1 day ago")
        #expect(Self.text(secondsAgo: 10 * 24 * 3600) == "10 days ago")
    }

    /// Each unit truncates rather than rounds, so the phrase never claims more time has passed than has.
    @Test func `a part-elapsed unit does not round up`() {
        #expect(Self.text(secondsAgo: 119) == "1 minute ago")
        #expect(Self.text(secondsAgo: 7199) == "1 hour ago")
    }

    /// A clock that has moved backwards leaves the timestamp in the future; a countdown would be nonsense.
    @Test func `a future timestamp reads as just now`() {
        #expect(RelativeTimeText.string(for: Self.now.addingTimeInterval(600), relativeTo: Self.now)
            == "just now")
    }
}
