//
//  BrewAPIClientCatalogueURLSessionIntegrationTests.swift
//  BrewTests
//

import BrewCoreTestSupport
@testable import BrewNetworking
import Foundation
import Testing

struct BrewAPICatalogueIntegrationTests {
    @Test @MainActor func `fetch formula catalogue sends if-none-match and returns not modified on 304`() async throws {
        let baseURL = makeStubBaseURL()
        let expectedURL = URL(string: "/api/formula.json", relativeTo: baseURL)?.absoluteURL
        let existingETag = #""catalogue-etag-123""#
        try StubURLProtocol.register(
            [.successWithStatus(data: Data(), statusCode: 304)],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        let response = try await client.fetchFormulaCatalogue(etag: existingETag)
        let requests = try StubURLProtocol.requests(forHost: #require(baseURL.host))
        #expect(requests.count == 1)
        #expect(requests.first?.url == expectedURL)
        #expect(requests.first?.httpMethod == "GET")
        #expect(requests.first?.value(forHTTPHeaderField: "If-None-Match") == existingETag)

        switch response {
        case .notModified:
            break
        case .updated:
            Issue.record("Expected .notModified for 304 response")
        }
    }

    @Test @MainActor func `fetch cask catalogue returns updated payload and response etag on 200`() async throws {
        let baseURL = makeStubBaseURL()
        let expectedURL = URL(string: "/api/cask.json", relativeTo: baseURL)?.absoluteURL
        let returnedETag = #""catalogue-etag-456""#
        try StubURLProtocol.register(
            [
                .successWithStatus(
                    data: Data(
                        """
                        [
                          {
                            "token": "iterm2",
                            "name": ["iTerm2"],
                            "desc": "Terminal emulator",
                            "homepage": "https://iterm2.com",
                            "version": "3.5.0",
                            "depends_on": { "macos": {} }
                          }
                        ]
                        """.utf8,
                    ),
                    statusCode: 200,
                    headers: ["ETag": returnedETag],
                ),
            ],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        let response = try await client.fetchCaskCatalogue(etag: nil)
        let requests = try StubURLProtocol.requests(forHost: #require(baseURL.host))
        #expect(requests.count == 1)
        #expect(requests.first?.url == expectedURL)
        #expect(requests.first?.value(forHTTPHeaderField: "If-None-Match") == nil)

        switch response {
        case .notModified:
            Issue.record("Expected .updated for 200 response")
        case let .updated(data: data, etag):
            #expect(data.items.count == 1)
            #expect(data.decodeFailures.isEmpty)
            #expect(data.items.first?.name == "iterm2")
            #expect(data.items.first?.description == "Terminal emulator")
            #expect(data.items.first?.homepage == "https://iterm2.com")
            #expect(data.items.first?.stableVersion == "3.5.0")
            #expect(etag == returnedETag)
        }
    }

    @Test @MainActor func `fetch formula catalogue collects decode failure on missing required fields`() async throws {
        let baseURL = makeStubBaseURL()
        try StubURLProtocol.register(
            [
                .successWithStatus(
                    data: Data(
                        """
                        [
                          {
                            "name": "wget"
                          }
                        ]
                        """.utf8,
                    ),
                    statusCode: 200,
                    headers: ["ETag": #""catalogue-etag-789""#],
                ),
            ],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        let response = try await client.fetchFormulaCatalogue(etag: nil)
        switch response {
        case .notModified:
            Issue.record("Expected .updated for 200 response")
        case let .updated(data: data, etag: _):
            #expect(data.items.isEmpty)
            #expect(data.decodeFailures.count == 1)
            #expect(data.decodeFailures.first?.index == 0)
        }
    }
}
