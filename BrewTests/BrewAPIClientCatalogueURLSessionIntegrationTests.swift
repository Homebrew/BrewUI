//
//  BrewAPIClientCatalogueURLSessionIntegrationTests.swift
//  BrewTests
//

@testable import Brew
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

    @Test func `decodes homebrew wire cask bulk shape`() throws {
        let data = Data(
            """
            [
              {
                "token": "iterm2",
                "name": ["iTerm2"],
                "desc": "Terminal emulator",
                "homepage": "https://iterm2.com",
                "version": "3.5.0",
                "depends_on": { "macos": { ">=": ["12"] } }
              }
            ]
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(CaskCatalogueJSON.self, from: data)

        #expect(decoded.items.count == 1)
        #expect(decoded.decodeFailures.isEmpty)
        #expect(decoded.items.first?.name == "iterm2")
        #expect(decoded.items.first?.displayName == "iTerm2")
        #expect(decoded.items.first?.stableVersion == "3.5.0")
    }

    @Test func `decodes cask with null desc`() throws {
        let data = Data(
            """
            [
              {
                "token": "0-ad",
                "name": ["0 A.D."],
                "desc": null,
                "homepage": "https://play0ad.com/",
                "version": "0.28.0",
                "depends_on": { "macos": {} }
              }
            ]
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(CaskCatalogueJSON.self, from: data)

        #expect(decoded.items.count == 1)
        #expect(decoded.decodeFailures.isEmpty)
        #expect(decoded.items.first?.description == nil)
    }

    @Test func `decodes cask with omitted desc`() throws {
        let data = Data(
            """
            [
              {
                "token": "0-ad",
                "name": ["0 A.D."],
                "homepage": "https://play0ad.com/",
                "version": "0.28.0",
                "depends_on": { "macos": {} }
              }
            ]
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(CaskCatalogueJSON.self, from: data)

        #expect(decoded.items.count == 1)
        #expect(decoded.decodeFailures.isEmpty)
        #expect(decoded.items.first?.description == nil)
    }

    @Test @MainActor func `fetch formula catalogue keeps valid items when one item fails decoding`() async throws {
        let baseURL = makeStubBaseURL()
        try StubURLProtocol.register(
            [
                .successWithStatus(
                    data: Data(
                        """
                        [
                          {
                            "name": "wget",
                            "desc": "Network downloader",
                            "homepage": "https://www.gnu.org/software/wget/",
                            "versions": { "stable": "1.24.5" },
                            "dependencies": []
                          },
                          {
                            "name": "broken-item"
                          }
                        ]
                        """.utf8,
                    ),
                    statusCode: 200,
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
            #expect(data.items.count == 1)
            #expect(data.items.first?.name == "wget")
            #expect(data.decodeFailures.count == 1)
            #expect(data.decodeFailures.first?.index == 1)
        }
    }
}
