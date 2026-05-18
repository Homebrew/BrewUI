//
//  BrewAPIClient.swift
//  Brew
//

import Foundation

protocol BrewAPIClient: Sendable {
    func fetchFormulaInstallOnRequestAnalytics(window: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON
    func fetchCaskInstallAnalytics(window: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON
    func fetchFormulaCatalogue(etag: String?) async throws -> CatalogueResponse<FormulaCatalogueJSON>
    func fetchCaskCatalogue(etag: String?) async throws -> CatalogueResponse<CaskCatalogueJSON>
}

enum CatalogueResponse<T> {
    case notModified
    case updated(data: T, etag: String?)
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

    func fetchFormulaCatalogue(etag: String?) async throws -> CatalogueResponse<FormulaCatalogueJSON> {
        try await fetchConditionalCatalogue(for: .formulaCatalogue, etag: etag, as: FormulaCatalogueJSON.self)
    }

    func fetchCaskCatalogue(etag: String?) async throws -> CatalogueResponse<CaskCatalogueJSON> {
        try await fetchConditionalCatalogue(for: .caskCatalogue, etag: etag, as: CaskCatalogueJSON.self)
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

    private func fetchConditionalCatalogue<T: Decodable>(
        for endpoint: Endpoint,
        etag: String?,
        as type: T.Type,
    ) async throws -> CatalogueResponse<T> {
        var headers: [String: String] = [:]
        if let etag {
            headers["If-None-Match"] = etag
        }
        let request = try makeRequest(for: endpoint, headers: headers)

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

        switch httpResponse.statusCode {
        case 304:
            return .notModified
        case 200:
            do {
                let payload = try decoder.decode(type, from: data)
                let responseETag = httpResponse.value(forHTTPHeaderField: "ETag")
                return .updated(data: payload, etag: responseETag)
            } catch {
                throw BrewAPIClientError.decoding(underlying: String(describing: error))
            }
        default:
            let bodyData = Data(data.prefix(250))
            let bodySnippet = String(bytes: bodyData, encoding: .utf8) ?? ""
            throw BrewAPIClientError.httpStatus(code: httpResponse.statusCode, bodySnippet: bodySnippet)
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

    private func makeRequest(for endpoint: Endpoint, headers: [String: String]) throws -> URLRequest {
        var request = try makeRequest(for: endpoint)
        for (header, value) in headers {
            request.setValue(value, forHTTPHeaderField: header)
        }
        return request
    }

    private nonisolated static var defaultBaseURL: URL {
        URL(string: "https://formulae.brew.sh") ?? URL(fileURLWithPath: "/")
    }
}

private enum Endpoint {
    case formulaInstallOnRequest(window: BrewAnalyticsWindow)
    case caskInstall(window: BrewAnalyticsWindow)
    case formulaCatalogue
    case caskCatalogue

    var path: String {
        switch self {
        case let .formulaInstallOnRequest(window):
            "/api/analytics/install-on-request/homebrew-core/\(window.rawValue).json"
        case let .caskInstall(window):
            "/api/analytics/cask-install/homebrew-cask/\(window.rawValue).json"
        case .formulaCatalogue:
            "/api/formula.json"
        case .caskCatalogue:
            "/api/cask.json"
        }
    }
}
