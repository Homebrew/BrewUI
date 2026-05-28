//
//  StubURLProtocol.swift
//  BrewCoreTestSupport
//

import Foundation

public func makeStubbedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
}

public func makeStubBaseURL() -> URL {
    URL(string: "https://stub-\(UUID().uuidString).local") ?? URL(fileURLWithPath: "/")
}

public final class StubURLProtocol: URLProtocol {
    public enum StubbedResult {
        case successWithStatus(data: Data, statusCode: Int, headers: [String: String] = [:])
        case successWithResponse(data: Data, response: URLResponse)
        case failure(any Error)
    }

    private static let lock = NSLock()
    /// Mutation is serialized by `lock`; opt out of the global-mutable-state check rather than
    /// re-expressing the lock through `Mutex` for test-only stubbing.
    private nonisolated(unsafe) static var queuedResultsByHost: [String: [StubbedResult]] = [:]
    private nonisolated(unsafe) static var queuedResultsByHostAndPath: [String: [String: [StubbedResult]]] = [:]
    private nonisolated(unsafe) static var repeatingResultsByHostAndPath: [String: [String: StubbedResult]] = [:]
    private nonisolated(unsafe) static var requestsByHost: [String: [URLRequest]] = [:]

    public static func register(_ results: [StubbedResult], forHost host: String) {
        lock.lock()
        queuedResultsByHost[host] = results
        queuedResultsByHostAndPath[host] = [:]
        repeatingResultsByHostAndPath[host] = [:]
        requestsByHost[host] = []
        lock.unlock()
    }

    /// Registers one stub per URL path so concurrent requests get the correct payload regardless of completion order.
    public static func registerByPath(_ resultsByPath: [String: StubbedResult], forHost host: String) {
        lock.lock()
        queuedResultsByHost[host] = []
        queuedResultsByHostAndPath[host] = resultsByPath.mapValues { [$0] }
        repeatingResultsByHostAndPath[host] = [:]
        requestsByHost[host] = []
        lock.unlock()
    }

    /// Same as `registerByPath`, but stubs are reused for every matching request (for stress tests).
    public static func registerRepeatingByPath(_ resultsByPath: [String: StubbedResult], forHost host: String) {
        lock.lock()
        queuedResultsByHost[host] = []
        queuedResultsByHostAndPath[host] = [:]
        repeatingResultsByHostAndPath[host] = resultsByPath
        requestsByHost[host] = []
        lock.unlock()
    }

    public static func requests(forHost host: String) -> [URLRequest] {
        lock.lock()
        let requests = requestsByHost[host] ?? []
        lock.unlock()
        return requests
    }

    // swiftlint:disable:next static_over_final_class
    override public class func canInit(with _: URLRequest) -> Bool {
        true
    }

    // swiftlint:disable:next static_over_final_class
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override public func startLoading() {
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

    override public func stopLoading() {}
}
