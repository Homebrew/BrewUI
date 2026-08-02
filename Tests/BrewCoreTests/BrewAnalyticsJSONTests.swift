//
//  BrewAnalyticsJSONTests.swift
//  BrewTests
//

import BrewCore
import Foundation
import Testing

/// Coverage for the analytics DTO. `BrewAnalyticsJSON` is a thin wire mirror (synthesized decode), so
/// these fixtures split into two groups: decode-time failures (missing/mistyped required fields) and
/// mapping-time failures raised by ``BrewAnalyticsJSON/rankedPackageCounts()`` (bad buckets/entries).
/// The live API keys entries by name with no rank field, so ranking is derived from `count`.
struct BrewAnalyticsJSONTests {
    @Test func `decodes formula counts and flattens buckets`() throws {
        let json = Data(
            """
            {
              "category": "install-on-request",
              "total_items": 2,
              "total_count": 1200,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "wget": [{ "formula": "wget", "count": "1,000" }],
                "bat": [{ "formula": "bat", "count": "200" }]
              }
            }
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(BrewAnalyticsJSON.self, from: json)

        #expect(decoded.category == "install-on-request")
        #expect(decoded.totalCount == 1200)
        let countsByName = try Dictionary(uniqueKeysWithValues: decoded.rankedPackageCounts().map { ($0.name, $0.count) })
        #expect(countsByName["wget"] == 1000)
        #expect(countsByName["bat"] == 200)
    }

    @Test func `ranks package counts by install count with a name tie-break`() throws {
        // Keys are alphabetical (like the live API) and unrelated to rank; ordering comes from `count`,
        // with equal counts broken by name so the order is stable.
        let json = Data(
            """
            {
              "category": "install-on-request",
              "total_items": 3,
              "total_count": 3300,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "bat": [{ "formula": "bat", "count": "1,500" }],
                "fd": [{ "formula": "fd", "count": "300" }],
                "wget": [{ "formula": "wget", "count": "1,500" }]
              }
            }
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(BrewAnalyticsJSON.self, from: json)

        #expect(try decoded.rankedPackageCounts().map(\.name) == ["bat", "wget", "fd"])
    }

    @Test func `decodes cask entries into cask references`() throws {
        let json = Data(
            """
            {
              "category": "cask-install",
              "total_items": 1,
              "total_count": 50,
              "start_date": "2026-02-17",
              "end_date": "2026-05-17",
              "formulae": {
                "iterm2": [{ "cask": "iterm2", "count": "50" }]
              }
            }
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(BrewAnalyticsJSON.self, from: json)
        #expect(try decoded.rankedPackageCounts().first?.reference == .cask(token: "iterm2"))
    }

    @Test func `throws when required fields are missing`() throws {
        // `total_count` is absent, so the synthesized decode fails before any mapping is attempted.
        let json = Data(
            """
            {
              "category": "install-on-request",
              "total_items": 2,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "wget": [{ "formula": "wget", "count": "1000" }]
              }
            }
            """.utf8,
        )

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(BrewAnalyticsJSON.self, from: json)
        }
    }

    @Test func `throws when entry count is malformed`() throws {
        // `count` mirrors the wire as a String, so this decodes fine and fails during mapping.
        let json = Data(
            """
            {
              "category": "install-on-request",
              "total_items": 2,
              "total_count": 1200,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "wget": [{ "formula": "wget", "count": "not-a-number" }]
              }
            }
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(BrewAnalyticsJSON.self, from: json)
        #expect(throws: BrewAnalyticsMappingError.self) {
            _ = try decoded.rankedPackageCounts()
        }
    }

    @Test func `throws when entry package identity is missing`() throws {
        let json = Data(
            """
            {
              "category": "install-on-request",
              "total_items": 2,
              "total_count": 1200,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "wget": [{ "count": "1000" }]
              }
            }
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(BrewAnalyticsJSON.self, from: json)
        #expect(throws: BrewAnalyticsMappingError.self) {
            _ = try decoded.rankedPackageCounts()
        }
    }

    @Test func `throws when neither formulae nor casks bucket is present`() throws {
        let json = Data(
            """
            {
              "category": "install-on-request",
              "total_items": 0,
              "total_count": 0,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17"
            }
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(BrewAnalyticsJSON.self, from: json)
        #expect(throws: BrewAnalyticsMappingError.missingPackageBucket) {
            _ = try decoded.rankedPackageCounts()
        }
    }
}
