//
//  SelfUpgradeStatus.swift
//  BrewCore
//

import Foundation

/// ``isUpgradeAvailable`` is the cask's `outdated` flag verbatim, not a comparison of the version strings —
/// there is no semantic-version comparator here.
public struct SelfUpgradeStatus: Hashable, Sendable {
    public let runningVersion: String
    public let latestVersion: String?
    public let homepageURL: URL?
    public let isUpgradeAvailable: Bool

    public init(
        runningVersion: String,
        latestVersion: String?,
        homepageURL: URL?,
        isUpgradeAvailable: Bool,
    ) {
        self.runningVersion = runningVersion
        self.latestVersion = latestVersion
        self.homepageURL = homepageURL
        self.isUpgradeAvailable = isUpgradeAvailable
    }

    /// Also the answer when the cask isn't in the inventory at all.
    public static func upToDate(runningVersion: String, homepageURL: URL? = SelfUpgradeIdentity.homepageURL) -> SelfUpgradeStatus {
        SelfUpgradeStatus(
            runningVersion: runningVersion,
            latestVersion: nil,
            homepageURL: homepageURL,
            isUpgradeAvailable: false,
        )
    }
}
