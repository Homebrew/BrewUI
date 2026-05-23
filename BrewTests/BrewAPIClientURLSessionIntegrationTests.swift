//
//  BrewAPIClientURLSessionIntegrationTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct BrewAPIClientURLSessionIntegrationTests {
    @Test @MainActor func `fetch formula analytics decodes payload`() async throws {
        let baseURL = makeStubBaseURL()
        let expectedURL = URL(
            string: "/api/analytics/install-on-request/homebrew-core/30d.json",
            relativeTo: baseURL,
        )?.absoluteURL
        try StubURLProtocol.register(
            [
                .successWithStatus(
                    data: Data(
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
                    ),
                    statusCode: 200,
                ),
            ],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        let result = try await client.fetchFormulaInstallOnRequestAnalytics(window: .days30)
        let requests = try StubURLProtocol.requests(forHost: #require(baseURL.host))
        #expect(requests.count == 1)
        #expect(requests.first?.url == expectedURL)
        #expect(requests.first?.httpMethod == "GET")
        #expect(result.category == "formula_install_on_request")
        #expect(result.totalCount == 1200)

        let countsByName = Dictionary(uniqueKeysWithValues: result.packageCounts.map { ($0.name, $0.count) })
        #expect(countsByName["wget"] == 1000)
        #expect(countsByName["bat"] == 200)
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

        _ = try await client.fetchCaskInstallAnalytics(window: .days90)
        let requests = try StubURLProtocol.requests(forHost: #require(baseURL.host))
        #expect(requests.first?.url == expectedURL)
    }

    @Test @MainActor func `fetch formula and cask analytics concurrently`() async throws {
        let baseURL = makeStubBaseURL()
        let host = try #require(baseURL.host)
        StubURLProtocol.registerByPath(
            [
                "/api/analytics/install-on-request/homebrew-core/30d.json": .successWithStatus(
                    data: Data(
                        """
                        {
                          "category": "formula_install_on_request",
                          "total_items": 1,
                          "total_count": 100,
                          "start_date": "2026-04-17",
                          "end_date": "2026-05-17",
                          "formulae": {
                            "wget": [{ "formula": "wget", "count": "100" }]
                          }
                        }
                        """.utf8,
                    ),
                    statusCode: 200,
                ),
                "/api/analytics/cask-install/homebrew-cask/30d.json": .successWithStatus(
                    data: Data(
                        """
                        {
                          "category": "cask_install",
                          "total_items": 1,
                          "total_count": 50,
                          "start_date": "2026-04-17",
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
            forHost: host,
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        async let formulaAnalytics = client.fetchFormulaInstallOnRequestAnalytics(window: .days30)
        async let caskAnalytics = client.fetchCaskInstallAnalytics(window: .days30)

        let formulaResult = try await formulaAnalytics
        let caskResult = try await caskAnalytics

        #expect(formulaResult.packageCounts.first?.name == "wget")
        #expect(caskResult.packageCounts.first?.name == "iterm2")
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
            _ = try await client.fetchFormulaInstallOnRequestAnalytics(window: .days30)
        }
    }

    @Test @MainActor func `fetch throws decoding error for invalid JSON`() async throws {
        let baseURL = makeStubBaseURL()
        try StubURLProtocol.register(
            [.successWithStatus(data: Data("{ this-is-not-json }".utf8), statusCode: 200)],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        await #expect(throws: BrewAPIClientError.self) {
            _ = try await client.fetchFormulaInstallOnRequestAnalytics(window: .days30)
        }
    }

    @Test @MainActor func `fetch throws decoding error when required fields are missing`() async throws {
        let baseURL = makeStubBaseURL()
        try StubURLProtocol.register(
            [
                .successWithStatus(
                    data: Data(
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
                    ),
                    statusCode: 200,
                ),
            ],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        await #expect(throws: BrewAPIClientError.self) {
            _ = try await client.fetchFormulaInstallOnRequestAnalytics(window: .days30)
        }
    }

    @Test @MainActor func `fetch throws decoding error when entry count is malformed`() async throws {
        let baseURL = makeStubBaseURL()
        try StubURLProtocol.register(
            [
                .successWithStatus(
                    data: Data(
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
                    ),
                    statusCode: 200,
                ),
            ],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        await #expect(throws: BrewAPIClientError.self) {
            _ = try await client.fetchFormulaInstallOnRequestAnalytics(window: .days30)
        }
    }

    @Test @MainActor func `fetch throws decoding error when entry package identity is missing`() async throws {
        let baseURL = makeStubBaseURL()
        try StubURLProtocol.register(
            [
                .successWithStatus(
                    data: Data(
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
                    ),
                    statusCode: 200,
                ),
            ],
            forHost: #require(baseURL.host),
        )
        let session = makeStubbedSession()
        let client = URLSessionBrewAPIClient(session: session, baseURL: baseURL)

        await #expect(throws: BrewAPIClientError.self) {
            _ = try await client.fetchFormulaInstallOnRequestAnalytics(window: .days30)
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
            _ = try await client.fetchFormulaInstallOnRequestAnalytics(window: .days30)
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
            _ = try await client.fetchFormulaInstallOnRequestAnalytics(window: .days30)
        }
    }
}

func makeStubbedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
}

func makeStubBaseURL() -> URL {
    URL(string: "https://stub-\(UUID().uuidString).local") ?? URL(fileURLWithPath: "/")
}

final class StubURLProtocol: URLProtocol {
    enum StubbedResult {
        case successWithStatus(data: Data, statusCode: Int, headers: [String: String] = [:])
        case successWithResponse(data: Data, response: URLResponse)
        case failure(Error)
    }

    private static let lock = NSLock()
    private static var queuedResultsByHost: [String: [StubbedResult]] = [:]
    private static var queuedResultsByHostAndPath: [String: [String: [StubbedResult]]] = [:]
    private static var repeatingResultsByHostAndPath: [String: [String: StubbedResult]] = [:]
    private static var requestsByHost: [String: [URLRequest]] = [:]

    static func register(_ results: [StubbedResult], forHost host: String) {
        lock.lock()
        queuedResultsByHost[host] = results
        queuedResultsByHostAndPath[host] = [:]
        repeatingResultsByHostAndPath[host] = [:]
        requestsByHost[host] = []
        lock.unlock()
    }

    /// Registers one stub per URL path so concurrent requests get the correct payload regardless of completion order.
    static func registerByPath(_ resultsByPath: [String: StubbedResult], forHost host: String) {
        lock.lock()
        queuedResultsByHost[host] = []
        queuedResultsByHostAndPath[host] = resultsByPath.mapValues { [$0] }
        repeatingResultsByHostAndPath[host] = [:]
        requestsByHost[host] = []
        lock.unlock()
    }

    /// Same as `registerByPath`, but stubs are reused for every matching request (for stress tests).
    static func registerRepeatingByPath(_ resultsByPath: [String: StubbedResult], forHost host: String) {
        lock.lock()
        queuedResultsByHost[host] = []
        queuedResultsByHostAndPath[host] = [:]
        repeatingResultsByHostAndPath[host] = resultsByPath
        requestsByHost[host] = []
        lock.unlock()
    }

    static func requests(forHost host: String) -> [URLRequest] {
        lock.lock()
        let requests = requestsByHost[host] ?? []
        lock.unlock()
        return requests
    }

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let host = request.url?.host else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let result: StubbedResult
        Self.lock.lock()
        Self.requestsByHost[host, default: []].append(request)
        if let path = request.url?.path,
           let repeatingResults = Self.repeatingResultsByHostAndPath[host],
           let repeatingResult = repeatingResults[path]
        {
            result = repeatingResult
        } else if let path = request.url?.path,
                  var pathQueues = Self.queuedResultsByHostAndPath[host],
                  var pathQueue = pathQueues[path],
                  !pathQueue.isEmpty
        {
            result = pathQueue.removeFirst()
            pathQueues[path] = pathQueue.isEmpty ? nil : pathQueue
            Self.queuedResultsByHostAndPath[host] = pathQueues
        } else {
            var queuedResults = Self.queuedResultsByHost[host] ?? []
            if queuedResults.isEmpty {
                result = .failure(URLError(.badServerResponse))
            } else {
                result = queuedResults.removeFirst()
                Self.queuedResultsByHost[host] = queuedResults
            }
        }
        Self.lock.unlock()

        switch result {
        case let .successWithStatus(data, statusCode, headers):
            if let url = request.url,
               let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers)
            {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            }
        case let .successWithResponse(data, response):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
