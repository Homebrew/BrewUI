//
//  RelativeTimeTextTests.swift
//  BrewUIComponentsTests
//

@testable import BrewUIComponents
import Foundation
import Testing

/// Asserts unit selection — which catalogue key the elapsed time maps to — not the wording. The key
/// for a counted unit is its format string (`%lld minutes ago`), so the count itself is not visible
/// here; the resolved phrases for representative counts are asserted in
/// `BrewTests/LocalizationResolutionTests.swift`, where the catalogue is compiled.
struct RelativeTimeTextTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private static func key(secondsAgo: TimeInterval) -> String {
        RelativeTimeText.resource(for: now.addingTimeInterval(-secondsAgo), relativeTo: now).key
    }

    @Test func `anything under a minute reads as just now`() {
        #expect([Self.key(secondsAgo: 0), Self.key(secondsAgo: 59)] == ["just now", "just now"])
    }

    @Test func `minutes, hours and days each get their own unit`() {
        #expect([
            Self.key(secondsAgo: 60),
            Self.key(secondsAgo: 59 * 60),
            Self.key(secondsAgo: 60 * 60),
            Self.key(secondsAgo: 23 * 3600),
            Self.key(secondsAgo: 24 * 3600),
            Self.key(secondsAgo: 10 * 24 * 3600),
        ] == [
            "%lld minutes ago",
            "%lld minutes ago",
            "%lld hours ago",
            "%lld hours ago",
            "%lld days ago",
            "%lld days ago",
        ])
    }

    /// Each unit truncates rather than rounds, so the phrase never claims more time has passed than
    /// has: 119 seconds is still the minutes unit, and 7199 is still hours.
    @Test func `a part-elapsed unit does not round up`() {
        #expect([Self.key(secondsAgo: 119), Self.key(secondsAgo: 7199)]
            == ["%lld minutes ago", "%lld hours ago"])
    }

    /// A clock that has moved backwards leaves the timestamp in the future; a countdown would be
    /// nonsense.
    @Test func `a future timestamp reads as just now`() {
        #expect(RelativeTimeText.resource(for: Self.now.addingTimeInterval(600), relativeTo: Self.now)
            .key == "just now")
    }

    /// Every string this type can produce is bound to the module bundle, not `Bundle.main`.
    @Test func `every relative phrase points at the module bundle`() {
        let bundles = [0, 60, 3600, 24 * 3600].map { secondsAgo -> String? in
            let resource = RelativeTimeText.resource(
                for: Self.now.addingTimeInterval(-TimeInterval(secondsAgo)),
                relativeTo: Self.now,
            )
            guard case let .atURL(url) = resource.bundle else {
                return nil
            }
            return url.lastPathComponent
        }
        #expect(bundles == Array(repeating: "BrewKit_BrewUIComponents.bundle", count: 4))
    }
}
