//
//  PackageDetailMetadataItemTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import BrewRepositories
import BrewRepositoriesTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

struct PackageDetailMetadataItemTests {
    @Test func `info command uses package name`() {
        let item = PackageDetailMetadataItem(package: InstalledBrewPackage.fixture(name: "wget", kind: .formula))
        #expect(item.infoCommand == "brew info wget")
    }

    @Test func `metadata values normalize missing versions to em dash`() {
        let item = PackageDetailMetadataItem(
            package: .fixture(name: "wget", latestVersion: " ", installedVersions: []),
        )
        #expect(item.latestVersionValue == "—")
        #expect(item.installedVersionsValue == "—")
    }

    @Test func `metadata installed versions join with comma separator`() {
        let item = PackageDetailMetadataItem(
            package: .fixture(name: "wget", installedVersions: ["1.0.0", "2.0.0"]),
        )
        #expect(item.installedVersionsValue == "1.0.0, 2.0.0")
    }

    @Test func `homepage metadata keeps valid web URLs and host title`() {
        let item = PackageDetailMetadataItem(
            package: .fixture(name: "wget", homepage: "https://example.com/docs"),
        )
        #expect(item.homepageURL?.absoluteString == "https://example.com/docs")
        #expect(item.homepageDisplayTitle == "example.com")
    }

    @Test func `homepage metadata rejects invalid URLs`() {
        let item = PackageDetailMetadataItem(
            package: .fixture(name: "wget", homepage: "ftp://example.com"),
        )
        #expect(item.homepageURL == nil)
        #expect(item.homepageDisplayTitle == nil)
    }
}
