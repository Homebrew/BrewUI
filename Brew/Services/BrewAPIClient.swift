//
//  BrewAPIClient.swift
//  Brew
//

import Foundation

@MainActor
protocol BrewAPIClient: Sendable {
    func fetchFormulaInstallOnRequestAnalytics(window: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON
    func fetchCaskInstallAnalytics(window: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON
}

enum BrewAPIClientError: Error, Equatable {
    case invalidURL(path: String)
    case transport(underlying: String)
    case invalidResponse
    case httpStatus(code: Int, bodySnippet: String)
    case decoding(underlying: String)
}

struct URLSessionBrewAPIClient: BrewAPIClient {
    private let baseURL: URL
    private let fetchData: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private let decoder: JSONDecoder

    init(
        baseURL: URL = Self.defaultBaseURL,
        decoder: JSONDecoder = JSONDecoder(),
        fetchData: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse),
    ) {
        self.baseURL = baseURL
        self.decoder = decoder
        self.fetchData = fetchData
    }

    init(session: URLSession, baseURL: URL = Self.defaultBaseURL, decoder: JSONDecoder = JSONDecoder()) {
        self.init(baseURL: baseURL, decoder: decoder) { request in
            try await session.data(for: request)
        }
    }

    static func live() -> URLSessionBrewAPIClient {
        URLSessionBrewAPIClient(session: URLSession.shared)
    }

    func fetchFormulaInstallOnRequestAnalytics(window: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON {
        try await fetchAnalytics(for: .formulaInstallOnRequest(window: window))
    }

    func fetchCaskInstallAnalytics(window: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON {
        try await fetchAnalytics(for: .caskInstall(window: window))
    }

    private func fetchAnalytics(for endpoint: Endpoint) async throws -> BrewAnalyticsJSON {
        let request = try makeRequest(for: endpoint)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await fetchData(request)
        } catch {
            throw BrewAPIClientError.transport(underlying: String(describing: error))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BrewAPIClientError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let bodyData = Data(data.prefix(250))
            let bodySnippet = String(bytes: bodyData, encoding: .utf8) ?? ""
            throw BrewAPIClientError.httpStatus(code: httpResponse.statusCode, bodySnippet: bodySnippet)
        }

        do {
            return try decoder.decode(BrewAnalyticsJSON.self, from: data)
        } catch {
            throw BrewAPIClientError.decoding(underlying: String(describing: error))
        }
    }

    private func makeRequest(for endpoint: Endpoint) throws -> URLRequest {
        guard let url = URL(string: endpoint.path, relativeTo: baseURL)?.absoluteURL else {
            throw BrewAPIClientError.invalidURL(path: endpoint.path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return request
    }

    private nonisolated static var defaultBaseURL: URL {
        URL(string: "https://formulae.brew.sh") ?? URL(fileURLWithPath: "/")
    }
}

private enum Endpoint {
    case formulaInstallOnRequest(window: BrewAnalyticsWindow)
    case caskInstall(window: BrewAnalyticsWindow)

    var path: String {
        switch self {
        case let .formulaInstallOnRequest(window):
            "/api/analytics/install-on-request/homebrew-core/\(window.rawValue).json"
        case let .caskInstall(window):
            "/api/analytics/cask-install/homebrew-cask/\(window.rawValue).json"
        }
    }
}
