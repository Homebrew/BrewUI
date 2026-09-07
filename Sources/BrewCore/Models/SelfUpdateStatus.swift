//
//  SelfUpdateStatus.swift
//  BrewCore
//

import Foundation

/// ``isUpdateAvailable`` is the cask's `outdated` flag verbatim, not a comparison of the version strings —
/// there is no semantic-version comparator here.
public struct SelfUpdateStatus: Hashable, Sendable {
    public let runningVersion: String
    public let latestVersion: String?
    public let homepageURL: URL?
    public let isUpdateAvailable: Bool

    public init(
        runningVersion: String,
        latestVersion: String?,
        homepageURL: URL?,
        isUpdateAvailable: Bool,
    ) {
        self.runningVersion = runningVersion
        self.latestVersion = latestVersion
        self.homepageURL = homepageURL
        self.isUpdateAvailable = isUpdateAvailable
    }

    /// Also the answer when the cask isn't in the inventory at all.
    public static func upToDate(runningVersion: String, homepageURL: URL? = SelfUpdateIdentity.homepageURL) -> SelfUpdateStatus {
        SelfUpdateStatus(
            runningVersion: runningVersion,
            latestVersion: nil,
            homepageURL: homepageURL,
            isUpdateAvailable: false,
        )
    }
}
