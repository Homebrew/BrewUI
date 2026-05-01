//
//  InstalledPackageRow+Presentation.swift
//  Brew
//

import Foundation

/// How the version line should render (unit-testable; no SwiftUI).
enum RowVersionPresentation: Equatable {
    case installed(String)
    case upgrade(current: String, latest: String)
}

extension InstalledPackageRow {
    var hasDescription: Bool {
        !description.isEmpty
    }

    /// Whether the list row should show “update available” styling (paired with ``versionPresentation``).
    var showsUpdateAvailable: Bool {
        updateVersion != nil
    }

    var versionPresentation: RowVersionPresentation {
        if let latest = updateVersion {
            return .upgrade(current: installedVersion, latest: latest)
        }
        return .installed(installedVersion)
    }

    /// VoiceOver summary for the combined row.
    var listRowAccessibilitySummary: String {
        var parts = [name]
        if hasDescription {
            parts.append(description)
        }
        parts.append(installedVersion)
        if let update = updateVersion {
            parts.append("Update available to \(update)")
        } else {
            parts.append("Installed and up to date")
        }
        return parts.joined(separator: ", ")
    }
}
