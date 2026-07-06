//
//  DiscoverAnalyticsCaching.swift
//  BrewNetworking
//

import BrewCore
import Foundation

public protocol DiscoverAnalyticsCaching: Sendable {
    func formulaAnalyticsData(window: BrewAnalyticsWindow) async -> Data?
    func caskAnalyticsData(window: BrewAnalyticsWindow) async -> Data?
    func etag(for kind: DiscoverAnalyticsCache.AnalyticsKind, window: BrewAnalyticsWindow) async -> String?
    func updateFormulaAnalytics(window: BrewAnalyticsWindow, with rawData: Data, etag: String?) async throws
    func updateCaskAnalytics(window: BrewAnalyticsWindow, with rawData: Data, etag: String?) async throws
}
