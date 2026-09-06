//
//  FixturePackage.swift
//  BrewUITests
//

import Foundation

/// One package rendered into every wire format that mentions it, so a scenario cannot claim `wget` is
/// at one version in the inventory and another in the catalogue.
struct FixturePackage {
    enum Kind {
        case formula
        case cask
    }

    let token: String
    let kind: Kind
    let displayName: String
    let summary: String
    let installedVersion: String?
    let latestVersion: String
    let dependencies: [String]

    init(
        token: String,
        kind: Kind,
        displayName: String? = nil,
        summary: String,
        installedVersion: String? = nil,
        latestVersion: String,
        dependencies: [String] = [],
    ) {
        self.token = token
        self.kind = kind
        self.displayName = displayName ?? token
        self.summary = summary
        self.installedVersion = installedVersion
        self.latestVersion = latestVersion
        self.dependencies = dependencies
    }

    var homepage: String {
        "https://example.invalid/\(token)"
    }

    var isOutdated: Bool {
        guard let installedVersion else {
            return false
        }
        return installedVersion != latestVersion
    }

    var infoFormulaJSON: [String: Any] {
        var installed: [[String: Any]] = []
        if let installedVersion {
            installed.append([
                "version": installedVersion,
                "installed_on_request": true,
                "poured_from_bottle": true,
                // Fixed instant: a relative date would make "installed N days ago" depend on the run.
                "time": 1_767_225_600,
            ])
        }
        var json: [String: Any] = [
            "name": token,
            "full_name": token,
            "tap": "homebrew/core",
            "desc": summary,
            "homepage": homepage,
            "license": "MIT",
            "dependencies": dependencies,
            "versions": ["stable": latestVersion],
            "installed": installed,
            "pinned": false,
            "keg_only": false,
            "outdated": isOutdated,
        ]
        if let installedVersion {
            json["linked_keg"] = installedVersion
        }
        return json
    }

    var infoCaskJSON: [String: Any] {
        [
            "token": token,
            "tap": "homebrew/cask",
            "name": [displayName],
            "desc": summary,
            "homepage": homepage,
            "version": latestVersion,
            "installed": installedVersion ?? "",
            "installed_on_request": true,
            "depends_on": ["formula": dependencies],
            "outdated": isOutdated,
        ]
    }

    var catalogueFormulaJSON: [String: Any] {
        [
            "name": token,
            "desc": summary,
            "homepage": homepage,
            "versions": ["stable": latestVersion],
            "dependencies": dependencies,
        ]
    }

    var catalogueCaskJSON: [String: Any] {
        [
            "token": token,
            "name": [displayName],
            "desc": summary,
            "homepage": homepage,
            "version": latestVersion,
            "depends_on": ["formula": dependencies],
        ]
    }
}
