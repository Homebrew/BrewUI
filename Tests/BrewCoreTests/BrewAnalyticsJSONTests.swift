//
//  BrewAnalyticsJSONTests.swift
//  BrewTests
//

import BrewCore
import Foundation
import Testing

/// Decoding coverage for the analytics DTO. The API client now returns the raw response bytes and the
/// repository decodes them through this type, so these fixtures exercise the flatten/validation logic
/// directly rather than through a URLSession stub.
struct BrewAnalyticsJSONTests {
    @Test func `decodes formula ranking and flattens buckets`() throws {
        let json = Data(
            """
            {
              "category": "formula_install_on_request",
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

        #expect(decoded.category == "formula_install_on_request")
        #expect(decoded.totalCount == 1200)
        let countsByName = Dictionary(uniqueKeysWithValues: decoded.packageCounts.map { ($0.name, $0.count) })
        #expect(countsByName["wget"] == 1000)
        #expect(countsByName["bat"] == 200)
    }

    @Test func `decodes cask ranking into cask references`() throws {
        let json = Data(
            """
            {
              "category": "cask_install",
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
        #expect(decoded.packageCounts.first?.reference == .cask(token: "iterm2"))
    }

    @Test func `throws when required fields are missing`() throws {
        let json = Data(
            """
            {
              "category": "formula_install_on_request",
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
        let json = Data(
            """
            {
              "category": "formula_install_on_request",
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

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(BrewAnalyticsJSON.self, from: json)
        }
    }

    @Test func `throws when entry package identity is missing`() throws {
        let json = Data(
            """
            {
              "category": "formula_install_on_request",
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

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(BrewAnalyticsJSON.self, from: json)
        }
    }

    @Test func `throws when neither formulae nor casks bucket is present`() throws {
        let json = Data(
            """
            {
              "category": "formula_install_on_request",
              "total_items": 0,
              "total_count": 0,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17"
            }
            """.utf8,
        )

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(BrewAnalyticsJSON.self, from: json)
        }
    }
}
