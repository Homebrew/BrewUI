//
//  BrewUITestingStubURLProtocol.swift
//  Homebrew
//

import Foundation

/// Answers UI-test requests from the installed fixture tree, so the real ``URLSessionBrewAPIClient``
/// still builds the request, negotiates ETag/304, decodes and caches.
///
/// Reachable only through ``URLSessionBrewAPIClient/stubbed(protocolClasses:baseURL:)``, which installs
/// it on one ephemeral session rather than registering it globally — a global registration would also
/// capture `.shared`. State comes from the process environment, so concurrent loads need no locking.
final nonisolated class BrewUITestingStubURLProtocol: URLProtocol {
    /// Fixture layout under `<fixtures>/<scenario>/http/`: `<key>` is the body, `<key>.status` the
    /// status code (default 200), `<key>.etag` the `ETag`, also matched against `If-None-Match`.
    private enum FixtureSuffix {
        static let status = ".status"
        static let etag = ".etag"
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let stub = Self.stub(for: url, ifNoneMatch: request.value(forHTTPHeaderField: "If-None-Match"))
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headerFields,
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private struct Stub {
        let statusCode: Int
        let headerFields: [String: String]
        let body: Data
    }

    private static func stub(for url: URL, ifNoneMatch: String?) -> Stub {
        guard let directory = BrewUITestingLaunchConfiguration.current()?.httpFixturesURL else {
            return missingFixture(reason: "no fixtures directory")
        }

        let key = fixtureKey(for: url)
        let bodyURL = directory.appendingPathComponent(key)
        guard let body = try? Data(contentsOf: bodyURL) else {
            return missingFixture(reason: "no fixture named \(key)")
        }

        let etag = trimmedContents(of: directory.appendingPathComponent(key + FixtureSuffix.etag))
        var headerFields = ["Content-Type": "application/json"]
        if let etag {
            headerFields["ETag"] = etag
        }

        // Answer the client's real conditional request, so the 304 branch is exercised not stubbed away.
        if let etag, let ifNoneMatch, ifNoneMatch == etag {
            return Stub(statusCode: 304, headerFields: headerFields, body: Data())
        }

        let statusText = trimmedContents(of: directory.appendingPathComponent(key + FixtureSuffix.status))
        let statusCode = statusText.flatMap(Int.init) ?? 200
        return Stub(statusCode: statusCode, headerFields: headerFields, body: body)
    }

    /// `/api/analytics/cask-install/homebrew-cask/30d.json` → `api_analytics_cask-install_homebrew-cask_30d.json`.
    private static func fixtureKey(for url: URL) -> String {
        url.path
            .split(separator: "/")
            .joined(separator: "_")
    }

    /// An unfixtured endpoint is a test-authoring mistake, not a scenario. 404 puts the reason in the
    /// body snippet the real client surfaces.
    private static func missingFixture(reason: String) -> Stub {
        Stub(
            statusCode: 404,
            headerFields: ["Content-Type": "text/plain"],
            body: Data("UI-test stub: \(reason)".utf8),
        )
    }

    private static func trimmedContents(of url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
