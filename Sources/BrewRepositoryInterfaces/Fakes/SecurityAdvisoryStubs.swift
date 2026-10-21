//
//  SecurityAdvisoryStubs.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation
import Observation

/// Observable advisory repository preloaded with a fixed report (or error) — for previews/tests.
/// `load(forceRefresh:)` is a no-op so the preset state stays put.
@Observable
@MainActor
public final class StubSecurityAdvisoryRepository: SecurityAdvisoryRepository {
    public private(set) var state: LoadState<SecurityAdvisoryReport, any Error>
    public private(set) var isRefreshing = false
    public private(set) var scannedAt: Date?

    public init(report: SecurityAdvisoryReport, scannedAt: Date? = nil) {
        state = .loaded(report)
        self.scannedAt = scannedAt
    }

    public init(error: any Error) {
        state = .failed(error)
    }

    public func load(forceRefresh _: Bool) async {}
}
