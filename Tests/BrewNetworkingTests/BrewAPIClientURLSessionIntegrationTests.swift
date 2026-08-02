//
//  BrewAPIClientURLSessionIntegrationTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewNetworking
import Foundation
import Testing

struct BrewAPIClientURLSessionIntegrationTests {
    @Test @MainActor func `fetch formula analytics returns raw body`() async throws {
        let baseURL = makeStubBaseURL()
        let expectedURL = URL(
            string: "/api/analytics/install-on-request/homebrew-core/30d.json",
            relativeTo: baseURL,
        )?.absoluteURL
        let body = Data(
            """
            {
              "category": "formula_install_on_request",
              "total_items": 2,
              "total_count": 1200,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "wget": [{ "number": 1, "formula": "wget", "count": "1,000" }],
                "bat": [{ "number": 2, "formula": "bat", "count": "200" }]
              }
            }
            """.utf8,
        )
        try StubURLProtocol.register(
            [.successWithStatus(data: body, statusCode: 200)],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        let response = try await client.fetchFormulaInstallOnRequestAnalytics(window: .days30, etag: nil)
        let requests = try StubURLProtocol.requests(forHost: #require(baseURL.host))
        #expect(requests.count == 1)
        #expect(requests.first?.url == expectedURL)
        #expect(requests.first?.httpMethod == "GET")

        guard case let .updated(data: data, etag: _) = response else {
            Issue.record("Expected updated analytics payload")
            return
        }
        // The client hands back the response verbatim so callers can persist it byte-for-byte.
        #expect(data == body)
        let decoded = try JSONDecoder().decode(BrewAnalyticsJSON.self, from: data)
        #expect(decoded.category == "formula_install_on_request")
        #expect(decoded.totalCount == 1200)
    }

    @Test @MainActor func `fetch analytics forwards etag as conditional request header`() async throws {
        let baseURL = makeStubBaseURL()
        try StubURLProtocol.register(
            [.successWithStatus(data: Data(), statusCode: 304)],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        let response = try await client.fetchFormulaInstallOnRequestAnalytics(
            window: .days30,
            etag: #""cached-etag""#,
        )
        let requests = try StubURLProtocol.requests(forHost: #require(baseURL.host))
        #expect(requests.first?.value(forHTTPHeaderField: "If-None-Match") == #""cached-etag""#)
        guard case .notModified = response else {
            Issue.record("Expected notModified for a 304 response")
            return
        }
    }

    @Test @MainActor func `fetch cask analytics hits cask endpoint`() async throws {
        let baseURL = makeStubBaseURL()
        let expectedURL = URL(
            string: "/api/analytics/cask-install/homebrew-cask/90d.json",
            relativeTo: baseURL,
        )?.absoluteURL
        try StubURLProtocol.register(
            [
                .successWithStatus(
                    data: Data(
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
                    ),
                    statusCode: 200,
                ),
            ],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        _ = try await client.fetchCaskInstallAnalytics(window: .days90, etag: nil)
        let requests = try StubURLProtocol.requests(forHost: #require(baseURL.host))
        #expect(requests.first?.url == expectedURL)
    }

    @Test @MainActor func `fetch formula and cask analytics concurrently`() async throws {
        let baseURL = makeStubBaseURL()
        let host = try #require(baseURL.host)
        StubURLProtocol.registerByPath(
            [
                "/api/analytics/install-on-request/homebrew-core/30d.json": Self.formulaAnalyticsStub(name: "wget"),
                "/api/analytics/cask-install/homebrew-cask/30d.json": Self.caskAnalyticsStub(name: "iterm2"),
            ],
            forHost: host,
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        async let formulaAnalytics = client.fetchFormulaInstallOnRequestAnalytics(window: .days30, etag: nil)
        async let caskAnalytics = client.fetchCaskInstallAnalytics(window: .days30, etag: nil)

        guard case let .updated(data: formulaData, etag: _) = try await formulaAnalytics,
              case let .updated(data: caskData, etag: _) = try await caskAnalytics
        else {
            Issue.record("Expected updated analytics payloads")
            return
        }

        let formula = try JSONDecoder().decode(BrewAnalyticsJSON.self, from: formulaData)
        let cask = try JSONDecoder().decode(BrewAnalyticsJSON.self, from: caskData)
        #expect(try formula.rankedPackageCounts().first?.name == "wget")
        #expect(try cask.rankedPackageCounts().first?.name == "iterm2")
        #expect(StubURLProtocol.requests(forHost: host).count == 2)
    }

    @Test @MainActor func `fetch throws http status error for non success response`() async throws {
        let baseURL = makeStubBaseURL()
        try StubURLProtocol.register(
            [.successWithStatus(data: Data("{\"error\":\"bad\"}".utf8), statusCode: 500)],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        await #expect(throws: BrewAPIClientError.self) {
            _ = try await client.fetchFormulaInstallOnRequestAnalytics(window: .days30, etag: nil)
        }
    }

    @Test @MainActor func `fetch throws transport error when request execution fails`() async throws {
        let baseURL = makeStubBaseURL()
        try StubURLProtocol.register(
            [.failure(URLError(.timedOut))],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        await #expect(throws: BrewAPIClientError.self) {
            _ = try await client.fetchFormulaInstallOnRequestAnalytics(window: .days30, etag: nil)
        }
    }

    @Test @MainActor func `fetch throws invalid response when URL response is not HTTP`() async throws {
        let baseURL = makeStubBaseURL()
        let responseURL = try #require(URL(string: "https://formulae.brew.sh"))
        try StubURLProtocol.register(
            [
                .successWithResponse(
                    data: Data(),
                    response: URLResponse(
                        url: responseURL,
                        mimeType: "application/json",
                        expectedContentLength: 0,
                        textEncodingName: nil,
                    ),
                ),
            ],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        await #expect(throws: BrewAPIClientError.self) {
            _ = try await client.fetchFormulaInstallOnRequestAnalytics(window: .days30, etag: nil)
        }
    }

    private static func formulaAnalyticsStub(name: String) -> StubURLProtocol.StubbedResult {
        .successWithStatus(
            data: Data(
                """
                {
                  "category": "formula_install_on_request",
                  "total_items": 1,
                  "total_count": 100,
                  "start_date": "2026-04-17",
                  "end_date": "2026-05-17",
                  "formulae": {
                    "\(name)": [{ "number": 1, "formula": "\(name)", "count": "100" }]
                  }
                }
                """.utf8,
            ),
            statusCode: 200,
        )
    }

    private static func caskAnalyticsStub(name: String) -> StubURLProtocol.StubbedResult {
        .successWithStatus(
            data: Data(
                """
                {
                  "category": "cask_install",
                  "total_items": 1,
                  "total_count": 50,
                  "start_date": "2026-04-17",
                  "end_date": "2026-05-17",
                  "formulae": {
                    "\(name)": [{ "number": 1, "cask": "\(name)", "count": "50" }]
                  }
                }
                """.utf8,
            ),
            statusCode: 200,
        )
    }
}
