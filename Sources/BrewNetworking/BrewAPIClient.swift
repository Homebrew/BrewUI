//
//  BrewAPIClient.swift
//  BrewNetworking
//

import BrewCore
import Foundation

public protocol BrewAPIClient: Sendable {
    /// Returns the raw analytics JSON body so callers can persist it verbatim (the `BrewAnalyticsJSON`
    /// DTO is lossy/`Decodable`-only and cannot be round-tripped). Supports conditional requests via
    /// `etag`, mirroring the catalogue endpoints.
    func fetchFormulaInstallOnRequestAnalytics(
        window: BrewAnalyticsWindow,
        etag: String?,
    ) async throws -> CatalogueResponse<Data>
    func fetchCaskInstallAnalytics(
        window: BrewAnalyticsWindow,
        etag: String?,
    ) async throws -> CatalogueResponse<Data>
    func fetchFormulaCatalogue(etag: String?) async throws -> CatalogueResponse<FormulaCatalogueJSON>
    func fetchCaskCatalogue(etag: String?) async throws -> CatalogueResponse<CaskCatalogueJSON>
}

public enum CatalogueResponse<T: Sendable>: Sendable {
    case notModified
    case updated(data: T, etag: String?)
}

public struct URLSessionBrewAPIClient: BrewAPIClient {
    private let baseURL: URL
    private let session: URLSession

    init(session: URLSession, baseURL: URL? = nil) {
        self.session = session
        self.baseURL = baseURL ?? URL(string: "https://formulae.brew.sh") ?? URL(fileURLWithPath: "/")
    }

    public static func live() -> URLSessionBrewAPIClient {
        URLSessionBrewAPIClient(session: .shared)
    }

    /// Test seam: a client whose `URLSession` routes every request through the given `URLProtocol`
    /// classes, so no traffic leaves the process.
    ///
    /// The protocol classes are set on a per-session configuration rather than registered globally
    /// via `URLProtocol.registerClass(_:)` — a global registration would also intercept `.shared`,
    /// and therefore any other client in the process.
    public static func stubbed(protocolClasses: [AnyClass], baseURL: URL? = nil) -> URLSessionBrewAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = protocolClasses
        return URLSessionBrewAPIClient(session: URLSession(configuration: configuration), baseURL: baseURL)
    }

    public func fetchFormulaInstallOnRequestAnalytics(
        window: BrewAnalyticsWindow,
        etag: String?,
    ) async throws -> CatalogueResponse<Data> {
        try await fetchConditionalAnalytics(for: .formulaInstallOnRequest(window: window), etag: etag)
    }

    public func fetchCaskInstallAnalytics(
        window: BrewAnalyticsWindow,
        etag: String?,
    ) async throws -> CatalogueResponse<Data> {
        try await fetchConditionalAnalytics(for: .caskInstall(window: window), etag: etag)
    }

    public func fetchFormulaCatalogue(etag: String?) async throws -> CatalogueResponse<FormulaCatalogueJSON> {
        try await fetchConditionalCatalogue(for: .formulaCatalogue, etag: etag, as: FormulaCatalogueJSON.self)
    }

    public func fetchCaskCatalogue(etag: String?) async throws -> CatalogueResponse<CaskCatalogueJSON> {
        try await fetchConditionalCatalogue(for: .caskCatalogue, etag: etag, as: CaskCatalogueJSON.self)
    }

    private func fetchConditionalAnalytics(
        for endpoint: Endpoint,
        etag: String?,
    ) async throws -> CatalogueResponse<Data> {
        var headers: [String: String] = [:]
        if let etag {
            headers["If-None-Match"] = etag
        }
        let request = try makeRequest(for: endpoint, headers: headers)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BrewAPIClientError.transport(underlying: String(describing: error))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BrewAPIClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 304:
            return .notModified
        case 200 ... 299:
            let responseETag = httpResponse.value(forHTTPHeaderField: "ETag")
            return .updated(data: data, etag: responseETag)
        default:
            let bodyData = Data(data.prefix(250))
            let bodySnippet = String(bytes: bodyData, encoding: .utf8) ?? ""
            throw BrewAPIClientError.httpStatus(code: httpResponse.statusCode, bodySnippet: bodySnippet)
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
            (data, response) = try await session.data(for: request)
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
                let payload = try JSONDecoder().decode(type, from: data)
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
